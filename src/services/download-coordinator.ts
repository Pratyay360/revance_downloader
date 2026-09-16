import { fetch } from "expo/fetch";
import { DownloadTask, File, Paths } from "expo-file-system";
import * as IntentLauncher from "expo-intent-launcher";
import { sha256 } from "js-sha256";
import { Platform } from "react-native";

import { DownloadHistoryStore } from "@/lib/download-history";
import { showNotification } from "./notifications";

/**
 * Port of download_coordinator.dart — orchestrates a single download:
 * fetch with progress + cancel + inactivity watchdog, verify sha256 digest,
 * record in the history DB, then hand the file to the Android installer.
 *
 * Fetching is aria2c-style (`-x`/`-s`): files large enough to be worth it
 * are split into ranges downloaded over parallel connections with HTTP
 * `Range` requests and written at offsets into a preallocated file.
 * Servers without range support fall back to a single-stream DownloadTask.
 */

export interface DownloadRequest {
	name: string;
	url: string;
	digest: string;
}

type Listener<T> = (value: T) => void;

/** Minimal observable, replaces Flutter's ValueNotifier. */
export class Notifier<T> {
	private listeners = new Set<Listener<T>>();
	constructor(public value: T) {}
	set(value: T) {
		this.value = value;
		this.listeners.forEach((l) => {
			l(value);
		});
	}
	subscribe(listener: Listener<T>) {
		this.listeners.add(listener);
		return () => {
			this.listeners.delete(listener);
		};
	}
}

const INACTIVITY_TIMEOUT_MS = 60_000;

// aria2c-style segmented download tuning. Connection count is adaptive
// (AIMD on measured throughput), so throttled hosts stay low and fast
// hosts ramp up with zero manual configuration.
/** Only segment files at least this large; small files aren't worth it. */
const SEGMENTED_MIN_SIZE = 4 * 1024 * 1024;
/** Piece size per range request. Bounds memory use to ~1MB per connection. */
const PIECE_SIZE = 1024 * 1024;
/** Adaptive pool bounds (connections). */
const MIN_WORKERS = 1;
const START_WORKERS = 4;
const MAX_WORKERS = 16;
/** How often throughput is sampled to grow/shrink the pool. */
const ADJUST_INTERVAL_MS = 3000;
/** Per-piece fetch attempts before the download fails. */
const PIECE_RETRIES = 3;

class DownloadCoordinator {
	readonly progress = new Notifier<number>(0); // 0..1
	readonly status = new Notifier<string>("Starting...");

	private watchdog: ReturnType<typeof setTimeout> | null = null;
	private abortController: AbortController | null = null;
	private running = false;
	private cancelled = false;

	get isRunning(): boolean {
		return this.running;
	}

	async startDownload(
		request: DownloadRequest,
		options?: {
			onCompleted?: () => void;
			onError?: (message: string) => void;
			onCancelled?: () => void;
		},
	): Promise<void> {
		if (this.running) {
			throw new Error("A download is already in progress.");
		}

		this.running = true;
		this.cancelled = false;
		this.progress.set(0);
		this.status.set("Starting...");
		this.abortController = new AbortController();
		this.resetWatchdog(() => {
			this.cancelDownload();
			options?.onError?.("Download timed out due to inactivity.");
		});

		try {
			const safeName = sanitizeFileName(request.name);
			const destination = new File(Paths.cache, safeName);
			const report = ({
				bytesWritten,
				totalBytes,
			}: {
				bytesWritten: number;
				totalBytes: number;
			}) => {
				if (this.cancelled) return;
				this.resetWatchdog(() => {
					this.cancelDownload();
					options?.onError?.("Download timed out due to inactivity.");
				});
				if (totalBytes > 0) {
					const ratio = bytesWritten / totalBytes;
					this.progress.set(Math.min(1, Math.max(0, ratio)));
					this.status.set(`${(ratio * 100).toFixed(1)}%`);
				}
			};

			// Fast path: parallel segmented fetch. Returns null when the
			// server can't do ranges (or the file is small), in which case
			// we fall through to the single-stream DownloadTask below.
			let file = await this.segmentedDownload(
				request.url,
				destination,
				this.abortController.signal,
				report,
			);
			if (!file) {
				file = await this.singleStreamDownload(
					request.url,
					destination,
					this.abortController.signal,
					report,
				);
			}

			if (this.cancelled) return;
			if (!file) {
				throw new Error("Download failed.");
			}

			this.status.set("Verifying download...");
			await this.verifyDigest(file, request.digest);

			this.status.set("Saving download metadata...");
			await DownloadHistoryStore.insert({
				name: request.name,
				digest: request.digest,
				path: file.uri,
			});

			this.status.set("Launching installer...");
			await this.launchInstaller(file);
			await showNotification({
				id: 2,
				title: "Installation",
				body: "Installer opened successfully",
			});

			this.finish();
			options?.onCompleted?.();
		} catch (e) {
			this.finish();
			if (this.cancelled) {
				options?.onCancelled?.();
				return;
			}
			const message = e instanceof Error ? e.message : String(e);
			options?.onError?.(`Download processing failed: ${message}`);
		}
	}

	cancelDownload() {
		if (!this.running || this.cancelled) return;
		this.cancelled = true;
		this.abortController?.abort();
		this.finish();
	}

	/** Original single-connection fetch via the native download task. */
	private async singleStreamDownload(
		url: string,
		destination: File,
		signal: AbortSignal,
		onProgress: (p: { bytesWritten: number; totalBytes: number }) => void,
	): Promise<File | null> {
		const downloadTask = new DownloadTask(url, destination, {
			onProgress,
			signal,
		});
		return downloadTask.downloadAsync();
	}

	/**
	 * aria2c-style segmented download with an adaptive connection pool:
	 * probe for `Accept-Ranges`, preallocate the file (mirrors
	 * `aria2c --file-allocation=prealloc`), then drain a shared queue of
	 * 1MB pieces with N parallel connections. N starts at START_WORKERS
	 * and is retuned every ADJUST_INTERVAL_MS from measured throughput
	 * (AIMD): while aggregate speed keeps improving a connection is added
	 * (up to MAX_WORKERS); when it degrades past 70% of the best observed
	 * speed a connection drains out (down to MIN_WORKERS). Throttled hosts
	 * therefore settle low, fast hosts ramp up — no manual tuning.
	 *
	 * Returns null when the server can't do ranges (or the file is too
	 * small to bother) so the caller falls back to single-stream.
	 * Throws on real failures (network errors, 206 mismatch, aborts).
	 */
	private async segmentedDownload(
		url: string,
		destination: File,
		signal: AbortSignal,
		onProgress: (p: { bytesWritten: number; totalBytes: number }) => void,
	): Promise<File | null> {
		const total = await this.probeDownloadSize(url, signal);
		if (
			total === null ||
			total < SEGMENTED_MIN_SIZE ||
			!(await this.serverSupportsRanges(url, signal))
		) {
			return null;
		}

		// Fresh preallocated file: delete any stale partial, create, zero-fill.
		if (destination.exists) destination.delete();
		destination.create();
		const handle = destination.open();
		try {
			const zeros = new Uint8Array(PIECE_SIZE);
			for (let pos = 0; pos < total; pos += PIECE_SIZE) {
				if (this.cancelled) throw new Error("Download cancelled.");
				handle.offset = pos;
				handle.writeBytes(zeros.subarray(0, Math.min(PIECE_SIZE, total - pos)));
			}

			// Shared piece queue: every piece is an independent range, so
			// fast connections automatically take more work (no stragglers
			// holding a whole fixed segment hostage).
			const pieces: { start: number; end: number }[] = [];
			for (let pos = 0; pos < total; pos += PIECE_SIZE) {
				pieces.push({ start: pos, end: Math.min(pos + PIECE_SIZE, total) });
			}
			let next = 0;
			let active = 0;
			let target = Math.min(START_WORKERS, pieces.length);
			let nextId = 0;
			let failed: unknown = null;
			const all: Promise<void>[] = [];

			let written = 0;
			const report = (n: number) => {
				written += n;
				onProgress({ bytesWritten: written, totalBytes: total });
			};

			const worker = async (id: number): Promise<void> => {
				active++;
				try {
					for (;;) {
						if (failed !== null) return;
						if (id >= target) return; // pool scaled down — drain out
						if (this.cancelled) throw new Error("Download cancelled.");
						const piece = next < pieces.length ? pieces[next++] : null;
						if (!piece) return; // queue drained
						await this.fetchPiece(url, handle, piece, signal);
						if (failed !== null) return;
						report(piece.end - piece.start);
					}
				} catch (e) {
					if (failed === null) failed = e;
					throw e;
				} finally {
					active--;
				}
			};
			const spawn = () => {
				all.push(worker(nextId++));
			};
			for (let i = 0; i < target; i++) spawn();

			// AIMD controller: grow while speed improves, shrink on drop.
			// Per-piece `offset`+`writeBytes` pairs are synchronous, so they
			// can't interleave mid-write on the shared handle.
			let lastW = 0;
			let lastT = Date.now();
			let best = 0;
			const timer = setInterval(() => {
				if (failed !== null) return;
				const now = Date.now();
				const elapsed = Math.max(1, now - lastT) / 1000;
				const speed = (written - lastW) / elapsed;
				lastW = written;
				lastT = now;
				if (speed >= best && target < MAX_WORKERS && next < pieces.length) {
					best = speed;
					target++;
					spawn();
				} else {
					if (speed > best) best = speed;
					if (speed < best * 0.7 && target > MIN_WORKERS) target--;
				}
			}, ADJUST_INTERVAL_MS);

			try {
				while (failed === null && (next < pieces.length || active > 0)) {
					await new Promise((r) => setTimeout(r, 100));
				}
			} finally {
				clearInterval(timer);
			}
			// Let scaled-down / in-flight workers exit before closing the
			// handle out from under them.
			await Promise.allSettled(all);
			if (failed !== null) throw failed;
		} finally {
			handle.close();
		}
		return destination;
	}

	/**
	 * Fetch one [start, end) piece with retries, writing it at its absolute
	 * offset. Throws on abort, cancellation, or persistent failure.
	 */
	private async fetchPiece(
		url: string,
		handle: { offset: number | null; writeBytes: (b: Uint8Array) => void },
		piece: { start: number; end: number },
		signal: AbortSignal,
	): Promise<void> {
		const expected = piece.end - piece.start;
		let lastError: unknown = null;
		for (let attempt = 0; attempt < PIECE_RETRIES; attempt++) {
			if (this.cancelled || signal.aborted) {
				throw new Error("Download cancelled.");
			}
			try {
				const res = await fetch(url, {
					headers: { Range: `bytes=${piece.start}-${piece.end - 1}` },
					signal,
				});
				if (res.status !== 206) {
					throw new Error(
						`Range request rejected (HTTP ${res.status}); server may not support segmented downloads.`,
					);
				}
				const bytes = new Uint8Array(await res.arrayBuffer());
				if (bytes.length !== expected) {
					throw new Error(
						`Short range response (${bytes.length}/${expected} bytes).`,
					);
				}
				handle.offset = piece.start;
				handle.writeBytes(bytes);
				return;
			} catch (e) {
				lastError = e;
				if (signal.aborted || this.cancelled) throw e;
				await new Promise((r) => setTimeout(r, 500 * (attempt + 1)));
			}
		}
		throw lastError;
	}

	/** HEAD probe for Content-Length. Null when unknown / probe fails. */
	private async probeDownloadSize(
		url: string,
		signal: AbortSignal,
	): Promise<number | null> {
		try {
			const res = await fetch(url, { method: "HEAD", signal });
			if (!res.ok) return null;
			const length = res.headers.get("content-length");
			const total = length !== null ? Number(length) : NaN;
			return Number.isSafeInteger(total) && total > 0 ? total : null;
		} catch {
			return null;
		}
	}

	/** Zero-byte range probe: 206 means the server honors Range requests. */
	private async serverSupportsRanges(
		url: string,
		signal: AbortSignal,
	): Promise<boolean> {
		try {
			const res = await fetch(url, {
				headers: { Range: "bytes=0-0" },
				signal,
			});
			return res.status === 206;
		} catch {
			return false;
		}
	}

	private async launchInstaller(file: File) {
		if (Platform.OS !== "android") {
			console.warn("APK installation is only supported on Android.");
			return;
		}
		try {
			const contentUri = await this.getShareableUri(file);
			// FLAG_ACTIVITY_NEW_TASK (0x10000000) | FLAG_GRANT_READ_URI_PERMISSION (0x1).
			// The content:// URI is served by expo-file-system's FileSystemFileProvider,
			// which avoids the FileUriExposedException thrown for file:// URIs on API 24+.
			// Requires android.permission.REQUEST_INSTALL_PACKAGES (see app.json).
			await IntentLauncher.startActivityAsync("android.intent.action.VIEW", {
				data: contentUri,
				type: "application/vnd.android.package-archive",
				flags: 268435457,
			});
		} catch (e) {
			console.warn(
				`APK installer could not be launched (file saved at ${file.uri}). ` +
					"On Android 8+, allow “Install unknown apps” for this app, then tap the APK to install it.",
				e,
			);
		}
	}

	/**
	 * Resolve a content:// URI other apps can read. Per SDK 57 docs
	 * (expo-file-system `File.contentUri`), this is a sync string property —
	 * no legacy `getContentUriAsync` import needed.
	 */
	private async getShareableUri(file: File): Promise<string> {
		if (
			typeof file.contentUri === "string" &&
			file.contentUri.startsWith("content://")
		) {
			return file.contentUri;
		}
		throw new Error(`No shareable content URI for ${file.uri}`);
	}

	private resetWatchdog(onTimeout: () => void) {
		if (this.watchdog) clearTimeout(this.watchdog);
		this.watchdog = setTimeout(onTimeout, INACTIVITY_TIMEOUT_MS);
	}

	private finish() {
		if (this.watchdog) {
			clearTimeout(this.watchdog);
			this.watchdog = null;
		}
		this.abortController = null;
		this.running = false;
	}

	private async verifyDigest(file: File, digest: string): Promise<void> {
		const normalized = this.normalizeDigest(digest);
		if (normalized === null) {
			if (digest.trim().length > 0) {
				throw new Error("Invalid digest format.");
			}
			return; // no digest provided — skip verification
		}

		if (!file.exists) {
			throw new Error("Downloaded file does not exist.");
		}

		const computed = await this.sha256File(file);
		if (computed !== normalized) {
			throw new Error("Digest mismatch detected.");
		}
	}

	private normalizeDigest(raw: string): string | null {
		const value = raw.trim().toLowerCase();
		if (!value) return null;
		if (value.startsWith("sha256:")) return value.slice("sha256:".length);
		if (/^[a-f0-9]{64}$/.test(value)) return value;
		return null;
	}

	/** Stream the file in chunks through js-sha256 (files can be 100+ MB). */
	private async sha256File(file: File): Promise<string> {
		const hasher = sha256.create();
		try {
			const reader = file.readableStream().getReader();
			for (;;) {
				const { done, value } = await reader.read();
				if (done) break;
				if (value) hasher.update(value);
			}
		} catch {
			// Fallback if the stream API is unavailable on this platform.
			const bytes = await file.bytes();
			hasher.update(bytes);
		}
		return hasher.hex();
	}
}

export const downloadCoordinator = new DownloadCoordinator();

/** Strip path separators / traversal so GitHub asset names can't escape cache. */
function sanitizeFileName(raw: string): string {
	const base = raw.split(/[\\/]/).pop() ?? raw;
	const cleaned = base.replace(/[^a-zA-Z0-9._-]+/g, "_").replace(/_+/g, "_");
	const trimmed = cleaned.replace(/^[._]+/, "").slice(0, 128);
	return trimmed || "download.apk";
}
