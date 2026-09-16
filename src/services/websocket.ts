import { secrets } from "@/lib/config";
import { showNotification } from "./notifications";

/**
 * Port of websocket.dart — connects to an ntfy websocket host and surfaces
 * incoming messages as local notifications. Reconnects with backoff, unlike
 * the Flutter version which let the connection die silently.
 */

interface NtfyMessage {
	message?: unknown;
	title?: unknown;
	sequence_id?: unknown;
}

let socket: WebSocket | null = null;
let retry = 0;
let disposed = false;
let reconnectTimer: ReturnType<typeof setTimeout> | null = null;

function connect() {
	if (disposed) return;
	try {
		socket = new WebSocket(secrets.ntfyHost);

		socket.onmessage = (event: WebSocketMessageEvent) => {
			const raw = typeof event.data === "string" ? String(event.data) : "";
			if (!raw.includes("sequence_id")) return;
			try {
				const jsonMessage = JSON.parse(raw) as NtfyMessage;
				const messageContent =
					typeof jsonMessage.message === "string" ? jsonMessage.message : null;
				const title =
					typeof jsonMessage.title === "string"
						? jsonMessage.title
						: "New Message";
				if (messageContent) {
					void showNotification({
						id: Math.floor(Date.now() / 1000) % 2147483647,
						title,
						body: messageContent,
					}).catch((e) => console.warn("Failed to show notification:", e));
				}
			} catch (e) {
				console.warn("Failed to parse WebSocket message:", e);
			}
		};

		socket.onerror = (error) => {
			const message =
				error && typeof error === "object" && "message" in error
					? String((error as { message?: unknown }).message)
					: "unknown error";
			console.warn("WebSocket Error:", message);
		};

		socket.onopen = () => {
			retry = 0;
		};

		socket.onclose = () => {
			if (disposed) return;
			// Reconnect with capped exponential backoff (1s, 2s, 4s ... max 60s)
			const delay = Math.min(60_000, 1000 * 2 ** retry++);
			reconnectTimer = setTimeout(connect, delay);
		};
	} catch (e) {
		console.warn("WebSocket Initialization Error:", e);
	}
}

export function initWebSocketService() {
	disposed = false;
	retry = 0;
	connect();
}

export function disposeWebSocketService() {
	disposed = true;
	if (reconnectTimer) {
		clearTimeout(reconnectTimer);
		reconnectTimer = null;
	}
	socket?.close();
	socket = null;
}
