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
	 * Resolve a content:// URI other apps can read. Prefers the SDK 57
	 * File.contentUri property, falls back to the legacy getContentUriAsync API.
	 */
	private async getShareableUri(file: File): Promise<string> {
		const candidate = file as unknown as { contentUri?: unknown };
		if (
			typeof candidate.contentUri === "string" &&
			candidate.contentUri.startsWith("content://")
		) {
			return candidate.contentUri;
		}
		const { getContentUriAsync } = await import("expo-file-system/legacy");
		return getContentUriAsync(file.uri);
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
