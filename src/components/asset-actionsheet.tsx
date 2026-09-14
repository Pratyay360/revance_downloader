import * as WebBrowser from "expo-web-browser";
import { Download, Globe } from "lucide-react-native";
import { Linking } from "react-native";
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
 * Port of _showActionOptions from download_page.dart — bottom sheet with
 * "Download & Install" and "Open in Browser" actions.
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
			}
		} catch (e) {
			// fall back to in-app browser
			await WebBrowser.openBrowserAsync(url).catch(() => undefined);
			void e;
		}
	};

	if (!asset) return null;

	const fromRepo =
		repo ?? ("repoUserName" in asset ? (asset as RepoAsset) : null);

	return (
		<Actionsheet isOpen={isOpen} onClose={onClose}>
			<ActionsheetBackdrop />
			<ActionsheetContent>
				<ActionsheetDragIndicatorWrapper>
					<ActionsheetDragIndicator />
				</ActionsheetDragIndicatorWrapper>

				<Text className="px-4 pt-2 text-lg font-semibold" numberOfLines={2}>
					Action for {asset.name}
				</Text>
				<Text className="text-muted-foreground px-4 pb-2 text-sm">
					{fromRepo
						? `From: ${fromRepo.userName}/${fromRepo.repoName}`
						: "Choose how you want to handle this file."}
				</Text>

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
