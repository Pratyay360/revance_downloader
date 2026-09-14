import { View } from "react-native";

import { Text } from "@/components/ui/text";

/**
 * Small, non-interactive badge for surfacing metadata next to a row title
 * (e.g. file size, repo count). Sits on `bg-secondary` so it stays legible
 * across both modes without competing with the primary accent.
 */
export interface StatPillProps {
	label: string;
	tone?: "neutral" | "primary" | "success" | "warning" | "destructive";
}

const TONE_CLASSES: Record<NonNullable<StatPillProps["tone"]>, string> = {
	neutral: "bg-secondary text-secondary-foreground",
	primary: "bg-primary-soft text-primary",
	success: "bg-success/15 text-success",
	warning: "bg-warning/15 text-warning",
	destructive: "bg-destructive/15 text-destructive",
};

export function StatPill({ label, tone = "neutral" }: StatPillProps) {
	return (
		<View
			className={`self-start rounded-full px-2.5 py-1 ${TONE_CLASSES[tone]}`}
		>
			<Text className="text-[11px] font-semibold tracking-wide uppercase">
				{label}
			</Text>
		</View>
	);
}
