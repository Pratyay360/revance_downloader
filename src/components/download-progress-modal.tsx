import { View } from "react-native";

import { Button, ButtonText } from "@/components/ui/button";
import {
	Modal,
	ModalBackdrop,
	ModalBody,
	ModalContent,
	ModalFooter,
	ModalHeader,
} from "@/components/ui/modal";
import { Progress, ProgressFilledTrack } from "@/components/ui/progress";
import { Text } from "@/components/ui/text";
import { useDownloadProgress } from "@/hooks/use-download-progress";
import { downloadCoordinator } from "@/services/download-coordinator";

interface DownloadProgressModalProps {
	visible: boolean;
	assetName: string;
	onClose: () => void;
	onCancelled?: () => void;
}

/**
 * Port of _showDownloadDialog from download_page.dart — non-dismissible modal
 * with live progress bar, percentage, status text and a cancel button.
 */
export function DownloadProgressModal({
	visible,
	assetName,
	onClose,
	onCancelled,
}: DownloadProgressModalProps) {
	const { progress, status } = useDownloadProgress();
	const isPercent = status.trim().endsWith("%");

	const handleCancel = () => {
		downloadCoordinator.cancelDownload();
		onClose();
		onCancelled?.();
	};

	return (
		<Modal
			isOpen={visible}
			onClose={onClose}
			closeOnOverlayClick={false}
			isKeyboardDismissable={false}
			size="md"
		>
			<ModalBackdrop />
			<ModalContent>
				<ModalHeader>
					<View className="flex-1">
						<Text className="text-muted-foreground text-sm">Downloading</Text>
						<Text className="text-xl font-bold" numberOfLines={2}>
							{assetName}
						</Text>
					</View>
				</ModalHeader>
				<ModalBody>
					<View className="gap-3">
						<Progress value={Math.round(progress * 100)} className="h-3">
							<ProgressFilledTrack className="bg-primary" />
						</Progress>
						<Text className="text-base font-bold">
							{(progress * 100).toFixed(0)}%
						</Text>
						{!isPercent && status.length > 0 && (
							<Text className="text-muted-foreground text-sm">{status}</Text>
						)}
					</View>
				</ModalBody>
				<ModalFooter>
					<Button variant="ghost" action="negative" onPress={handleCancel}>
						<ButtonText className="text-destructive">
							Cancel Download
						</ButtonText>
					</Button>
				</ModalFooter>
			</ModalContent>
		</Modal>
	);
}
