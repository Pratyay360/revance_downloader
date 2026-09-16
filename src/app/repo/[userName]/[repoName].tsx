import { useLocalSearchParams } from "expo-router";
import { useEffect, useState } from "react";

import { RepoDownloads } from "@/components/repo-downloads";
import { loadRepoDataList, RepoData } from "@/lib/repo-data";

interface RepoDetailState {
	ready: boolean;
	selected: RepoData | null;
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

	const [state, setState] = useState<RepoDetailState>({
		ready: false,
		selected: null,
	});

	// Async lookup on mount (and when params change). Previously this was
	// hidden inside a second `useReducer` initializer, which never executes,
	// so the screen stayed on the empty state forever.
	useEffect(() => {
		let cancelled = false;
		const fallback = new RepoData({ userName, repoName });
		void loadRepoDataList()
			.then((list) => {
				if (cancelled) return;
				const found = list.find(
					(r) => r.userName === userName && r.repoName === repoName,
				);
				setState({ ready: true, selected: found ?? fallback });
			})
			.catch(() => {
				if (!cancelled) setState({ ready: true, selected: fallback });
			});
		return () => {
			cancelled = true;
		};
	}, [userName, repoName]);

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
