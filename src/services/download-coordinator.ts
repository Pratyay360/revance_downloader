import { InstallApk } from "@isudaji/react-native-install-apk";
import { DownloadTask, File, Paths } from "expo-file-system";
import { sha256 } from "js-sha256";
import { Platform } from "react-native";

import { DownloadHistoryStore } from "@/lib/download-history";
import { showNotification } from "./notifications";

/**
 * Port of download_coordinator.dart — orchestrates a single download:
 * fetch with progress + cancel + inactivity watchdog, verify sha256 digest,
 * record in the history DB, then hand the file to the Android installer.
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
		this.listeners.forEach((l) => l(value));
	}
	subscribe(listener: Listener<T>) {
		this.listeners.add(listener);
		return () => {
			this.listeners.delete(listener);
		};
	}
}

const INACTIVITY_TIMEOUT_MS = 60_000;

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
			const destination = new File(Paths.cache, request.name);
			const downloadTask = new DownloadTask(request.url, destination, {
				onProgress: ({ bytesWritten, totalBytes }) => {
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
				},
				signal: this.abortController.signal,
			});

			const file = await downloadTask.downloadAsync();

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
			this.launchInstaller(file.uri);
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

	private launchInstaller(path: string) {
		if (Platform.OS !== "android") {
			console.warn("APK installation is only supported on Android.");
			return;
		}
		// Expo Go doesn't link the @isudaji/react-native-install-apk native module,
		// so calling InstallApk.install() throws. Detect this and degrade gracefully
		// — the file is still saved, the user just has to install it manually.
		const native = InstallApk as unknown as {
			install?: (p: string) => void;
		};
		if (typeof native.install !== "function") {
			console.warn(
				"InstallApk native module is not available (likely Expo Go). " +
					"Skipping auto-install; the APK is saved at " +
					path,
			);
			return;
		}
		// The native module expects a plain filesystem path.
		const filePath = path.startsWith("file://")
			? path.slice("file://".length)
			: path;
		try {
			native.install(filePath);
		} catch (e) {
			console.warn("InstallApk.install failed:", e);
		}
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
