import { Tabs } from "expo-router";
import { Image , useColorScheme } from "react-native";

import { Colors } from "@/constants/theme";

export default function AppTabs() {
	const scheme = useColorScheme();
	const colors = Colors[scheme === "dark" ? "dark" : "light"];

	return (
		<Tabs
			screenOptions={{
				headerShown: false,
				tabBarActiveTintColor: colors.tint,
				tabBarInactiveTintColor: colors.textSecondary,
				tabBarStyle: { backgroundColor: colors.background },
			}}
		>
			<Tabs.Screen
				name="index"
				options={{
					title: "Apps",
					tabBarIcon: ({ color }) => (
						<Image
							source={require("@/assets/images/tabIcons/home.png")}
							style={{ width: 24, height: 24, tintColor: color }}
							resizeMode="contain"
						/>
					),
				}}
			/>
			<Tabs.Screen
				name="explore"
				options={{
					title: "Repos",
					tabBarIcon: ({ color }) => (
						<Image
							source={require("@/assets/images/tabIcons/explore.png")}
							style={{ width: 24, height: 24, tintColor: color }}
							resizeMode="contain"
						/>
					),
				}}
			/>
		</Tabs>
	);
}
