import * as SQLite from "expo-sqlite";

/**
 * Small KV store on SQLite (replaces shared_preferences from the Flutter app).
 * Used for: intro_completed flag, repo list JSON.
 */
const DB_NAME = "rd_manager.db";

let dbPromise: Promise<SQLite.SQLiteDatabase> | null = null;

function getDb(): Promise<SQLite.SQLiteDatabase> {
	if (!dbPromise) {
		dbPromise = (async () => {
			const db = await SQLite.openDatabaseAsync(DB_NAME);
			await db.execAsync(
				`CREATE TABLE IF NOT EXISTS prefs(
          key TEXT PRIMARY KEY NOT NULL,
          value TEXT
        )`,
			);
			return db;
		})();
	}
	return dbPromise;
}

export async function getPrefString(key: string): Promise<string | null> {
	const db = await getDb();
	const row = await db.getFirstAsync<{ value: string }>(
		`SELECT value FROM prefs WHERE key = ?`,
		key,
	);
	return row?.value ?? null;
}

export async function setPrefString(key: string, value: string): Promise<void> {
	const db = await getDb();
	await db.runAsync(
		`INSERT OR REPLACE INTO prefs(key, value) VALUES(?, ?)`,
		key,
		value,
	);
}

export async function getPrefBool(key: string): Promise<boolean> {
	return (await getPrefString(key)) === "true";
}

export async function setPrefBool(key: string, value: boolean): Promise<void> {
	await setPrefString(key, value ? "true" : "false");
}
