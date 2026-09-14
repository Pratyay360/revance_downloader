import { useEffect, useState } from "react";
import { useColorScheme as useRNColorScheme } from "react-native";

/**
 * To support static rendering, this value needs to be re-calculated on the client side for web
 */
export function useColorScheme() {
	const [hasHydrated, setHasHydrated] = useState(false);

	useEffect(() => {
		// Two-pass hydration is intentional: render "light" on the server and
		// on the first client render to avoid a hydration mismatch, then flip
		// to the real color scheme once mounted.
		// eslint-disable-next-line react-hooks/set-state-in-effect
		setHasHydrated(true);
	}, []);

	const colorScheme = useRNColorScheme();

	if (hasHydrated) {
		return colorScheme;
	}

	return "light";
}
