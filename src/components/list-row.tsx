import type { ComponentType } from "react";
import { Pressable, View } from "react-native";

import { Text } from "@/components/ui/text";

/**
 * Grouped-list row primitive. Composes the leading icon, primary/secondary
 * text, and an optional trailing accessory into a tappable, native-looking row.
 * No outer card chrome — rows separate with hairline dividers, so the screen
 * keeps one continuous surface instead of stacking white boxes (the
 * "Everything's a Card" anti-pattern).
 */
export interface ListRowProps {
	title: string;
	subtitle?: string;
	leading?: React.ReactNode;
	trailing?: React.ReactNode;
	onPress?: () => void;
	disabled?: boolean;
	destructive?: boolean;
	hint?: string;
}

export function ListRow({
	title,
	subtitle,
	leading,
	trailing,
	onPress,
	disabled,
	destructive,
	hint,
}: ListRowProps) {
	const Container: ComponentType<{
		children: React.ReactNode;
		className?: string;
		onPress?: () => void;
		disabled?: boolean;
		accessibilityRole?: "button";
		accessibilityLabel?: string;
		accessibilityState?: { disabled: boolean };
	}> = onPress ? Pressable : View;
	const a11yLabel = hint ?? title;

	return (
		<Container
			onPress={onPress}
			disabled={disabled}
			accessibilityRole={onPress ? "button" : undefined}
			accessibilityLabel={onPress ? a11yLabel : undefined}
			accessibilityState={onPress ? { disabled: !!disabled } : undefined}
			className={`flex-row items-center gap-3 px-5 py-3 ${
				onPress ? "active:bg-accent" : ""
			} ${disabled ? "opacity-40" : ""}`}
		>
			{leading}
			<View className="flex-1">
				<Text
					className={`text-base font-semibold ${destructive ? "text-destructive" : "text-foreground"}`}
					numberOfLines={1}
				>
					{title}
				</Text>
				{subtitle ? (
					<Text
						className="text-muted-foreground mt-0.5 text-xs"
						numberOfLines={1}
					>
						{subtitle}
					</Text>
				) : null}
			</View>
			{trailing}
		</Container>
	);
}
