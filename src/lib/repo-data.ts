import { secrets } from "./config";
import { getPrefString, setPrefString } from "./prefs";

/** Lightweight value object representing a repository (RepoData in Dart). */
export class RepoData {
	readonly userName: string;
	readonly repoName: string;
	readonly isReadOnly: boolean;

	constructor(params: {
		userName: string;
		repoName: string;
		isReadOnly?: boolean;
	}) {
		this.userName = params.userName;
		this.repoName = params.repoName;
		this.isReadOnly = params.isReadOnly ?? false;
	}

	static fromJson(json: unknown): RepoData {
		const obj = (json ?? {}) as Record<string, unknown>;
		const user = obj.userName;
		const repo = obj.repoName;
		if (typeof user !== "string" || typeof repo !== "string") {
			throw new Error("Invalid RepoData JSON");
		}
		return new RepoData({
			userName: user,
			repoName: repo,
			isReadOnly: obj.isReadOnly === true,
		});
	}

	equals(other: RepoData): boolean {
		return (
			this.userName.toLowerCase() === other.userName.toLowerCase() &&
			this.repoName.toLowerCase() === other.repoName.toLowerCase() &&
			this.isReadOnly === other.isReadOnly
		);
	}

	toString(): string {
		return `RepoData(${this.userName}/${this.repoName}${this.isReadOnly ? ", readOnly" : ""})`;
	}
}

const REPO_STORAGE_KEY = "repo_list";

/** Port of RepoStorage from repo_data.dart. */
export async function saveRepoDataList(repos: RepoData[]): Promise<void> {
	const json = JSON.stringify(
		repos
			.filter((r) => !r.isReadOnly)
			.map((r) => ({
				userName: r.userName,
				repoName: r.repoName,
				isReadOnly: r.isReadOnly,
			})),
	);
	await setPrefString(REPO_STORAGE_KEY, json);
}

export async function loadRepoDataList(): Promise<RepoData[]> {
	const result: RepoData[] = [];
	const raw = await getPrefString(REPO_STORAGE_KEY);

	if (raw) {
		try {
			const decoded: unknown = JSON.parse(raw);
			if (Array.isArray(decoded)) {
				for (const item of decoded) {
					try {
						result.push(RepoData.fromJson(item));
					} catch {
						// keep running on malformed entries
					}
				}
			}
		} catch {
			// malformed stored list — start fresh with defaults below
		}
	}

	const defaultRepos: RepoData[] = [
		new RepoData({ ...secrets.defaultRepo, isReadOnly: true }),
	];

	const filtered = result.filter(
		(r) => !defaultRepos.some((dr) => r.equals(dr)),
	);
	return [...defaultRepos, ...filtered];
}
