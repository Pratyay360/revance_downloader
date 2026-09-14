import { FlashList } from "@shopify/flash-list";
import { ChevronRight, Puzzle } from "lucide-react-native";
import React from "react";
import { Image, Pressable, RefreshControl, View } from "react-native";

import { Text } from "@/components/ui/text";
import {
	attachIconForAsset,
	formatBytes,
	type GithubAsset,
	type RepoAsset,
} from "@/lib/github-releases";

interface AssetListProps {
	assets: (GithubAsset | RepoAsset)[];
	onAssetPress: (asset: GithubAsset | RepoAsset) => void;
	refreshing?: boolean;
	onRefresh?: () => void;
	emptyMessage?: string;
}

function AssetCard({
	asset,
	onPress,
}: {
	asset: GithubAsset | RepoAsset;
	onPress: () => void;
}) {
	return (
		<Pressable
			onPress={onPress}
			className="bg-card mx-4 my-1.5 rounded-xl border border-border/60 px-4 py-3 active:opacity-70"
		>
			<View className="flex-row items-center gap-3">
				<View className="h-10 w-10 items-center justify-center rounded-lg bg-secondary">
					{asset.imageLink ? (
						<Image
							source={{ uri: asset.imageLink }}
							className="h-8 w-8 rounded-md"
							resizeMode="cover"
						/>
					) : (
						<Puzzle size={22} className="text-muted-foreground" />
					)}
				</View>
				<View className="flex-1">
					<Text className="font-semibold" numberOfLines={1}>
						{asset.name}
					</Text>
					<Text className="text-muted-foreground text-xs">
						{"repoUserName" in asset
							? `${asset.repoUserName}/${asset.repoName} · ${formatBytes(asset.size)}`
							: formatBytes(asset.size)}
					</Text>
				</View>
				<ChevronRight size={18} className="text-muted-foreground" />
			</View>
		</Pressable>
	);
}

/**
 * Port of the asset ListView from download_page.dart. Kick off icon metadata
 * fetches the same way _fetchMetadataForAssets did (best-effort, in background).
 */
export function AssetList({
	assets,
	onAssetPress,
	refreshing,
	onRefresh,
	emptyMessage = "No assets found.",
}: AssetListProps) {
	// Fire icon lookups once per list identity; mutate asset objects directly,
	// matching the Flutter app's behavior.
	React.useEffect(() => {
		let cancelled = false;
		(async () => {
			for (const asset of assets) {
				if (cancelled) return;
				await attachIconForAsset(asset);
			}
		})();
		return () => {
			cancelled = true;
		};
	}, [assets]);

	if (assets.length === 0) {
		return (
			<View className="flex-1 items-center justify-center p-8">
				<Text className="text-muted-foreground text-center">
					{emptyMessage}
				</Text>
			</View>
		);
	}

	return (
		<FlashList
			data={assets}
			keyExtractor={(item, index) => `${item.id}-${index}`}
			renderItem={({ item }) => (
				<AssetCard asset={item} onPress={() => onAssetPress(item)} />
			)}
			refreshControl={
				onRefresh ? (
					<RefreshControl
						refreshing={refreshing ?? false}
						onRefresh={onRefresh}
					/>
				) : undefined
			}
		/>
	);
}
