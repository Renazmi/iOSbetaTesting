#!/usr/bin/env bash
# Build TrackIT iOS .ipa — run on macOS with Xcode + CocoaPods installed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Flutter pub get"
flutter pub get

echo "==> CocoaPods"
cd ios
pod install
cd ..

# Set your Apple Developer Team ID (10-character), or export DEVELOPMENT_TEAM before running.
TEAM_ID="${DEVELOPMENT_TEAM:-}"
EXPORT_METHOD="${EXPORT_METHOD:-development}" # development | ad-hoc | app-store

BUILD_ARGS=(--release)
if [[ -n "$TEAM_ID" ]]; then
  BUILD_ARGS+=(--export-options-plist="$ROOT/ios/ExportOptions.plist")
fi

echo "==> flutter build ipa (${EXPORT_METHOD})"
flutter build ipa "${BUILD_ARGS[@]}"

OUT="$ROOT/build/ios/ipa"
echo ""
echo "Done. IPA output:"
ls -la "$OUT"/*.ipa 2>/dev/null || ls -la "$ROOT/build/ios/ipa/" || true
echo ""
echo "Copy the .ipa from build/ios/ipa/ for TestFlight or device install."
