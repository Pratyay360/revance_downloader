import { styled } from "nativewind";
import { SafeAreaView as NativeSafeAreaView } from "react-native-safe-area-context";

/**
 * Safe-area screen root with working `className`.
 *
 * NativeWind v5 only translates `className` into styles for the core React
 * Native components and for anything wrapped in `styled()`. The
 * `react-native-safe-area-context` `SafeAreaView` is a native host component,
 * so `className="bg-background flex-1"` was silently dropped: every screen root
 * sized itself to its content instead of the viewport, which left the `flex: 1`
 * children (the asset and repo lists) collapsed to zero height — a header with
 * an empty screen under it.
 *
 * Keep the wrapper at module scope so its component identity stays stable.
 */
export const SafeAreaView = styled(NativeSafeAreaView, { className: "style" });
