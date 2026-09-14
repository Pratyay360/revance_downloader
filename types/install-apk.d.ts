declare module "@isudaji/react-native-install-apk" {
	/**
	 * Minimal typing for the APK installer native module
	 * (Android only; no-ops elsewhere).
	 */
	export const InstallApk: {
		install(apkPath: string): void;
	};
	export default InstallApk;
}
