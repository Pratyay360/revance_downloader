import { useRouter } from "expo-router";
import { Download } from "lucide-react-native";
import { useCallback, useEffect, useMemo, useState } from "react";
import { RefreshControl, ScrollView, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { AppAssetRow } from "@/components/app-asset-row";
import { AssetActionsheet } from "@/components/asset-actionsheet";
import { DownloadProgressModal } from "@/components/download-progress-modal";
import { EmptyState } from "@/components/empty-state";
import { ScreenHeader } from "@/components/screen-header";
import { Button, ButtonText } from "@/components/ui/button";
import { Text } from "@/components/ui/text";
import {
	fetchAllReposAssets,
	type GithubAsset,
	type RepoAsset,
} from "@/lib/github-releases";
import { loadRepoDataList, type RepoData } from "@/lib/repo-data";
import { downloadCoordinator } from "@/services/download-coordinator";

/**
 * "All Apps" home view — fetches the latest installable assets across every
 * saved repo and renders them grouped by repo, with a hero header summarising
 * the repo / asset count and a sticky refresh on pull-down.
 */
export default function HomeScreen() {
	const router = useRouter();
	const [repos, setRepos] = useState<RepoData[]>([]);
	const [assets, setAssets] = useState<RepoAsset[]>([]);
	const [refreshing, setRefreshing] = useState(false);
	const [loading, setLoading] = useState(true);
	const [errorMessage, setErrorMessage] = useState<string | null>(null);
	const [actionAsset, setActionAsset] = useState<RepoAsset | null>(null);
	const [sheetOpen, setSheetOpen] = useState(false);
	const [progressVisible, setProgressVisible] = useState(false);

	const grouped = useMemo(() => {
		const map = new Map<string, RepoAsset[]>();
		for (const asset of assets) {
			const key = `${asset.repoUserName}/${asset.repoName}`;
			const list = map.get(key) ?? [];
			list.push(asset);
			map.set(key, list);
		}
		return Array.from(map.entries());
	}, [assets]);

	const totalSize = useMemo(
		() => assets.reduce((sum, asset) => sum + asset.size, 0),
		[assets],
	);

	const fetchReleases = useCallback(
		async (isRefresh: boolean) => {
			if (isRefresh) setRefreshing(true);
			else setLoading(true);
			setErrorMessage(null);
			try {
				const result = await fetchAllReposAssets(
					repos.map((r) => ({
						userName: r.userName,
						repoName: r.repoName,
					})),
				);
				setAssets(result.assets);
				setErrorMessage(result.errorMessage);
			} finally {
				setLoading(false);
				setRefreshing(false);
			}
		},
		[repos],
	);

	useEffect(() => {
		let disposed = false;
		(async () => {
			const list = await loadRepoDataList();
			if (!disposed) setRepos(list);
		})();
		return () => {
			disposed = true;
		};
	}, []);

	useEffect(() => {
		if (repos.length === 0) {
			setLoading(false);
			return;
		}
		fetchReleases(false);
	}, [repos, fetchReleases]);

	if (loading) {
		return (
			<SafeAreaView className="bg-background flex-1" edges={["left", "right"]}>
				<ScreenHeader title="All Apps" subtitle="Loading latest releases…" />
			</SafeAreaView>
		);
	}

	return (
		<SafeAreaView className="bg-background flex-1" edges={["left", "right"]}>
			<ScreenHeader
				title="All Apps"
				subtitle={`${repos.length} ${repos.length === 1 ? "repo" : "repos"} · ${formatSize(totalSize)} available`}
			/>

			{repos.length === 0 ? (
				<EmptyState
					icon={Download}
					title="No repositories yet"
					description="Add a GitHub repo to start downloading patched apps."
					action={
						<Button size="sm" onPress={() => router.push("/(tabs)/explore")}>
							<ButtonText>Go to Repositories</ButtonText>
						</Button>
					}
				/>
			) : (
				<ScrollView
					className="flex-1"
					refreshControl={
						<RefreshControl
							refreshing={refreshing}
							onRefresh={() => fetchReleases(true)}
						/>
					}
					contentContainerStyle={{ paddingBottom: 32 }}
				>
					{grouped.length === 0 ? (
						<EmptyState
							icon={Download}
							title="No assets yet"
							description={errorMessage ?? "Pull to refresh and try again."}
						/>
					) : (
						grouped.map(([key, list]) => (
							<View key={key} className="pb-4">
								<View className="px-5 pb-1 pt-3">
									<Text className="text-muted-foreground text-xs font-semibold tracking-wider uppercase">
										{key}
									</Text>
								</View>
								{list.map((asset) => (
									<AppAssetRow
										key={asset.id}
										asset={asset}
										onPress={() => {
											setActionAsset(asset);
											setSheetOpen(true);
										}}
									/>
								))}
							</View>
						))
					)}
				</ScrollView>
			)}

			<AssetActionsheet
				isOpen={sheetOpen}
				onClose={() => setSheetOpen(false)}
				asset={actionAsset}
				repo={
					actionAsset
						? {
								userName: actionAsset.repoUserName,
								repoName: actionAsset.repoName,
							}
						: null
				}
				onDownload={(asset: GithubAsset | RepoAsset) => {
					if (downloadCoordinator.isRunning) return;
					setProgressVisible(true);
					downloadCoordinator
						.startDownload(
							{
								name: asset.name,
								url: asset.downloadUrl,
								digest: asset.digest,
							},
							{
								onCompleted: () => setProgressVisible(false),
								onError: () => setProgressVisible(false),
								onCancelled: () => setProgressVisible(false),
							},
						)
						.catch(() => setProgressVisible(false));
				}}
			/>

			<DownloadProgressModal
				visible={progressVisible}
				assetName={actionAsset?.name ?? ""}
				onClose={() => setProgressVisible(false)}
			/>
		</SafeAreaView>
	);
}

function formatSize(bytes: number): string {
	if (bytes <= 0) return "0 B";
	if (bytes < 1024) return `${bytes} B`;
	if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
	if (bytes < 1024 * 1024 * 1024)
		return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
	return `${(bytes / (1024 * 1024 * 1024)).toFixed(2)} GB`;
}
