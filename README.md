# rd_manager

A small Expo app that lets you browse and download patched APKs from one or
more GitHub release repos.

## Develop

```bash
bun install
bunx expo start
```

Then open the app on Android (development build, emulator, or Expo Go).

## Design system

Tokens live in [`src/global.css`](src/global.css) (CSS variables for
Tailwind / NativeWind) and [`src/constants/theme.ts`](src/constants/theme.ts)
(raw JS values for native tabs and Reanimated). Reusable screen
primitives live in `src/components/`:

- `ScreenHeader` — large-title header for every top-level route.
- `ListRow` — grouped-list row with leading icon, subtitle, trailing accessory.
- `EmptyState` — tinted icon well, headline, supporting copy, optional CTA.
- `AppAssetRow` — asset row with icon, size pill, repo path.
- `StatPill` — small badge for row-level metadata.

Screens import the primitives; nothing else should hand-roll typography,
spacing, or colors.

## Build APKs locally on GitHub Actions

`.github/workflows/android.yml` runs on every push / PR and on tags:

| Trigger | Job | Output |
|---|---|---|
| push / PR to `main`, manual dispatch | `build-debug` | Unsigned `app-debug.apk` uploaded as artifact `rd-manager-debug` |
| git tag matching `v*` (e.g. `v1.2.0`) | `build-release` | Signed `app-release.apk` uploaded as artifact `rd-manager-release` **and** attached to the GitHub Release for that tag |
| **Actions → Run workflow** with `create_release=true` and a `version` | `build-release` | Signed `app-release.apk` uploaded as artifact **and** published to a new GitHub Release tagged `v<version>` |

iOS is intentionally out of scope — local CI for iOS requires a macOS
runner plus signing secrets. Add it later if you need it.

### One-time setup for signed release builds

1. Generate a keystore (use Android Studio's `Build → Generate Signed
   Bundle / APK` wizard, or `keytool`):

   ```bash
   keytool -genkey -v \
     -keystore release.keystore \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias <your-alias>
   ```

2. Base64-encode the keystore file:

   ```bash
   base64 -i release.keystore | tr -d '\n' > release.keystore.b64
   ```

3. Add the following secrets under
   **Settings → Secrets and variables → Actions**:

   | Secret | Value |
   |---|---|
   | `ANDROID_KEYSTORE_BASE64` | contents of `release.keystore.b64` |
   | `ANDROID_KEYSTORE_PASSWORD` | keystore password |
   | `ANDROID_KEY_ALIAS` | key alias (e.g. `upload`) |
   | `ANDROID_KEY_PASSWORD` | key password (often the same as the keystore) |

4. Push a tag:

   ```bash
   git tag v1.2.0
   git push origin v1.2.0
   ```

5. The `build-release` job runs, produces
   `android/app/build/outputs/apk/release/app-release.apk`, uploads it as
   an artifact, and attaches it to the GitHub Release for `v1.2.0`.

### Manual release without a tag

If you don't want to push a tag just to publish a build, open
**Actions → Android APK → Run workflow**, fill in `version` (e.g. `1.2.0`)
and tick `create_release`. The job publishes a `v1.2.0` GitHub Release
with the signed APK attached. The local tag is **not** pushed, so it
won't appear in `git tag`.

### Local debug build

```bash
bun install
bunx expo prebuild --platform android --no-install
cd android && ./gradlew :app:assembleDebug
# APK at: android/app/build/outputs/apk/debug/app-debug.apk
```

For a local signed release build, drop your keystore at
`android/app/release.keystore`, create `android/keystore.properties`:

```properties
storeFile=release.keystore
storePassword=<store-pass>
keyAlias=<alias>
keyPassword=<key-pass>
```

then run `node scripts/patch-android-signing.mjs` (idempotent) before
`./gradlew :app:assembleRelease`. Pass `--undo` to revert the patch.

## Project layout

```
src/
  app/                expo-router file-based routes
  components/         reusable UI primitives
  constants/          JS-side theme tokens (mirrors global.css)
  hooks/              cross-cutting hooks
  lib/                data access (prefs, repos, github, secrets)
  services/           side-effecting services (downloads, notifications, websocket)
  global.css          Tailwind theme + CSS-variable design tokens
.github/workflows/    Android CI
scripts/              gradle signing patch helper, project reset
```

## Tech

- Expo SDK 57, expo-router, expo-image, expo-file-system
- NativeWind v5 (Tailwind v4) for styling
- Gluestack primitives + lucide-react-native icons
- React Native 0.86, Reanimated 4.5, Worklets 0.10

## License

MIT — see [LICENSE](LICENSE).