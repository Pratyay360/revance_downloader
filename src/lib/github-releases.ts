import { fetchAppMeta } from "./app-meta";

/** Port of GithubAsset + release fetching from download_page.dart. */

export interface GithubAsset {
	id: number;
	name: string;
	imageLink?: string | null;
	downloadUrl: string;
	size: number;
	digest: string;
}

export function assetFromJson(json: Record<string, unknown>): GithubAsset {
	return {
		id: typeof json.id === "number" ? json.id : 0,
		name: typeof json.name === "string" ? json.name : "",
		imageLink: null,
		downloadUrl:
			typeof json.browser_download_url === "string"
				? json.browser_download_url
				: "",
		size: typeof json.size === "number" ? json.size : 0,
		digest: typeof json.digest === "string" ? json.digest : "",
	};
}

export interface ReleaseFetchResult {
	assets: GithubAsset[];
	errorMessage: string | null;
}

function isInstallableAsset(asset: GithubAsset): boolean {
	const name = asset.name.toLowerCase();
	return (
		(name.endsWith(".apk") || name.endsWith(".aab")) &&
		(name.includes("arm64") ||
			name.includes("universal") ||
			name.includes("v8a"))
	);
}

/** Fetch the latest release assets for a single repo. */
export async function fetchLatestReleaseAssets(
	userName: string,
	repoName: string,
): Promise<ReleaseFetchResult> {
	try {
		const response = await fetch(
			`https://api.github.com/repos/${userName}/${repoName}/releases/latest`,
		);
		if (!response.ok) {
			if (response.status === 404) {
				return { assets: [], errorMessage: "No releases found." };
			}
			return {
				assets: [],
				errorMessage: `Failed to fetch releases: ${response.status} ${response.statusText}`,
			};
		}
		const json = (await response.json()) as { assets?: unknown };
		const assetsJson = Array.isArray(json.assets) ? json.assets : [];
		const assets = assetsJson
			.map((e) => assetFromJson(e as Record<string, unknown>))
			.filter(isInstallableAsset);
		return { assets, errorMessage: null };
	} catch (e) {
		const message = e instanceof Error ? e.message : String(e);
		if (/network|timed?\s?out/i.test(message)) {
			return {
				assets: [],
				errorMessage: "Connection timed out. Please check your internet.",
			};
		}
		return { assets: [], errorMessage: `Failed to fetch releases: ${message}` };
	}
}

export interface RepoAsset extends GithubAsset {
	repoUserName: string;
	repoName: string;
}

/** Fetch installable assets (.apk/.aab) across all repos — the "All Apps" view. */
export async function fetchAllReposAssets(
	repos: { userName: string; repoName: string }[],
): Promise<ReleaseFetchResult & { assets: RepoAsset[] }> {
	const all: RepoAsset[] = [];
	const errors: string[] = [];

	for (const repo of repos) {
		const result = await fetchLatestReleaseAssets(repo.userName, repo.repoName);
		if (result.errorMessage) {
			errors.push(`${repo.userName}/${repo.repoName}: ${result.errorMessage}`);
		}
		for (const asset of result.assets) {
			// All Apps shows every apk/aab, not just arm64/universal like the single view
			const name = asset.name.toLowerCase();
			if (name.endsWith(".apk") || name.endsWith(".aab")) {
				all.push({
					...asset,
					repoUserName: repo.userName,
					repoName: repo.repoName,
				});
			}
		}
	}

	return {
		assets: all,
		errorMessage:
			all.length === 0
				? "No assets found. Please check your internet or repository list."
				: null,
	};
}

/** Heuristic: extract a package name from an asset filename, then fetch its icon. */
export async function attachIconForAsset(asset: GithubAsset): Promise<void> {
	if (asset.imageLink) return;
	const parts = asset.name.split("_");
	for (const part of parts) {
		if (part.includes(".") && part.split(".").length >= 3) {
			const pkg = part.replace(/\.apk$/, "").replace(/\.aab$/, "");
			const meta = await fetchAppMeta(pkg);
			if (meta?.icon) {
				asset.imageLink = meta.icon;
				return;
			}
		}
	}
}

export function formatBytes(bytes: number): string {
	return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}
