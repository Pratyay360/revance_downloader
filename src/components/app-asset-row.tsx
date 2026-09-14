import { Image } from "expo-image";
import { ChevronRight, Download, FolderOpen } from "lucide-react-native";
import { useEffect, useState } from "react";
import { Pressable, View } from "react-native";

import { StatPill } from "@/components/stat-pill";
import { Text } from "@/components/ui/text";
import {
	attachIconForAsset,
	formatBytes,
	type GithubAsset,
	type RepoAsset,
} from "@/lib/github-releases";

/**
 * Single asset row used by every list view. `attachIconForAsset` mutates the
 * asset's `imageLink` in place once the lookup resolves, so we mirror that
 * state locally to trigger a re-render — same pattern as the original
 * `AssetList` card.
 */
export interface AppAssetRowProps {
	asset: GithubAsset | RepoAsset;
	onPress?: () => void;
}

export function AppAssetRow({ asset, onPress }: AppAssetRowProps) {
	const [iconUri, setIconUri] = useState<string | null>(
		asset.imageLink ?? null,
	);

	useEffect(() => {
		let cancelled = false;
		attachIconForAsset(asset).then(() => {
			if (!cancelled && asset.imageLink && asset.imageLink !== iconUri) {
				setIconUri(asset.imageLink);
			}
		});
		return () => {
			cancelled = true;
		};
	}, [asset, iconUri]);

	const repoLine =
		"repoUserName" in asset ? `${asset.repoUserName}/${asset.repoName}` : null;

	return (
		<Pressable
			onPress={onPress}
			className="active:bg-accent mx-3 flex-row items-center gap-3 rounded-2xl px-4 py-3"
			accessibilityRole="button"
			accessibilityLabel={`Download ${asset.name}`}
		>
			<View className="bg-secondary h-12 w-12 items-center justify-center overflow-hidden rounded-xl">
				{iconUri ? (
					<Image
						source={{ uri: iconUri }}
						className="h-12 w-12"
						contentFit="cover"
					/>
				) : (
					<Download size={22} className="text-muted-foreground" />
				)}
			</View>
			<View className="flex-1">
				<Text
					className="text-foreground text-base font-semibold"
					numberOfLines={1}
				>
					{asset.name}
				</Text>
				<View className="mt-1 flex-row items-center gap-2">
					<StatPill label={formatBytes(asset.size)} tone="neutral" />
					{repoLine ? (
						<View className="flex-row items-center gap-1">
							<FolderOpen size={12} className="text-muted-foreground" />
							<Text className="text-muted-foreground text-xs" numberOfLines={1}>
								{repoLine}
							</Text>
						</View>
					) : null}
				</View>
			</View>
			<ChevronRight size={18} className="text-muted-foreground" />
		</Pressable>
	);
}
