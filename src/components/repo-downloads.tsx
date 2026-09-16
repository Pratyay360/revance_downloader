import { Download } from "lucide-react-native";
import { useCallback, useEffect, useMemo, useState } from "react";
import { RefreshControl, ScrollView, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { AppAssetRow } from "@/components/app-asset-row";
import { AssetActionsheet } from "@/components/asset-actionsheet";
import { DownloadProgressModal } from "@/components/download-progress-modal";
import { EmptyState } from "@/components/empty-state";
import { ScreenHeader } from "@/components/screen-header";
import {
	fetchAllReposAssets,
	fetchLatestReleaseAssets,
	type GithubAsset,
	type RepoAsset,
} from "@/lib/github-releases";
import type { RepoData } from "@/lib/repo-data";
import { downloadCoordinator } from "@/services/download-coordinator";

interface RepoDownloadsProps {
	/** null repo = All Apps view (fetch across all repos) */
	repos: RepoData[];
	/** when set, single-repo mode for this entry */
	selected?: RepoData | null;
	onRepoChanged?: (index: number) => void;
	title: string;
}

/**
 * Polished list of installable assets for one or more repos. Shows a
 * back affordance only when invoked from a single-repo navigation stack.
 */
export function RepoDownloads({ repos, selected, title }: RepoDownloadsProps) {
	const [assets, setAssets] = useState<(GithubAsset | RepoAsset)[]>([]);
	const [loading, setLoading] = useState(true);
	const [refreshing, setRefreshing] = useState(false);
	const [errorMessage, setErrorMessage] = useState<string | null>(null);
	const [actionAsset, setActionAsset] = useState<
		GithubAsset | RepoAsset | null
	>(null);
	const [sheetOpen, setSheetOpen] = useState(false);
	const [progressVisible, setProgressVisible] = useState(false);

	const isAllApps = !selected;

	const startDownload = useMemo(
		() =>
			function start(asset: GithubAsset | RepoAsset) {
				if (downloadCoordinator.isRunning) return;
				setProgressVisible(true);
				downloadCoordinator
					.startDownload(
						{ name: asset.name, url: asset.downloadUrl, digest: asset.digest },
						{
							onCompleted: () => setProgressVisible(false),
							onError: () => setProgressVisible(false),
							onCancelled: () => setProgressVisible(false),
						},
					)
					.catch(() => setProgressVisible(false));
			},
		[],
	);

	const fetchReleases = useCallback(
		async (isRefresh: boolean) => {
			if (isRefresh) setRefreshing(true);
			else setLoading(true);
			setErrorMessage(null);

			try {
				if (isAllApps) {
					const result = await fetchAllReposAssets(
						repos.map((r) => ({ userName: r.userName, repoName: r.repoName })),
					);
					setAssets(result.assets);
					setErrorMessage(result.errorMessage);
				} else {
					const result = await fetchLatestReleaseAssets(
						selected.userName,
						selected.repoName,
					);
					setAssets(result.assets);
					setErrorMessage(
						result.errorMessage ??
							(result.assets.length === 0 ? "No assets found." : null),
					);
				}
			} finally {
				setLoading(false);
				setRefreshing(false);
			}
		},
		[isAllApps, repos, selected],
	);

	useEffect(() => {
		let cancelled = false;
		(async () => {
			if (!cancelled) await fetchReleases(false);
		})();
		return () => {
			cancelled = true;
		};
	}, [fetchReleases]);

	if (loading) {
		return (
			<SafeAreaView className="bg-background flex-1" edges={["top"]}>
				<ScreenHeader
					title={title}
					back={!isAllApps ? "Repos" : undefined}
					subtitle="Loading latest release…"
				/>
			</SafeAreaView>
		);
	}

	return (
		<SafeAreaView className="bg-background flex-1" edges={["top"]}>
			<ScreenHeader
				title={title}
				back={!isAllApps ? "Repos" : undefined}
				subtitle={
					assets.length > 0
						? `${assets.length} ${assets.length === 1 ? "asset" : "assets"} available`
						: undefined
				}
			/>

			{assets.length === 0 ? (
				<EmptyState
					icon={Download}
					title="No assets found"
					description={errorMessage ?? "Pull to refresh and try again."}
				/>
			) : (
				<ScrollView
					style={{ flex: 1 }}
					refreshControl={
						<RefreshControl
							refreshing={refreshing}
							onRefresh={() => fetchReleases(true)}
						/>
					}
					contentContainerStyle={{ paddingBottom: 32 }}
				>
					{assets.map((asset, idx) => (
						<View key={asset.id}>
							<AppAssetRow
								asset={asset}
								onPress={() => {
									setActionAsset(asset);
									setSheetOpen(true);
								}}
							/>
							{idx < assets.length - 1 && (
								<View className="ml-16 h-px bg-border/60" />
							)}
						</View>
					))}
				</ScrollView>
			)}

			<AssetActionsheet
				isOpen={sheetOpen}
				onClose={() => setSheetOpen(false)}
				asset={actionAsset}
				repo={
					"repoUserName" in (actionAsset ?? {})
						? {
								userName: (actionAsset as RepoAsset).repoUserName,
								repoName: (actionAsset as RepoAsset).repoName,
							}
						: selected
				}
				onDownload={startDownload}
			/>

			<DownloadProgressModal
				visible={progressVisible}
				assetName={actionAsset?.name ?? ""}
				onClose={() => setProgressVisible(false)}
			/>
		</SafeAreaView>
	);
}
