import { FolderGit, Lock, Pencil, Plus, Trash2 } from "lucide-react-native";
import { useCallback, useEffect, useMemo, useState } from "react";
import { Alert, ScrollView, View } from "react-native";

import { EmptyState } from "@/components/empty-state";
import { ListRow } from "@/components/list-row";
import { SafeAreaView } from "@/components/safe-area-view";
import { ScreenHeader } from "@/components/screen-header";
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
 * Add / edit / delete GitHub repositories that the home and detail screens
 * fetch from. Default (read-only) repos are pinned at the top with a lock
 * icon and have their edit / delete actions hidden.
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

	const { defaultRepos, customRepos } = useMemo(() => {
		return {
			defaultRepos: repos.filter((r) => r.isReadOnly),
			customRepos: repos.filter((r) => !r.isReadOnly),
		};
	}, [repos]);

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
		<SafeAreaView className="bg-background flex-1" edges={["top"]}>
			<ScreenHeader
				title="Repository List"
				subtitle="Default and custom GitHub repos"
				right={
					<Button
						size="sm"
						onPress={openAddDialog}
						accessibilityLabel="Add repository"
					>
						<Plus size={18} className="text-primary-foreground" />
					</Button>
				}
			/>

			<ScrollView
				className="flex-1"
				contentContainerStyle={{ paddingBottom: 24 }}
			>
				{loading ? (
					<Text className="text-muted-foreground px-5 py-6">Loading…</Text>
				) : repos.length === 0 ? (
					<EmptyState
						icon={FolderGit}
						title="No repositories found"
						description="Add your first repository to get started"
						action={
							<Button size="sm" onPress={openAddDialog}>
								<ButtonText>Add repository</ButtonText>
							</Button>
						}
					/>
				) : (
					<>
						{defaultRepos.length > 0 && (
							<>
								<SectionLabel label="Default" />
								{defaultRepos.map((repo) => (
									<View key={`${repo.userName}/${repo.repoName}/default`}>
										<ListRow
											title={repo.repoName}
											subtitle={repo.userName}
											leading={
												<View className="bg-secondary h-9 w-9 items-center justify-center rounded-xl">
													<FolderGit size={18} className="text-foreground" />
												</View>
											}
											trailing={
												<View className="p-1.5">
													<Lock size={18} className="text-muted-foreground" />
												</View>
											}
											disabled
										/>
										<Hairline />
									</View>
								))}
							</>
						)}
						{customRepos.length > 0 && (
							<>
								<SectionLabel label="Custom" />
								{customRepos.map((repo) => (
									<View key={`${repo.userName}/${repo.repoName}/custom`}>
										<ListRow
											title={repo.repoName}
											subtitle={repo.userName}
											leading={
												<View className="bg-primary-soft h-9 w-9 items-center justify-center rounded-xl">
													<FolderGit size={18} className="text-primary" />
												</View>
											}
											trailing={
												<View className="flex-row items-center gap-1">
													<Button
														variant="ghost"
														size="icon"
														onPress={() => openEditDialog(repo)}
														accessibilityLabel={`Edit ${repo.repoName}`}
													>
														<Pencil size={18} className="text-primary" />
													</Button>
													<Button
														variant="ghost"
														size="icon"
														onPress={() => {
															setPendingDelete(repo);
															setDeleteSheetOpen(true);
														}}
														accessibilityLabel={`Delete ${repo.repoName}`}
													>
														<Trash2 size={18} className="text-destructive" />
													</Button>
												</View>
											}
										/>
										<Hairline />
									</View>
								))}
							</>
						)}
						{customRepos.length === 0 && defaultRepos.length > 0 && (
							<View className="px-5 pt-2">
								<Text className="text-muted-foreground text-xs">
									Tap the + button to add a custom repository.
								</Text>
							</View>
						)}
					</>
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
						<View className="flex-1">
							<Text className="text-foreground text-lg font-bold">
								{editing ? "Edit Repository" : "Add Repository"}
							</Text>
						</View>
						<ModalCloseButton />
					</ModalHeader>
					<ModalBody>
						<View className="gap-4">
							<View>
								<Text className="text-muted-foreground mb-1.5 text-xs font-semibold uppercase">
									Owner
								</Text>
								<Input className="rounded-xl">
									<InputField
										placeholder="e.g. j-hc"
										value={userName}
										onChangeText={setUserName}
										autoCapitalize="none"
									/>
								</Input>
							</View>
							<View>
								<Text className="text-muted-foreground mb-1.5 text-xs font-semibold uppercase">
									Repo
								</Text>
								<Input className="rounded-xl">
									<InputField
										placeholder="e.g. revanced-magisk-module"
										value={repoName}
										onChangeText={setRepoName}
										autoCapitalize="none"
									/>
								</Input>
							</View>
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
					<View className="px-4 pb-2 pt-1">
						<Text className="text-foreground text-lg font-bold">
							Delete {pendingDelete?.repoName}?
						</Text>
						<Text className="text-muted-foreground text-sm">
							This removes the repo from your list. You can undo from the
							confirmation.
						</Text>
					</View>
					<ActionsheetItem onPress={confirmDelete}>
						<Trash2 size={18} className="text-destructive" />
						<ActionsheetItemText className="text-destructive">
							Delete
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

function SectionLabel({ label }: { label: string }) {
	return (
		<View className="px-5 pb-2 pt-4">
			<Text className="text-muted-foreground text-xs font-semibold tracking-wider uppercase">
				{label}
			</Text>
		</View>
	);
}

function Hairline() {
	return <View className="ml-16 h-px bg-border/60" />;
}
