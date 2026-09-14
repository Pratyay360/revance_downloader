/**
 * Theme tokens for code that can't consume Tailwind classes — native tabs,
 * inline `style` props, Reanimated worklets. Keep this in sync with
 * `src/global.css` (light/dark CSS variables drive the className API).
 */

import "@/global.css";

import { Platform } from "react-native";

export const Colors = {
	light: {
		text: "#18181b",
		background: "#fafafc",
		backgroundElement: "#f4f4f5",
		backgroundSelected: "#e4e4e7",
		textSecondary: "#71717a",
		tint: "#4f46e5",
		border: "#e4e4e7",
		card: "#ffffff",
		destructive: "#dc2626",
		success: "#16a34a",
	},
	dark: {
		text: "#fafafa",
		background: "#09090b",
		backgroundElement: "#27272a",
		backgroundSelected: "#3f3f46",
		textSecondary: "#a1a1aa",
		tint: "#818cf8",
		border: "#27272a",
		card: "#18181b",
		destructive: "#f87171",
		success: "#4ade80",
	},
} as const;

export type ThemeColor = keyof typeof Colors.light & keyof typeof Colors.dark;

export const Fonts = Platform.select({
	ios: {
		/** iOS `UIFontDescriptorSystemDesignDefault` */
		sans: "system-ui",
		/** iOS `UIFontDescriptorSystemDesignSerif` */
		serif: "ui-serif",
		/** iOS `UIFontDescriptorSystemDesignRounded` */
		rounded: "ui-rounded",
		/** iOS `UIFontDescriptorSystemDesignMonospaced` */
		mono: "ui-monospace",
	},
	default: {
		sans: "normal",
		serif: "serif",
		rounded: "normal",
		mono: "monospace",
	},
	web: {
		sans: "var(--font-display)",
		serif: "var(--font-serif)",
		rounded: "var(--font-rounded)",
		mono: "var(--font-mono)",
	},
});

/**
 * 4-point spacing scale. Use these in `style` props; for className code
 * prefer Tailwind's `gap-`/`p-`/`m-` utilities keyed off the same scale.
 */
export const Spacing = {
	xxs: 2,
	xs: 4,
	sm: 8,
	md: 12,
	lg: 16,
	xl: 20,
	xxl: 24,
	"3xl": 32,
	"4xl": 40,
	"5xl": 56,
	"6xl": 72,
} as const;

/**
 * Corner radii. Pair every non-full radius with `borderCurve: "continuous"`
 * (handled inside the reusable components) for iOS-native squircles.
 */
export const Radius = {
	xs: 6,
	sm: 10,
	md: 14,
	lg: 20,
	xl: 28,
	full: 9999,
} as const;

export const BottomTabInset = Platform.select({ ios: 50, android: 80 }) ?? 0;
export const MaxContentWidth = 800;

/**
 * Animation durations (ms). State feedback → fast; transitions → base;
 * sheets/large surfaces → slow. Components can multiply by `easing` to
 * define a complete motion preset.
 */
export const Motion = {
	fast: 150,
	base: 250,
	slow: 400,
} as const;
