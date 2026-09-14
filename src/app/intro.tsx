import { useRouter } from "expo-router";
import {
	Bell,
	Check,
	ChevronLeft,
	ChevronRight,
	Code,
	Download,
	FolderOpen,
} from "lucide-react-native";
import React, { useState } from "react";
import { Linking, Platform, ScrollView, StyleSheet, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { Button, ButtonText } from "@/components/ui/button";
import { Input, InputField } from "@/components/ui/input";
import { Text } from "@/components/ui/text";
import { secrets } from "@/lib/config";
import { setPrefBool } from "@/lib/prefs";
import { RepoData, saveRepoDataList } from "@/lib/repo-data";
import {
	getNotificationPermissionGranted,
	requestNotificationPermission,
} from "@/services/notifications";

/**
 * Port of intro.dart — onboarding pages: welcome, notification permission,
 * file access, install permission and default repository details.
 */
export default function IntroScreen() {
	const router = useRouter();
	const [page, setPage] = useState(0);
	const [userName, setUserName] = useState(secrets.defaultRepo.userName);
	const [repoName, setRepoName] = useState(secrets.defaultRepo.repoName);
	const [notifGranted, setNotifGranted] = React.useState<boolean | null>(null);
	const [storageRequested, setStorageRequested] = useState(false);
	const [installRequested, setInstallRequested] = useState(false);
	const [submitting, setSubmitting] = useState(false);

	React.useEffect(() => {
		getNotificationPermissionGranted()
			.then((granted) => setNotifGranted(granted))
			.catch(() => setNotifGranted(false));
	}, []);

	const requestNotification = async () => {
		const granted = await requestNotificationPermission();
		setNotifGranted(granted);
	};

	const requestManageStorage = async () => {
		if (Platform.OS !== "android") {
			setStorageRequested(true);
			return;
		}
		// MANAGE_EXTERNAL_STORAGE is a special permission — send the user to settings.
		await Linking.openSettings();
		setStorageRequested(true);
	};

	const requestInstallPackages = async () => {
		if (Platform.OS !== "android") {
			setInstallRequested(true);
			return;
		}
		// REQUEST_INSTALL_PACKAGES is also granted via settings.
		await Linking.openSettings();
		setInstallRequested(true);
	};

	const finish = async () => {
		if (!userName.trim() || !repoName.trim()) return;
		setSubmitting(true);
		try {
			if (
				userName.trim() !== secrets.defaultRepo.userName ||
				repoName.trim() !== secrets.defaultRepo.repoName
			) {
				await saveRepoDataList([
					new RepoData({
						userName: userName.trim(),
						repoName: repoName.trim(),
					}),
				]);
			}
			await setPrefBool("intro_completed", true);
			// Dismiss the modal and jump back to the home tab. Avoids Updates.reloadAsync,
			// which is a no-op in Expo Go and would leave the user stuck on the intro.
			router.dismissAll();
			router.replace("/(tabs)");
		} finally {
			setSubmitting(false);
		}
	};

	return (
		<SafeAreaView className="flex-1 bg-background">
			<ScrollView contentContainerStyle={styles.content}>
				{page === 0 && (
					<View className="flex-1 items-center justify-center gap-6">
						<Download size={80} className="text-primary" />
						<Text className="text-3xl font-bold">Welcome</Text>
						<Text className="text-muted-foreground text-center text-base">
							Download and manage ReVanced apps easily.
						</Text>
					</View>
				)}

				{page === 1 && (
					<View className="flex-1 items-center justify-center gap-6">
						<Bell size={64} className="text-primary" />
						<Text className="text-2xl font-bold">Notifications</Text>
						<Text className="text-muted-foreground text-center">
							Required to show download progress and completion.
						</Text>
						<PermissionButton
							granted={notifGranted === true}
							label={notifGranted ? "Allowed" : "Grant Permission"}
							onPress={requestNotification}
						/>
					</View>
				)}

				{page === 2 && (
					<View className="flex-1 items-center justify-center gap-6">
						<FolderOpen size={64} className="text-primary" />
						<Text className="text-2xl font-bold">File Access</Text>
						<Text className="text-muted-foreground text-center">
							Required to save APKs to your device.
						</Text>
						<PermissionButton
							granted={storageRequested}
							label={storageRequested ? "Requested" : "Grant Permission"}
							onPress={requestManageStorage}
						/>
					</View>
				)}

				{page === 3 && (
					<View className="flex-1 items-center justify-center gap-6">
						<Check size={64} className="text-primary" />
						<Text className="text-2xl font-bold">Install Apps</Text>
						<Text className="text-muted-foreground text-center">
							Required to install the downloaded ReVanced apps.
						</Text>
						<PermissionButton
							granted={installRequested}
							label={installRequested ? "Requested" : "Grant Permission"}
							onPress={requestInstallPackages}
						/>
					</View>
				)}

				{page === 4 && (
					<View className="flex-1 items-center justify-center gap-6">
						<Code size={64} className="text-primary" />
						<Text className="text-2xl font-bold">Repository Details</Text>
						<Text className="text-muted-foreground text-center">
							Enter the default GitHub repository details for patches.
						</Text>
						<View className="w-full gap-4 px-2">
							<Input className="rounded-xl">
								<InputField
									placeholder="User Name (e.g. j-hc)"
									value={userName}
									onChangeText={setUserName}
									autoCapitalize="none"
								/>
							</Input>
							<Input className="rounded-xl">
								<InputField
									placeholder="Repo Name (e.g. revanced-magisk-module)"
									value={repoName}
									onChangeText={setRepoName}
									autoCapitalize="none"
								/>
							</Input>
						</View>
					</View>
				)}
			</ScrollView>

			<View className="flex-row items-center justify-between p-6">
				{page > 0 ? (
					<Button variant="ghost" onPress={() => setPage((p) => p - 1)}>
						<ChevronLeft size={18} />
					</Button>
				) : (
					<View className="w-10" />
				)}

				<View className="flex-row gap-1.5">
					{[0, 1, 2, 3, 4].map((i) => (
						<View
							key={i}
							className={`h-2 rounded-full ${i === page ? "w-6 bg-primary" : "w-2 bg-muted"}`}
						/>
					))}
				</View>

				{page < 4 ? (
					<Button onPress={() => setPage((p) => p + 1)}>
						<ChevronRight size={18} />
					</Button>
				) : (
					<Button onPress={finish} disabled={submitting}>
						<ButtonText>Done</ButtonText>
					</Button>
				)}
			</View>
		</SafeAreaView>
	);
}

function PermissionButton({
	granted,
	label,
	onPress,
}: {
	granted: boolean;
	label: string;
	onPress: () => void;
}) {
	return (
		<Button onPress={onPress} disabled={granted} className="rounded-xl px-6">
			{granted && <Check size={16} className="text-primary-foreground" />}
			<ButtonText>{granted ? "Allowed" : label}</ButtonText>
		</Button>
	);
}

const styles = StyleSheet.create({
	content: {
		flexGrow: 1,
	},
});
