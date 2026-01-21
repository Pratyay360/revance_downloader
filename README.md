# revance_downloader

revanced manager :) but no compile

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Building Signed APK

### Local Build

To build a signed release APK locally:

1. Copy `android/key.properties.example` to `android/key.properties`
2. Update the values in `android/key.properties` with your keystore details:
   - `storePassword`: Your keystore password
   - `keyPassword`: Your key password
   - `keyAlias`: Your key alias
   - `storeFile`: Path to your keystore file (default: `../../revanced.keystore`)
3. Run: `flutter build apk --release`

### GitHub Actions

The GitHub Actions workflow automatically builds and releases APK files on push to main/master.

#### Required Secrets (for signed releases)

To build signed release APKs in GitHub Actions, add these secrets to your repository at `Settings > Secrets and variables > Actions`:

- `KEYSTORE_PASSWORD`: Your keystore password
- `KEY_PASSWORD`: Your key password
- `KEY_ALIAS`: Your key alias (e.g., "upload" or "key0")

**Note:** The workflow uses `GITHUB_TOKEN` automatically (no manual setup needed) and will work without signing secrets (will build debug APK instead).

#### Setting up GitHub Secrets

1. Go to your repository on GitHub
2. Navigate to `Settings > Secrets and variables > Actions`
3. Click "New repository secret"
4. Add each of the secrets listed above

The keystore file (`revanced.keystore`) is already included in the repository.
