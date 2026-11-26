#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$MOBILE_DIR"

if [ ! -d "android" ] || [ ! -d "ios" ]; then
  echo "==> Generating canonical Android & iOS platform scaffolding with Flutter..."
  flutter create \
    --platforms=android,ios \
    --org=com.aiproxylauncher \
    --project-name=ai_proxy_launcher \
    .
fi

echo "==> Applying custom Android native bridge & manifest..."
ANDROID_MAIN="android/app/src/main"
mkdir -p "$ANDROID_MAIN/kotlin/com/aiproxylauncher/ai_proxy_launcher"
cp -f "native/android/MainActivity.kt" \
  "$ANDROID_MAIN/kotlin/com/aiproxylauncher/ai_proxy_launcher/MainActivity.kt"
cp -f "native/android/AndroidManifest.xml" "$ANDROID_MAIN/AndroidManifest.xml"

# Remove any stale Java MainActivity if flutter create generated one
rm -f "$ANDROID_MAIN/java/com/aiproxylauncher/ai_proxy_launcher/MainActivity.java" || true

echo "==> Applying custom iOS native bridge & Info.plist..."
cp -f "native/ios/AppDelegate.swift" "ios/Runner/AppDelegate.swift"
cp -f "native/ios/Info.plist" "ios/Runner/Info.plist"

# Ensure iOS deployment target is at least 13.0 for modern Swift / Network APIs
if [ -f "ios/Runner.xcodeproj/project.pbxproj" ]; then
  if sed --version >/dev/null 2>&1; then
    sed -i 's/IPHONEOS_DEPLOYMENT_TARGET = 12\.0;/IPHONEOS_DEPLOYMENT_TARGET = 13.0;/g' ios/Runner.xcodeproj/project.pbxproj
  else
    sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 12\.0;/IPHONEOS_DEPLOYMENT_TARGET = 13.0;/g' ios/Runner.xcodeproj/project.pbxproj
  fi
fi

echo "==> Platform scaffolding ready."

