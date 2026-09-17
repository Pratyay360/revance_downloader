import Constants from "expo-constants";
import { Platform } from "react-native";

import { getPrefBool, setPrefBool } from "@/lib/prefs";

/**
 * Port of notifications.dart — local notification helper built on
 * expo-notifications (replaces flutter_local_notifications).
 *
 * NOTE: Android push/local-notification functionality from expo-notifications
 * was removed from Expo Go in SDK 53+. A top-level `import` would throw at
 * module load time inside Expo Go and take down every route that (transitively)
 * imports this file. So the module is loaded lazily via `require` and every
 * public function degrades to a no-op when it is unavailable. Use a
 * development build (`npx expo run:android`) for full notification support.
 */

type NotificationsModule = typeof import("expo-notifications");

let notificationsModule: NotificationsModule | null | undefined;

// expo-notifications removed Android push support from Expo Go in SDK 53+,
// and merely *evaluating* the module throws on Android (its
// DevicePushTokenAutoRegistration side-effect calls addPushTokenListener at
// module scope). So in Expo Go we never load it in the first place — the
// try/catch below is only a second line of defence for other environments.
const isExpoGo = Constants.appOwnership === "expo";

function getNotifications(): NotificationsModule | null {
	if (notificationsModule !== undefined) {
		return notificationsModule;
	}
	if (isExpoGo) {
		notificationsModule = null;
		return notificationsModule;
	}
	try {
		// eslint-disable-next-line @typescript-eslint/no-require-imports
		notificationsModule = require("expo-notifications") as NotificationsModule;
	} catch (e) {
		console.warn(
			"expo-notifications is unavailable (likely Expo Go) — local notifications are disabled.",
			e,
		);
		notificationsModule = null;
	}
	return notificationsModule;
}

/** False inside Expo Go / on platforms without the native module. */
export function isNotificationsAvailable(): boolean {
	return getNotifications() !== null;
}

let handlerSet = false;

function ensureHandler(): void {
	const Notifications = getNotifications();
	if (!Notifications || handlerSet) return;
	try {
		Notifications.setNotificationHandler({
			handleNotification: async () => ({
				shouldShowBanner: true,
				shouldShowList: true,
				shouldPlaySound: true,
				shouldSetBadge: false,
			}),
		});
		handlerSet = true;
	} catch (e) {
		console.warn("Error setting notification handler:", e);
	}
}

// Every notification this app posts is routed to this channel (see
// showNotification). Without an explicit channelId expo-notifications falls
// back to its own `expo_notifications_fallback_notification_channel`.
const ANDROID_CHANNEL_ID = "basic_channel";

// Bumped whenever a property Android treats as immutable (importance, sound,
// vibration) changes, so existing installs get migrated exactly once.
const CHANNEL_MIGRATION_KEY = "notifications_channel_v2";

/**
 * Android only lets an app update a channel's name and description after
 * creation — importance, sound and vibration are frozen at their original
 * values. So an install that already created the channel would keep the old
 * (non-heads-up) importance forever. Recreate it once to pick up the current
 * config.
 *
 * The pref flag is what makes this safe: we never delete a channel again, so a
 * change the *user* makes later in system settings is never overwritten.
 */
async function migrateAndroidChannel(
	Notifications: NotificationsModule,
): Promise<void> {
	try {
		if (await getPrefBool(CHANNEL_MIGRATION_KEY)) return;
		const existing =
			await Notifications.getNotificationChannelAsync(ANDROID_CHANNEL_ID);
		if (existing && existing.importance < Notifications.AndroidImportance.HIGH) {
			await Notifications.deleteNotificationChannelAsync(ANDROID_CHANNEL_ID);
		}
		await setPrefBool(CHANNEL_MIGRATION_KEY, true);
	} catch (e) {
		// Never let this block channel setup — the channel is (re)created next.
		console.warn("Error migrating notification channel:", e);
	}
}

let initialized = false;

export async function initNotifications(): Promise<void> {
	if (initialized) return;
	const Notifications = getNotifications();
	if (!Notifications) return;
	ensureHandler();
	try {
		if (Platform.OS === "android") {
			await migrateAndroidChannel(Notifications);
			await Notifications.setNotificationChannelAsync(ANDROID_CHANNEL_ID, {
				name: "Basic Notifications",
				// HIGH, not DEFAULT: heads-up banners require HIGH or above, and
				// DEFAULT would silently downgrade what the fallback channel did.
				importance: Notifications.AndroidImportance.HIGH,
				// Do NOT pass sound: "default" here. On the channel API the string is
				// treated as a custom raw-resource name, so it logs "Custom sound
				// 'default' not found in native app". Omitting the key already falls
				// back to Settings.System.DEFAULT_NOTIFICATION_URI (the system sound).
				vibrationPattern: [0, 250, 250, 250],
				showBadge: true,
			});
		}
		initialized = true;
	} catch (e) {
		console.warn("Error initializing notifications:", e);
	}
}

export async function requestNotificationPermission(): Promise<boolean> {
	const Notifications = getNotifications();
	if (!Notifications) return false;
	try {
		await initNotifications();
		const current = await Notifications.getPermissionsAsync();
		if (current.granted) return true;
		const requested = await Notifications.requestPermissionsAsync();
		return requested.granted;
	} catch (e) {
		console.warn("Error requesting notification permission:", e);
		return false;
	}
}

export async function getNotificationPermissionGranted(): Promise<boolean> {
	const Notifications = getNotifications();
	if (!Notifications) return false;
	try {
		const current = await Notifications.getPermissionsAsync();
		return current.granted;
	} catch (e) {
		console.warn("Error reading notification permission:", e);
		return false;
	}
}

export async function showNotification(params: {
	id: number;
	title: string;
	body: string;
}): Promise<void> {
	const Notifications = getNotifications();
	if (!Notifications) {
		return;
	}
	await initNotifications();
	if (!initialized) {
		console.warn("Notifications not initialized, skipping notification");
		return;
	}
	try {
		await Notifications.scheduleNotificationAsync({
			identifier: String(params.id),
			content: {
				title: params.title,
				body: params.body,
				sound: "default",
			},
			// Channel-aware triggers carry no time, so this still fires immediately
			// (parseTrigger maps it to { type: 'channel' } on Android, null on iOS).
			trigger:
				Platform.OS === "android" ? { channelId: ANDROID_CHANNEL_ID } : null,
		});
	} catch (e) {
		console.warn("Error showing notification:", e);
	}
}
