import { useRouter } from "expo-router";
import { Settings } from "lucide-react-native";
import { useCallback, useEffect, useMemo, useState } from "react";
import { View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { AssetActionsheet } from "@/components/asset-actionsheet";
import { AssetList } from "@/components/asset-list";
import { DownloadProgressModal } from "@/components/download-progress-modal";
import { Button } from "@/components/ui/button";
import { Text } from "@/components/ui/text";
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
 * Port of DownloadPage + AllAppsView from download_page.dart — fetches latest
 * release assets, shows them in a list, and handles download & install flow.
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

	const startDownload = useMemo(
		() =>
			function start(asset: GithubAsset | RepoAsset) {
				if (downloadCoordinator.isRunning) return;
				setProgressVisible(true);
				downloadCoordinator
					.startDownload(
						{ name: asset.name, url: asset.downloadUrl, digest: asset.digest },
						{
							onCompleted: () => {
								setProgressVisible(false);
							},
							onError: () => {
								setProgressVisible(false);
							},
							onCancelled: () => {
								setProgressVisible(false);
							},
						},
					)
					.catch(() => setProgressVisible(false));
			},
		[],
	);

	if (loading) {
		return (
			<SafeAreaView className="flex-1 bg-background" edges={["left", "right"]}>
				<Header title={title} />
				<View className="flex-1 items-center justify-center">
					<Text className="text-muted-foreground">Loading…</Text>
				</View>
			</SafeAreaView>
		);
	}

	return (
		<SafeAreaView className="flex-1 bg-background" edges={["left", "right"]}>
			<Header title={title} />

			{errorMessage && assets.length === 0 ? (
				<View className="flex-1 items-center justify-center p-8">
					<Text className="text-muted-foreground text-center">
						{errorMessage}
					</Text>
				</View>
			) : (
				<AssetList
					assets={assets}
					onAssetPress={(asset) => {
						setActionAsset(asset);
						setSheetOpen(true);
					}}
					refreshing={refreshing}
					onRefresh={() => fetchReleases(true)}
					emptyMessage={errorMessage ?? "No assets found."}
				/>
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

function Header({ title }: { title: string }) {
	const router = useRouter();
	return (
		<View className="flex-row items-center justify-between px-4 py-3">
			<Text className="text-xl font-bold" numberOfLines={1} style={{ flex: 1 }}>
				{title}
			</Text>
			<Button
				variant="ghost"
				size="sm"
				onPress={() => router.push("/repos")}
				accessibilityLabel="Manage Repositories"
			>
				<Settings size={20} className="text-foreground" />
			</Button>
		</View>
	);
}
