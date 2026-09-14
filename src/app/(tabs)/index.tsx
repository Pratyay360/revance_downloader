import { useEffect, useState } from "react";
import { SafeAreaView } from "react-native-safe-area-context";

import { RepoDownloads } from "@/components/repo-downloads";
import { ThemedView } from "@/components/themed-view";
import { loadRepoDataList, type RepoData } from "@/lib/repo-data";

export default function HomeScreen() {
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

	if (!ready) {
		return (
			<ThemedView
				style={{ flex: 1, alignItems: "center", justifyContent: "center" }}
			>
				<SafeAreaView
					style={{ flex: 1, alignItems: "center", justifyContent: "center" }}
				></SafeAreaView>
			</ThemedView>
		);
	}

	return <RepoDownloads repos={repos} selected={undefined} title="All Apps" />;
}
