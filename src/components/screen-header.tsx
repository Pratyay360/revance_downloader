import { useRouter } from "expo-router";
import { ChevronLeft } from "lucide-react-native";
import type { ReactNode } from "react";
import { Pressable, View } from "react-native";

import { Text } from "@/components/ui/text";

/**
 * Large-title screen header used by every top-level route. Matches the iOS
 * Settings-style large title (left aligned, hairline divider when `withDivider`
 * is set) so we keep one rhythm across the app instead of a per-screen header.
 */
export interface ScreenHeaderProps {
	title: string;
	subtitle?: string;
	right?: ReactNode;
	withDivider?: boolean;
	back?: boolean | string;
}

export function ScreenHeader({
	title,
	subtitle,
	right,
	withDivider,
	back,
}: ScreenHeaderProps) {
	const router = useRouter();
	return (
		<View
			className={`px-5 pb-3 pt-2 ${withDivider ? "border-b border-border/60" : ""}`}
		>
			<View className="flex-row items-center justify-between">
				{back ? (
					<Pressable
						onPress={() => {
							if (router.canGoBack()) router.back();
						}}
						hitSlop={12}
						className="-ml-2 mr-2 flex-row items-center gap-1 active:opacity-60"
						accessibilityRole="button"
						accessibilityLabel={
							typeof back === "string" ? `Back to ${back}` : "Go back"
						}
					>
						<ChevronLeft size={20} className="text-primary" />
						<Text className="text-primary text-sm font-medium">
							{typeof back === "string" ? back : ""}
						</Text>
					</Pressable>
				) : (
					<View className="flex-1" />
				)}
				{right ? (
					<View className="flex-row items-center gap-2">{right}</View>
				) : null}
			</View>
			<View className="mt-1">
				<Text
					className="text-foreground text-3xl font-bold tracking-tight"
					numberOfLines={2}
				>
					{title}
				</Text>
				{subtitle ? (
					<Text className="text-muted-foreground mt-0.5 text-sm">
						{subtitle}
					</Text>
				) : null}
			</View>
		</View>
	);
}
