import { useRouter } from "expo-router";
import { Download } from "lucide-react-native";
import { useCallback, useEffect, useMemo, useState } from "react";
import { RefreshControl, ScrollView, View } from "react-native";

import { AppAssetRow } from "@/components/app-asset-row";
import { AssetActionsheet } from "@/components/asset-actionsheet";
import { DownloadProgressModal } from "@/components/download-progress-modal";
import { EmptyState } from "@/components/empty-state";
import { SafeAreaView } from "@/components/safe-area-view";
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
	const [reposLoaded, setReposLoaded] = useState(false);
	const [fetchInFlight, setFetchInFlight] = useState(false);
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

	// The setState calls below all live inside Promise callbacks, not inside an
	// effect body, so the "set-state-in-effect" lint rule is satisfied. State
	// derives the "loading" view: we show the loading header until repos have
	// loaded AND either there are no repos to fetch from or the first fetch
	// has resolved.
	const loading = !reposLoaded || (fetchInFlight && assets.length === 0);

	const fetchReleases = useCallback(
		async (isRefresh: boolean, reposForFetch: RepoData[]) => {
			if (isRefresh) setRefreshing(true);
			else setFetchInFlight(true);
			setErrorMessage(null);
			try {
				const result = await fetchAllReposAssets(
					reposForFetch.map((r) => ({
						userName: r.userName,
						repoName: r.repoName,
					})),
				);
				setAssets(result.assets);
				setErrorMessage(result.errorMessage);
			} finally {
				setFetchInFlight(false);
				setRefreshing(false);
			}
		},
		[],
	);

	const refresh = useCallback(() => {
		void fetchReleases(true, repos);
	}, [fetchReleases, repos]);

	// Kick off the initial load once on mount. Previously this lived in a
	// `useState` lazy initializer (a render-phase side effect): double-invoked
	// in StrictMode, causing duplicate fetches and setState-during-render.
	useEffect(() => {
		let cancelled = false;
		void loadRepoDataList()
			.then((list) => {
				if (cancelled) return;
				setRepos(list);
				setReposLoaded(true);
				if (list.length > 0) {
					void fetchReleases(false, list);
				}
			})
			.catch(() => {
				if (!cancelled) setReposLoaded(true);
			});
		return () => {
			cancelled = true;
		};
	}, [fetchReleases]);

	if (loading) {
		return (
			<SafeAreaView className="bg-background flex-1" edges={["top"]}>
				<ScreenHeader title="All Apps" subtitle="Loading latest releases…" />
			</SafeAreaView>
		);
	}

	return (
		<SafeAreaView className="bg-background flex-1" edges={["top"]}>
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
						<Button size="sm" onPress={() => router.push("/explore")}>
							<ButtonText>Go to Repositories</ButtonText>
						</Button>
					}
				/>
			) : (
				<ScrollView
					style={{ flex: 1 }}
					refreshControl={
						<RefreshControl refreshing={refreshing} onRefresh={refresh} />
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
								{list.map((asset, idx) => (
									<View key={asset.downloadUrl || asset.name}>
										<AppAssetRow
											asset={asset}
											onPress={() => {
												setActionAsset(asset);
												setSheetOpen(true);
											}}
										/>
										{idx < list.length - 1 && (
											<View className="ml-16 h-px bg-border/60" />
										)}
									</View>
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
