import { useRouter } from "expo-router";
import {
	Bell,
	Check,
	ChevronLeft,
	ChevronRight,
	Code,
	FolderOpen,
	Sparkles,
} from "lucide-react-native";
import { useEffect, useState } from "react";
import {
	KeyboardAvoidingView,
	Linking,
	Platform,
	ScrollView,
	View,
} from "react-native";

import { SafeAreaView } from "@/components/safe-area-view";
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

type Step = {
	icon: typeof Sparkles;
	eyebrow: string;
	title: string;
	body: string;
};

const STEPS: Step[] = [
	{
		icon: Sparkles,
		eyebrow: "Welcome",
		title: "ReVanced, ready to go",
		body: "Browse, download, and install patched ReVanced APKs straight from your favourite GitHub repos.",
	},
	{
		icon: Bell,
		eyebrow: "Notifications",
		title: "Stay in the loop",
		body: "Required to show download progress and surface new releases from your repos.",
	},
	{
		icon: FolderOpen,
		eyebrow: "File Access",
		title: "Save where you want",
		body: "Required to save APKs to your device. We only write to the path you pick.",
	},
	{
		icon: Check,
		eyebrow: "Install Apps",
		title: "Install in one tap",
		body: "Required to install the downloaded ReVanced apps after a download finishes.",
	},
	{
		icon: Code,
		eyebrow: "Repository",
		title: "Pick a starting repo",
		body: "Enter the default GitHub repo for patches. You can add more later from the Repositories tab.",
	},
];

/**
 * Five-step onboarding. Keeps the same flow as the Flutter port — welcome,
 * permissions, repo — but lays it out as one continuous scrollable hero
 * with a progress bar, eyebrow labels, and a tinted icon well.
 */
export default function IntroScreen() {
	const router = useRouter();
	const [page, setPage] = useState(0);
	const [userName, setUserName] = useState(secrets.defaultRepo.userName);
	const [repoName, setRepoName] = useState(secrets.defaultRepo.repoName);
	const [notifGranted, setNotifGranted] = useState<boolean | null>(null);
	const [storageRequested, setStorageRequested] = useState(false);
	const [installRequested, setInstallRequested] = useState(false);
	const [submitting, setSubmitting] = useState(false);

	useEffect(() => {
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
		await Linking.openSettings();
		setStorageRequested(true);
	};

	const requestInstallPackages = async () => {
		if (Platform.OS !== "android") {
			setInstallRequested(true);
			return;
		}
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
			router.replace("/(tabs)");
		} finally {
			setSubmitting(false);
		}
	};

	const step = STEPS[page];
	const Icon = step.icon;
	const isLast = page === STEPS.length - 1;
	const progress = (page + 1) / STEPS.length;

	return (
		<SafeAreaView className="bg-background flex-1">
			<KeyboardAvoidingView
				className="flex-1"
				behavior={Platform.OS === "ios" ? "padding" : undefined}
			>
				<View className="flex-row items-center justify-between px-5 pt-2">
					<Text className="text-muted-foreground text-xs font-semibold tracking-wider uppercase">
						Step {page + 1} of {STEPS.length}
					</Text>
					<View className="h-1.5 w-32 overflow-hidden rounded-full bg-secondary">
						<View
							className="bg-primary h-full rounded-full"
							style={{ width: `${progress * 100}%` }}
						/>
					</View>
				</View>

				<ScrollView
					contentContainerStyle={{ flexGrow: 1, padding: 24 }}
					keyboardShouldPersistTaps="handled"
				>
					<View className="flex-1 items-center justify-center gap-5">
						<View className="bg-primary-soft items-center justify-center rounded-3xl p-6">
							<Icon size={48} className="text-primary" strokeWidth={1.75} />
						</View>
						<View className="items-center gap-2">
							<Text className="text-muted-foreground text-xs font-semibold tracking-wider uppercase">
								{step.eyebrow}
							</Text>
							<Text className="text-foreground text-center text-3xl font-bold tracking-tight">
								{step.title}
							</Text>
							<Text className="text-muted-foreground px-4 text-center text-base leading-6">
								{step.body}
							</Text>
						</View>

						{page === 1 && (
							<PermissionButton
								granted={notifGranted === true}
								label="Grant Permission"
								grantedLabel="Allowed"
								onPress={requestNotification}
							/>
						)}

						{page === 2 && (
							<PermissionButton
								granted={storageRequested}
								label="Grant Permission"
								grantedLabel="Requested"
								onPress={requestManageStorage}
							/>
						)}

						{page === 3 && (
							<PermissionButton
								granted={installRequested}
								label="Grant Permission"
								grantedLabel="Requested"
								onPress={requestInstallPackages}
							/>
						)}

						{page === 4 && (
							<View className="w-full gap-4 pt-2">
								<View>
									<Text className="text-muted-foreground mb-1.5 text-xs font-semibold uppercase">
										Owner
									</Text>
									<Input className="rounded-xl">
										<InputField
											placeholder="e.g. j-hc"
											value={userName}
											onChangeText={setUserName}
											autoCapitalize="none"
										/>
									</Input>
								</View>
								<View>
									<Text className="text-muted-foreground mb-1.5 text-xs font-semibold uppercase">
										Repo
									</Text>
									<Input className="rounded-xl">
										<InputField
											placeholder="e.g. revanced-magisk-module"
											value={repoName}
											onChangeText={setRepoName}
											autoCapitalize="none"
										/>
									</Input>
								</View>
							</View>
						)}
					</View>
				</ScrollView>

				<View className="flex-row items-center justify-between px-5 pb-4 pt-2">
					{page > 0 ? (
						<Button
							variant="ghost"
							onPress={() => setPage((p) => p - 1)}
							accessibilityLabel="Previous step"
						>
							<ChevronLeft size={18} className="text-foreground" />
							<ButtonText>Back</ButtonText>
						</Button>
					) : (
						<View />
					)}

					{isLast ? (
						<Button
							onPress={finish}
							disabled={submitting || !userName.trim() || !repoName.trim()}
						>
							<ButtonText>
								{submitting ? "Finishing…" : "Get started"}
							</ButtonText>
						</Button>
					) : (
						<Button onPress={() => setPage((p) => p + 1)}>
							<ButtonText>Continue</ButtonText>
							<ChevronRight size={18} className="text-primary-foreground" />
						</Button>
					)}
				</View>
			</KeyboardAvoidingView>
		</SafeAreaView>
	);
}

function PermissionButton({
	granted,
	label,
	grantedLabel,
	onPress,
}: {
	granted: boolean;
	label: string;
	grantedLabel: string;
	onPress: () => void;
}) {
	return (
		<Button
			onPress={onPress}
			disabled={granted}
			variant={granted ? "secondary" : "default"}
		>
			{granted ? <Check size={16} className="text-primary" /> : null}
			<ButtonText>{granted ? grantedLabel : label}</ButtonText>
		</Button>
	);
}
