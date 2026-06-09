#!/bin/bash
set -euo pipefail

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "=== Checking requirements ==="

MACOS_VERSION=$(sw_vers -productVersion)
MACOS_MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
MACOS_MINOR=$(echo "$MACOS_VERSION" | cut -d. -f2)

if [[ "$MACOS_MAJOR" -lt 15 ]] || { [[ "$MACOS_MAJOR" -eq 15 ]] && [[ "$MACOS_MINOR" -lt 6 ]]; }; then
  echo "ERROR: macOS $MACOS_VERSION detected. Xcode 26 requires macOS 15.6+."
  echo "Update macOS from System Settings > General > Software Update, then rerun."
  exit 1
fi

XCODE_PATH=$(xcode-select -p 2>/dev/null || true)
XCODE_VERSION=$(xcodebuild -version 2>/dev/null | head -1 || echo "not installed")
SDK_VERSION=$(xcodebuild -showsdks 2>/dev/null | rg -o 'iphoneos[0-9.]+' | sort -V | tail -1 | rg -o '[0-9.]+' || echo "unknown")

echo "macOS: $MACOS_VERSION"
echo "Xcode: $XCODE_VERSION"
echo "iOS SDK: $SDK_VERSION"

if [[ "$XCODE_VERSION" != Xcode\ 26* ]]; then
  echo "ERROR: App Store requires Xcode 26+ with iOS 26 SDK."
  echo "Install Xcode 26 from Mac App Store, then run:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

SDK_MAJOR=$(echo "$SDK_VERSION" | cut -d. -f1)
if [[ "$SDK_MAJOR" -lt 26 ]]; then
  echo "ERROR: iOS SDK $SDK_VERSION is too old. Need iOS 26 SDK or later."
  exit 1
fi

AVAIL_KB=$(df -k / | awk 'NR==2 {print $4}')
if [[ "$AVAIL_KB" -lt 5242880 ]]; then
  echo "WARNING: Less than 5 GB free disk space. Build may fail."
fi

echo "=== Building IPA ==="
flutter clean
flutter pub get
cd ios && pod install && cd ..
flutter build ipa --release

IPA_PATH="$PROJECT_DIR/build/ios/ipa"
echo ""
echo "SUCCESS: IPA ready in $IPA_PATH"
ls -lh "$IPA_PATH"/*.ipa 2>/dev/null || true
