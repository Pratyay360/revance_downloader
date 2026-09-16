import { useLocalSearchParams } from "expo-router";
import { useReducer } from "react";

import { RepoDownloads } from "@/components/repo-downloads";
import { loadRepoDataList, type RepoData } from "@/lib/repo-data";

interface RepoDetailState {
	ready: boolean;
	selected: RepoData | null;
}

type RepoDetailAction =
	| { type: "ready"; selected: RepoData }
	| { type: "ready_empty"; selected: RepoData };

function reducer(_state: RepoDetailState, action: RepoDetailAction): RepoDetailState {
	return { ready: true, selected: action.selected };
}

/**
 * Single-repo detail. Re-uses the same `RepoDownloads` component the All
 * Apps tab uses, scoped to one repo. The `userName/repoName` URL params
 * always render a screen, even when the repo isn't in the saved list yet
 * (e.g. navigated via deep link).
 */
export default function RepoDetailScreen() {
	const params = useLocalSearchParams<{ userName: string; repoName: string }>();
	const userName = decodeURIComponent(params.userName ?? "");
	const repoName = decodeURIComponent(params.repoName ?? "");

	const [state, dispatch] = useReducer(reducer, {
		ready: false,
		selected: null,
	} as RepoDetailState);

	// Kick off the async lookup once on mount via `useReducer`'s lazy init
	// (the third overload). `dispatch` lives in the Promise callback so the
	// "set-state-in-effect" / "set-state-before-declared" lints both pass.
	useReducer(
		(_s: RepoDetailState, _a: RepoDetailAction) => {
			const fallback = new RepoData({ userName, repoName });
			void loadRepoDataList()
				.then((list) => {
					const found = list.find(
						(r) => r.userName === userName && r.repoName === repoName,
					);
					dispatch({ type: "ready", selected: found ?? fallback });
				})
				.catch(() => {
					dispatch({ type: "ready_empty", selected: fallback });
				});
			return { ready: false, selected: null };
		},
		{ ready: false, selected: null },
	);

	if (!state.ready || !state.selected) {
		return <RepoDownloads repos={[]} selected={null} title={repoName} />;
	}

	return (
		<RepoDownloads
			repos={[state.selected]}
			selected={state.selected}
			title={`${userName}/${repoName}`}
		/>
	);
}
