import { useLocalSearchParams } from "expo-router";
import { useEffect, useMemo, useState } from "react";

import { RepoDownloads } from "@/components/repo-downloads";
import { loadRepoDataList, RepoData } from "@/lib/repo-data";

export default function RepoScreen() {
	const { userName, repoName } = useLocalSearchParams<{
		userName: string;
		repoName: string;
	}>();

	const [repos, setRepos] = useState<RepoData[]>([]);
	const [ready, setReady] = useState(false);

	useEffect(() => {
		let disposed = false;
		(async () => {
			try {
				const list = await loadRepoDataList();
				if (!disposed) setRepos(list);
			} finally {
				if (!disposed) setReady(true);
			}
		})();
		return () => {
			disposed = true;
		};
	}, []);

	const selected = useMemo(() => {
		if (!userName || !repoName) return null;
		return (
			repos.find(
				(r) =>
					r.userName.toLowerCase() === String(userName).toLowerCase() &&
					r.repoName.toLowerCase() === String(repoName).toLowerCase(),
			) ??
			new RepoData({ userName: String(userName), repoName: String(repoName) })
		);
	}, [repos, userName, repoName]);

	if (!ready || !selected) return null;

	return (
		<RepoDownloads
			repos={repos}
			selected={selected}
			title={`${selected.userName}/${selected.repoName}`}
		/>
	);
}
