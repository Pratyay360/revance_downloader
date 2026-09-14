import { useLocalSearchParams } from "expo-router";
import { useCallback, useEffect, useState } from "react";

import { RepoDownloads } from "@/components/repo-downloads";
import type { RepoData } from "@/lib/repo-data";

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

	const [selected, setSelected] = useState<RepoData | null>(null);
	const [ready, setReady] = useState(false);

	const load = useCallback(async () => {
		try {
			const { loadRepoDataList } = await import("@/lib/repo-data");
			const list = await loadRepoDataList();
			const match =
				list.find((r) => r.userName === userName && r.repoName === repoName) ??
				new RepoData({ userName, repoName });
			setSelected(match);
		} catch {
			setSelected(new RepoData({ userName, repoName }));
		} finally {
			setReady(true);
		}
	}, [userName, repoName]);

	useEffect(() => {
		load();
	}, [load]);

	if (!ready || !selected) {
		return <RepoDownloads repos={[]} selected={null} title={repoName} />;
	}

	return (
		<RepoDownloads
			repos={[selected]}
			selected={selected}
			title={`${userName}/${repoName}`}
		/>
	);
}
