import { Code, Lock, Pencil, Plus, Trash2 } from "lucide-react-native";
import { useCallback, useEffect, useState } from "react";
import { Alert, Pressable, ScrollView, View } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";
import {
	Actionsheet,
	ActionsheetBackdrop,
	ActionsheetContent,
	ActionsheetDragIndicator,
	ActionsheetDragIndicatorWrapper,
	ActionsheetItem,
	ActionsheetItemText,
} from "@/components/ui/actionsheet";
import { Button, ButtonText } from "@/components/ui/button";
import { Input, InputField } from "@/components/ui/input";
import {
	Modal,
	ModalBackdrop,
	ModalBody,
	ModalCloseButton,
	ModalContent,
	ModalFooter,
	ModalHeader,
} from "@/components/ui/modal";
import { Text } from "@/components/ui/text";
import { loadRepoDataList, RepoData, saveRepoDataList } from "@/lib/repo-data";

/**
 * Port of RepoDataList from repo_data.dart — list user repositories with
 * add / edit / delete (undo via alert), read-only default repo protected.
 */
export default function ReposScreen() {
	const [repos, setRepos] = useState<RepoData[]>([]);
	const [loading, setLoading] = useState(true);
	const [editing, setEditing] = useState<RepoData | null>(null);
	const [dialogOpen, setDialogOpen] = useState(false);
	const [userName, setUserName] = useState("");
	const [repoName, setRepoName] = useState("");
	const [deleteSheetOpen, setDeleteSheetOpen] = useState(false);
	const [pendingDelete, setPendingDelete] = useState<RepoData | null>(null);

	const reload = useCallback(async () => {
		try {
			const list = await loadRepoDataList();
			setRepos(list);
		} finally {
			setLoading(false);
		}
	}, []);

	useEffect(() => {
		reload();
	}, [reload]);

	const openAddDialog = () => {
		setEditing(null);
		setUserName("");
		setRepoName("");
		setDialogOpen(true);
	};

	const openEditDialog = (repo: RepoData) => {
		setEditing(repo);
		setUserName(repo.userName);
		setRepoName(repo.repoName);
		setDialogOpen(true);
	};

	const submitDialog = async () => {
		const user = userName.trim();
		const repo = repoName.trim();
		if (!user || !repo) return;

		const duplicate = repos.some(
			(r) =>
				r !== editing &&
				r.userName.toLowerCase() === user.toLowerCase() &&
				r.repoName.toLowerCase() === repo.toLowerCase(),
		);
		if (duplicate) {
			Alert.alert(
				"Duplicate",
				editing
					? "Another repository with same name exists"
					: "Repository already exists",
			);
			return;
		}

		const next = editing
			? repos.map((r) =>
					r === editing ? new RepoData({ userName: user, repoName: repo }) : r,
				)
			: [...repos, new RepoData({ userName: user, repoName: repo })];

		setRepos(next);
		await saveRepoDataList(next);
		setDialogOpen(false);
	};

	const confirmDelete = async () => {
		const repo = pendingDelete;
		setDeleteSheetOpen(false);
		setPendingDelete(null);
		if (!repo || repo.isReadOnly) return;

		const index = repos.indexOf(repo);
		const next = repos.filter((r) => r !== repo);
		setRepos(next);
		await saveRepoDataList(next);

		Alert.alert("Deleted", repo.repoName, [
			{
				text: "Undo",
				onPress: async () => {
					const insertIndex = Math.max(0, Math.min(index, next.length));
					const restored = [...next];
					restored.splice(insertIndex, 0, repo);
					setRepos(restored);
					await saveRepoDataList(restored);
				},
			},
			{ text: "OK" },
		]);
	};

	return (
		<SafeAreaView className="flex-1 bg-background" edges={["top"]}>
			<View className="flex-row items-center justify-between px-4 py-3">
				<Text className="text-xl font-bold">Repository List</Text>
				<Button size="sm" className="rounded-full" onPress={openAddDialog}>
					<Plus size={18} className="text-primary-foreground" />
				</Button>
			</View>

			<ScrollView className="flex-1">
				{loading ? (
					<View className="items-center py-16">
						<Text className="text-muted-foreground">Loading…</Text>
					</View>
				) : repos.length === 0 ? (
					<View className="items-center gap-2 py-16">
						<Text className="font-semibold">No repositories found</Text>
						<Text className="text-muted-foreground text-sm">
							Add your first repository to get started
						</Text>
					</View>
				) : (
					repos.map((repo) => (
						<View
							key={`${repo.userName}/${repo.repoName}/${repo.isReadOnly}`}
							className="bg-card mx-4 my-1.5 rounded-xl border border-border/60 px-4 py-3"
						>
							<View className="flex-row items-center gap-3">
								<View className="h-9 w-9 items-center justify-center rounded-full bg-secondary">
									<Code size={18} className="text-foreground" />
								</View>
								<View className="flex-1">
									<Text className="font-semibold" numberOfLines={1}>
										{repo.repoName}
									</Text>
									<Text
										className="text-muted-foreground text-xs"
										numberOfLines={1}
									>
										{repo.userName}
									</Text>
								</View>
								{repo.isReadOnly ? (
									<Lock size={18} className="text-muted-foreground" />
								) : (
									<View className="flex-row gap-2">
										<Pressable
											onPress={() => openEditDialog(repo)}
											className="p-1.5"
											accessibilityLabel="Edit repository"
										>
											<Pencil size={18} className="text-primary" />
										</Pressable>
										<Pressable
											onPress={() => {
												setPendingDelete(repo);
												setDeleteSheetOpen(true);
											}}
											className="p-1.5"
											accessibilityLabel="Delete repository"
										>
											<Trash2 size={18} className="text-destructive" />
										</Pressable>
									</View>
								)}
							</View>
						</View>
					))
				)}
			</ScrollView>

			{/* Add/Edit dialog */}
			<Modal
				isOpen={dialogOpen}
				onClose={() => setDialogOpen(false)}
				size="md"
				avoidKeyboard
			>
				<ModalBackdrop />
				<ModalContent>
					<ModalHeader>
						<Text className="text-lg font-bold">
							{editing ? "Edit Repository" : "Add Repository"}
						</Text>
						<ModalCloseButton />
					</ModalHeader>
					<ModalBody>
						<View className="gap-4">
							<Input className="rounded-xl">
								<InputField
									placeholder="User Name (e.g. bitwarden)"
									value={userName}
									onChangeText={setUserName}
									autoCapitalize="none"
								/>
							</Input>
							<Input className="rounded-xl">
								<InputField
									placeholder="Repo Name (e.g. android)"
									value={repoName}
									onChangeText={setRepoName}
									autoCapitalize="none"
								/>
							</Input>
						</View>
					</ModalBody>
					<ModalFooter>
						<Button variant="ghost" onPress={() => setDialogOpen(false)}>
							<ButtonText>Cancel</ButtonText>
						</Button>
						<Button onPress={submitDialog}>
							<ButtonText>{editing ? "Save" : "Add"}</ButtonText>
						</Button>
					</ModalFooter>
				</ModalContent>
			</Modal>

			{/* Delete confirmation */}
			<Actionsheet
				isOpen={deleteSheetOpen}
				onClose={() => setDeleteSheetOpen(false)}
			>
				<ActionsheetBackdrop />
				<ActionsheetContent>
					<ActionsheetDragIndicatorWrapper>
						<ActionsheetDragIndicator />
					</ActionsheetDragIndicatorWrapper>
					<ActionsheetItem onPress={confirmDelete}>
						<ActionsheetItemText>
							Delete {pendingDelete?.repoName}?
						</ActionsheetItemText>
					</ActionsheetItem>
					<ActionsheetItem onPress={() => setDeleteSheetOpen(false)}>
						<ActionsheetItemText>Cancel</ActionsheetItemText>
					</ActionsheetItem>
				</ActionsheetContent>
			</Actionsheet>
		</SafeAreaView>
	);
}
