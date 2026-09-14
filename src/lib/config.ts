import { ntfyHost, repoName1, userName1 } from "./secrets";

/**
 * Central config, ported from revance_downloader's secrets.dart + usage sites.
 * Real values live in `secrets.local.ts` (gitignored), mirroring the Flutter
 * app's gitignored `secrets.dart`. The template `secrets.ts` is committed so
 * the project typechecks out of the box — copy it to `secrets.local.ts`, fill
 * in your values, and update the import above if you use a local file.
 */
export const secrets = {
	ntfyHost,
	defaultRepo: { userName: userName1, repoName: repoName1 },
} as const;
