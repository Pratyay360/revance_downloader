import { useRouter } from "expo-router";
import { FolderGit, Settings } from "lucide-react-native";
import { useEffect, useMemo, useState } from "react";
import { SectionList, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { EmptyState } from "@/components/empty-state";
import { ScreenHeader } from "@/components/screen-header";
import { Button, ButtonText } from "@/components/ui/button";
import { Text } from "@/components/ui/text";
import { loadRepoDataList, type RepoData } from "@/lib/repo-data";

interface RepoSection {
	title: string;
	data: RepoData[];
}

/**
 * Browse-and-manage screen for saved GitHub repositories. Grouped by
 * Default / Custom with hairline dividers, so the list reads as one
 * continuous native surface instead of stacked cards.
 */
export default function ReposTabScreen() {
	const router = useRouter();
	const [repos, setRepos] = useState<RepoData[]>([]);
	const [loading, setLoading] = useState(true);

	useEffect(() => {
		let disposed = false;
		(async () => {
			setLoading(true);
			try {
				const list = await loadRepoDataList();
				if (!disposed) setRepos(list);
			} finally {
				if (!disposed) setLoading(false);
			}
		})();
		return () => {
			disposed = true;
		};
	}, []);

	const sections = useMemo<RepoSection[]>(() => {
		const defaults = repos.filter((r) => r.isReadOnly);
		const customs = repos.filter((r) => !r.isReadOnly);
		const result: RepoSection[] = [];
		if (defaults.length > 0) result.push({ title: "Default", data: defaults });
		if (customs.length > 0) result.push({ title: "Custom", data: customs });
		return result;
	}, [repos]);

	if (loading) {
		return (
			<SafeAreaView className="bg-background flex-1" edges={["top"]}>
				<ScreenHeader title="Repositories" subtitle="Loading…" />
			</SafeAreaView>
		);
	}

	return (
		<SafeAreaView className="bg-background flex-1" edges={["top"]}>
			<ScreenHeader
				title="Repositories"
				subtitle={`${repos.length} ${repos.length === 1 ? "repo" : "repos"}`}
				right={
					<Button
						variant="ghost"
						size="sm"
						onPress={() => router.push("/repos")}
						accessibilityLabel="Manage repositories"
					>
						<Settings size={18} className="text-foreground" />
					</Button>
				}
			/>

			{sections.length === 0 ? (
				<EmptyState
					icon={FolderGit}
					title="No repositories"
					description="Add a GitHub repo to start downloading patched apps."
					action={
						<Button size="sm" onPress={() => router.push("/repos")}>
							<ButtonText>Manage repositories</ButtonText>
						</Button>
					}
				/>
			) : (
				<SectionList<RepoData, RepoSection>
					sections={sections}
					keyExtractor={(item) =>
						`${item.userName}/${item.repoName}/${item.isReadOnly}`
					}
					contentContainerStyle={{ paddingBottom: 24 }}
					renderSectionHeader={({ section: { title } }) => (
						<View className="bg-background px-5 pb-2 pt-3">
							<Text className="text-muted-foreground text-xs font-semibold tracking-wider uppercase">
								{title}
							</Text>
						</View>
					)}
					renderSectionFooter={({ section }) =>
						section.title === "Default" ? (
							<View className="px-5 pb-2">
								<Text className="text-muted-foreground text-xs">
									The default repo ships with the app and is read-only.
								</Text>
							</View>
						) : null
					}
					renderItem={({ item }) => (
						<RepoListRow
							repo={item}
							onPress={() =>
								router.push(
									`/repo/${encodeURIComponent(item.userName)}/${encodeURIComponent(item.repoName)}`,
								)
							}
						/>
					)}
					ItemSeparatorComponent={() => (
						<View className="ml-16 h-px bg-border/60" />
					)}
					SectionSeparatorComponent={() => <View className="h-1" />}
					stickySectionHeadersEnabled={false}
				/>
			)}
		</SafeAreaView>
	);
}

function RepoListRow({
	repo,
	onPress,
}: {
	repo: RepoData;
	onPress: () => void;
}) {
	return (
		<View className="active:bg-accent flex-row items-center gap-3 px-5 py-3">
			<View className="bg-primary-soft h-10 w-10 items-center justify-center rounded-xl">
				<FolderGit size={18} className="text-primary" />
			</View>
			<View className="flex-1">
				<Text
					className="text-foreground text-base font-semibold"
					numberOfLines={1}
				>
					{repo.repoName}
				</Text>
				<Text className="text-muted-foreground text-xs" numberOfLines={1}>
					{repo.userName}
					{repo.isReadOnly ? " · default" : ""}
				</Text>
			</View>
			<Button variant="ghost" size="sm" onPress={onPress}>
				<ButtonText className="text-primary">Open</ButtonText>
			</Button>
		</View>
	);
}
