import * as WebBrowser from "expo-web-browser";
import { Download, Globe } from "lucide-react-native";
import { Linking, View } from "react-native";

import {
	Actionsheet,
	ActionsheetBackdrop,
	ActionsheetContent,
	ActionsheetDragIndicator,
	ActionsheetDragIndicatorWrapper,
	ActionsheetIcon,
	ActionsheetItem,
	ActionsheetItemText,
} from "@/components/ui/actionsheet";
import { Text } from "@/components/ui/text";
import type { GithubAsset, RepoAsset } from "@/lib/github-releases";

interface AssetActionsheetProps {
	isOpen: boolean;
	onClose: () => void;
	asset: GithubAsset | null;
	repo?: { userName: string; repoName: string } | null;
	onDownload: (asset: GithubAsset) => void;
}

/**
 * Bottom sheet that confirms what to do with an asset: download & install
 * or open the URL in a browser. Both actions dismiss the sheet before
 * starting the action so the user can keep tapping rows without overlap.
 */
export function AssetActionsheet({
	isOpen,
	onClose,
	asset,
	repo,
	onDownload,
}: AssetActionsheetProps) {
	const openInBrowser = async (url: string) => {
		try {
			if (await Linking.canOpenURL(url)) {
				await Linking.openURL(url);
				return;
			}
		} catch {
			// fall back to in-app browser
		}
		await WebBrowser.openBrowserAsync(url).catch(() => undefined);
	};

	if (!asset) return null;

	// `RepoAsset` carries `repoUserName`/`repoName`, but this sheet renders
	// `userName`/`repoName`. Normalize so `From x/y` never prints undefined.
	const fromRepo: { userName: string; repoName: string } | null =
		repo ??
		("repoUserName" in asset
			? {
					userName: (asset as RepoAsset).repoUserName,
					repoName: (asset as RepoAsset).repoName,
				}
			: null);

	return (
		<Actionsheet isOpen={isOpen} onClose={onClose}>
			<ActionsheetBackdrop />
			<ActionsheetContent>
				<ActionsheetDragIndicatorWrapper>
					<ActionsheetDragIndicator />
				</ActionsheetDragIndicatorWrapper>

				<View className="px-5 pt-2 pb-3">
					<Text className="text-muted-foreground text-xs font-semibold tracking-wider uppercase">
						Asset
					</Text>
					<Text
						className="text-foreground mt-1 text-lg font-bold"
						numberOfLines={2}
					>
						{asset.name}
					</Text>
					{fromRepo ? (
						<Text className="text-muted-foreground mt-1 text-sm">
							From {fromRepo.userName}/{fromRepo.repoName}
						</Text>
					) : (
						<Text className="text-muted-foreground mt-1 text-sm">
							Choose how to handle this file.
						</Text>
					)}
				</View>

				<ActionsheetItem
					onPress={() => {
						onClose();
						onDownload(asset);
					}}
				>
					<ActionsheetIcon as={Download} />
					<ActionsheetItemText>Download &amp; Install</ActionsheetItemText>
				</ActionsheetItem>
				<ActionsheetItem
					onPress={() => {
						onClose();
						openInBrowser(asset.downloadUrl);
					}}
				>
					<ActionsheetIcon as={Globe} />
					<ActionsheetItemText>Open in Browser</ActionsheetItemText>
				</ActionsheetItem>
			</ActionsheetContent>
		</Actionsheet>
	);
}
