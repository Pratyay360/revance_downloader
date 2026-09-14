import { useRouter } from "expo-router";
import { Code, Settings } from "lucide-react-native";
import { useEffect, useState } from "react";
import { ActivityIndicator, FlatList, Pressable, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import { ThemedView } from "@/components/themed-view";
import { Text } from "@/components/ui/text";
import { loadRepoDataList, type RepoData } from "@/lib/repo-data";

export default function ReposTabScreen() {
	const router = useRouter();
	const [repos, setRepos] = useState<RepoData[]>([]);
	const [loading, setLoading] = useState(true);

	useEffect(() => {
		let disposed = false;
		(async () => {
			setLoading(true);
			try {
				const list = await loadRepoDataList();
				if (!disposed) setRepos(list);
			} finally {
				if (!disposed) setLoading(false);
			}
		})();
		return () => {
			disposed = true;
		};
	}, []);

	if (loading) {
		return (
			<ThemedView
				style={{ flex: 1, alignItems: "center", justifyContent: "center" }}
			>
				<ActivityIndicator />
			</ThemedView>
		);
	}

	return (
		<SafeAreaView style={{ flex: 1 }} edges={["top"]}>
			<View
				style={{
					flexDirection: "row",
					alignItems: "center",
					justifyContent: "space-between",
					paddingHorizontal: 16,
					paddingVertical: 12,
				}}
			>
				<Text style={{ fontSize: 20, fontWeight: "700" }}>Repositories</Text>
				<Pressable
					onPress={() => router.push("/repos")}
					accessibilityLabel="Manage Repositories"
					style={{ padding: 8 }}
				>
					<Settings size={20} />
				</Pressable>
			</View>

			<FlatList
				data={repos}
				keyExtractor={(r) => `${r.userName}/${r.repoName}/${r.isReadOnly}`}
				ListEmptyComponent={
					<View style={{ padding: 32, alignItems: "center", gap: 8 }}>
						<Text style={{ fontWeight: "600" }}>No repositories</Text>
						<Text style={{ fontSize: 12, opacity: 0.7 }}>
							Tap the manage icon to add one.
						</Text>
					</View>
				}
				renderItem={({ item }) => (
					<Pressable
						onPress={() =>
							router.push(
								`/repo/${encodeURIComponent(item.userName)}/${encodeURIComponent(item.repoName)}`,
							)
						}
						style={({ pressed }) => ({
							marginHorizontal: 16,
							marginVertical: 6,
							paddingHorizontal: 16,
							paddingVertical: 14,
							borderRadius: 12,
							borderWidth: 1,
							borderColor: "rgba(0,0,0,0.08)",
							opacity: pressed ? 0.7 : 1,
							flexDirection: "row",
							alignItems: "center",
							gap: 12,
						})}
					>
						<View
							style={{
								height: 36,
								width: 36,
								borderRadius: 18,
								alignItems: "center",
								justifyContent: "center",
								backgroundColor: "rgba(0,0,0,0.06)",
							}}
						>
							<Code size={18} />
						</View>
						<View style={{ flex: 1 }}>
							<Text style={{ fontWeight: "600" }} numberOfLines={1}>
								{item.repoName}
							</Text>
							<Text style={{ fontSize: 12, opacity: 0.7 }} numberOfLines={1}>
								{item.userName}
							</Text>
						</View>
					</Pressable>
				)}
			/>
		</SafeAreaView>
	);
}
