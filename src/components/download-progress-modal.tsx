import { Download } from "lucide-react-native";
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
 * Non-dismissible modal showing the live download state for the active
 * asset. Uses a tinted icon well + percentage badge so the user always
 * sees both the brand color and the current speed/status.
 */
export function DownloadProgressModal({
	visible,
	assetName,
	onClose,
	onCancelled,
}: DownloadProgressModalProps) {
	const { progress, status } = useDownloadProgress();
	const isPercent = status.trim().endsWith("%");
	const percent = Math.round(progress * 100);

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
					<View className="flex-row items-center gap-3">
						<View className="bg-primary-soft h-12 w-12 items-center justify-center rounded-2xl">
							<Download size={22} className="text-primary" strokeWidth={1.75} />
						</View>
						<View className="flex-1">
							<Text className="text-muted-foreground text-xs font-semibold tracking-wider uppercase">
								Downloading
							</Text>
							<Text
								className="text-foreground text-lg font-bold"
								numberOfLines={2}
							>
								{assetName}
							</Text>
						</View>
					</View>
				</ModalHeader>
				<ModalBody>
					<View className="gap-4">
						<Progress value={percent} className="bg-muted h-2.5 rounded-full">
							<ProgressFilledTrack className="bg-primary rounded-full" />
						</Progress>
						<View className="flex-row items-center justify-between">
							<Text className="text-muted-foreground text-sm">
								{isPercent
									? status
									: status.length > 0
										? status
										: "Connecting…"}
							</Text>
							<Text className="text-foreground text-base font-bold">
								{percent}%
							</Text>
						</View>
					</View>
				</ModalBody>
				<ModalFooter>
					<Button variant="ghost" onPress={handleCancel}>
						<ButtonText className="text-destructive">Cancel</ButtonText>
					</Button>
				</ModalFooter>
			</ModalContent>
		</Modal>
	);
}
