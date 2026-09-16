import {
	DarkTheme,
	DefaultTheme,
	Redirect,
	Stack,
	ThemeProvider,
	usePathname,
} from "expo-router";
import * as SplashScreen from "expo-splash-screen";
import { useEffect, useState } from "react";
import { ActivityIndicator, useColorScheme, View } from "react-native";

import { AnimatedSplashOverlay } from "@/components/animated-icon";

import { GluestackUIProvider } from "@/components/ui/gluestack-ui-provider";
import { getPrefBool } from "@/lib/prefs";
import "@/global.css";
import {
	initNotifications,
	requestNotificationPermission,
} from "@/services/notifications";
import {
	disposeWebSocketService,
	initWebSocketService,
} from "@/services/websocket";

SplashScreen.preventAutoHideAsync().catch(() => {
	// Already prevented (Fast Refresh double-invoke) — safe to ignore.
});

export default function TabLayout() {
	const colorScheme = useColorScheme();
	const pathname = usePathname();
	const [introChecked, setIntroChecked] = useState(false);
	const [introCompleted, setIntroCompleted] = useState(false);

	// Port of MyApp._checkPermissionsAndNavigate from main.dart: read the
	// intro_completed flag on cold start and decide whether to redirect to
	// /intro before mounting the rest of the navigator.
	useEffect(() => {
		let disposed = false;
		(async () => {
			const completed = await getPrefBool("intro_completed");
			if (disposed) return;
			setIntroCompleted(completed);
			setIntroChecked(true);
		})();
		return () => {
			disposed = true;
		};
	}, []);

	// Re-read the flag whenever the route changes. `intro.tsx` sets the pref
	// then navigates away, but this layout's state would otherwise stay
	// `false` and `<Redirect href="/intro" />` would push the user straight
	// back into onboarding (intro loop).
	useEffect(() => {
		if (!introChecked || introCompleted) return;
		let disposed = false;
		(async () => {
			const completed = await getPrefBool("intro_completed");
			if (!disposed && completed) setIntroCompleted(true);
		})();
		return () => {
			disposed = true;
		};
	}, [pathname, introChecked, introCompleted]);

	// Port of MyApp._initializeNotifications + WebSocketService.init() from main.dart:
	// set up the notification channel, ask for permission, then connect the
	// custom ntfy websocket so incoming messages become local notifications.
	useEffect(() => {
		let disposed = false;
		(async () => {
			await initNotifications();
			await requestNotificationPermission();
			if (!disposed) initWebSocketService();
		})();
		return () => {
			disposed = true;
			disposeWebSocketService();
		};
	}, []);

	if (!introChecked) {
		return (
			<View style={{ flex: 1, alignItems: "center", justifyContent: "center" }}>
				<ActivityIndicator />
			</View>
		);
	}

	return (
		<GluestackUIProvider mode="dark">
			<ThemeProvider value={colorScheme === "dark" ? DarkTheme : DefaultTheme}>
				<AnimatedSplashOverlay />
				{!introCompleted && <Redirect href="/intro" />}
				<Stack screenOptions={{ headerShown: false }}>
					<Stack.Screen name="(tabs)" />
					<Stack.Screen name="intro" options={{ presentation: "modal" }} />
					<Stack.Screen name="repos" options={{ presentation: "modal" }} />
					<Stack.Screen
						name="repo/[userName]/[repoName]"
						options={{ presentation: "modal" }}
					/>
				</Stack>
			</ThemeProvider>
		</GluestackUIProvider>
	);
}
