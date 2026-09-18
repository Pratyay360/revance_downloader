# Taste
- Uses very terse, lowercase, casual phrasing for bug reports (e.g. "no apps showing up btw") with minimal context. Expects the agent to investigate and ask clarifying questions rather than provide upfront detail. Confidence: 0.85
- Comfortable answering multi-step clarifying questions (multiple `ask_user_question` rounds) to narrow down a bug — does not push back on being asked for more info. Confidence: 0.8
- Project is an Expo SDK 57 / React Native 0.86 app using `expo-router` with `unstable-native-tabs` (`NativeTabs`), `expo-sqlite` for prefs, and TypeScript strict. Uses `reactCompiler`. Confidence: 0.95
- Uses Bun as the package manager / runner (`bunx`, `bun install`, `bun start`). Prefer `bunx tsc` / `bun start` over `npx` equivalents. Confidence: 0.9
- Uses `jj` (Jujutsu) on top of git for version control; the repo may be in a detached state with uncommitted jj exports on top of `main`. Confidence: 0.9
- Default GitHub repo for the app is `suvradeep2025/docker-py-revanced` — used as the seed "defaultRepo" in `secrets.ts`. Confidence: 0.85
- Default to running an Expo project as a **dev build** (not Expo Go) — `expo run:android` / EAS dev client, not the QR-code Expo Go path. Confidence: 0.85
- AGENTS.md in the repo instructs: read Expo v57 docs before writing code. Confidence: 0.8
- Accepts the agent typechecking (`bunx tsc --noEmit`) as a verification step before proposing runtime fixes. Confidence: 0.8
