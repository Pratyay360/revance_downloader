import type { LucideIcon } from "lucide-react-native";
import type { ReactNode } from "react";
import { View } from "react-native";

import { Text } from "@/components/ui/text";

/**
 * Empty / error state with a tinted icon well, headline, supporting copy,
 * and an optional CTA. Use this for every screen's loading → empty transition
 * so we never flash a spinner in place of meaningful content.
 */
export interface EmptyStateProps {
	icon: LucideIcon;
	title: string;
	description?: string;
	action?: ReactNode;
}

export function EmptyState({
	icon: Icon,
	title,
	description,
	action,
}: EmptyStateProps) {
	return (
		<View className="flex-1 items-center justify-center gap-4 px-8 py-16">
			<View className="bg-primary-soft items-center justify-center rounded-2xl p-4">
				<Icon size={36} className="text-primary" strokeWidth={1.75} />
			</View>
			<View className="items-center gap-1.5">
				<Text className="text-foreground text-lg font-semibold">{title}</Text>
				{description ? (
					<Text className="text-muted-foreground text-center text-sm leading-5">
						{description}
					</Text>
				) : null}
			</View>
			{action ? <View className="mt-2">{action}</View> : null}
		</View>
	);
}
