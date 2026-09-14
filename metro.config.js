const { getDefaultConfig } = require("expo/metro-config");
const { withNativewind } = require("nativewind/metro");

const config = getDefaultConfig(__dirname);

// expo-sqlite web (wa-sqlite) imports its .wasm binary as a module —
// Metro must treat .wasm as an asset or the web/SSR bundles fail to resolve.
// https://docs.expo.dev/versions/v57.0.0/sdk/sqlite/#web-setup
config.resolver.assetExts.push("wasm");

module.exports = withNativewind(config, { inlineRem: 16 });
