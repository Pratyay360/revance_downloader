import type { SQLiteDatabase } from "expo-sqlite";
import * as SQLite from "expo-sqlite";

/**
 * Port of DownloadHistoryStore from revance_downloader/lib/download_coordinator.dart.
 * Tracks downloaded files: name -> (digest, path) so re-downloads can be
 * detected and cached files located.
 */
class DownloadHistoryStoreImpl {
	private db: SQLiteDatabase | null = null;
	private opening: Promise<SQLiteDatabase> | null = null;

	private open(): Promise<SQLiteDatabase> {
		if (this.db) return Promise.resolve(this.db);
		if (!this.opening) {
			this.opening = (async () => {
				const db = await SQLite.openDatabaseAsync("downloads.db");
				await db.execAsync(
					`CREATE TABLE IF NOT EXISTS downloads(
            name TEXT PRIMARY KEY NOT NULL,
            digest TEXT,
            path TEXT
          )`,
				);
				this.db = db;
				return db;
			})();
		}
		return this.opening;
	}

	async insert(params: { name: string; digest: string; path: string }) {
		const db = await this.open();
		await db.runAsync(
			`INSERT OR REPLACE INTO downloads(name, digest, path) VALUES(?, ?, ?)`,
			params.name,
			params.digest,
			params.path,
		);
	}

	async get(
		name: string,
	): Promise<{ name: string; digest: string; path: string } | null> {
		const db = await this.open();
		return (
			(await db.getFirstAsync<{ name: string; digest: string; path: string }>(
				`SELECT name, digest, path FROM downloads WHERE name = ?`,
				name,
			)) ?? null
		);
	}

	async close() {
		await this.db?.closeAsync();
		this.db = null;
		this.opening = null;
	}
}

export const DownloadHistoryStore = new DownloadHistoryStoreImpl();
