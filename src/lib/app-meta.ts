/**
 * Port of app_meta.dart — fetches app name/icon metadata from Aptoide so
 * GitHub release assets can show a real app icon.
 */

export interface AppMeta {
	name: string;
	packageName: string;
	icon: string;
	versionName: string;
	versionCode: number;
}

interface AptoideResponse {
	data?: {
		name?: unknown;
		package?: unknown;
		icon?: unknown;
		file?: { vername?: unknown; vercode?: unknown };
	};
	nodes?: {
		data?: {
			name?: unknown;
			package?: unknown;
			icon?: unknown;
			file?: { vername?: unknown; vercode?: unknown };
		};
	}[];
}

export async function fetchAppMeta(
	packageName: string,
): Promise<AppMeta | null> {
	try {
		const url =
			"https://ws2-cache.aptoide.com/api/7/app/getMeta" +
			"?cdn=web" +
			"&q=bXlDUFU9YXJtNjQtdjhhLGFybWVhYmktdjdhLGFybWVhYmkmbGVhbmJhY2s9MA" +
			"&country=IN&limit=1" +
			`&package_name=${encodeURIComponent(packageName)}` +
			"&sort=relevance&view=response";

		const response = await fetch(url);
		if (!response.ok) return null;

		const json = (await response.json()) as AptoideResponse;
		const data = json.data ?? json.nodes?.[0]?.data;
		if (!data) return null;

		return {
			name: typeof data.name === "string" ? data.name : "",
			packageName: typeof data.package === "string" ? data.package : "",
			icon: typeof data.icon === "string" ? data.icon : "",
			versionName:
				typeof data.file?.vername === "string" ? data.file.vername : "",
			versionCode:
				typeof data.file?.vercode === "number" ? data.file.vercode : 0,
		};
	} catch {
		return null;
	}
}
