#!/usr/bin/env bash
#
# Build a signed Qontract iOS release (.ipa), TestFlight/App Store ready.
#
# MUST be run on macOS with Xcode installed (xcodebuild + the iOS SDK).
# It cannot run on Linux/Windows hosts.
#
# The .ipa is signed for *distribution* (not development) so it can be
# uploaded to App Store Connect. See DEPLOY.md ("iOS release builds") for
# the full signing setup (team, certificates, provision profile) and the
# App Store Connect upload + TestFlight steps.
#
# One-time prerequisites (on this Mac):
#   1. Xcode + command line tools:            `xcode-select --install`
#   2. Accept the license:                     `sudo xcodebuild -license accept`
#   3. Create the App Store distribution
#      certificate + a matching App Store
#      provisioning profile in the Apple
#      Developer portal and download the
#      profile (it ships with the cert).
#   4. Put your 10-character Apple team id in
#      ios/Runner/xcconfig/Secrets.xcconfig
#      (committed empty — fill it in locally, never push it).
#
# Usage (from the repo root):
#   ./tool/build_ios_release.sh
#   QONTRACT_API_BASE_URL=https://api.example.com/api ./tool/build_ios_release.sh
#
# Requirements: flutter + git on PATH, macOS + Xcode, team id configured.

set -euo pipefail

cd "$(dirname "$0")/.."

# --- guards ------------------------------------------------------------------
if [ "$(uname -s)" != "Darwin" ]; then
  echo "error: iOS release builds require macOS (Xcode). Current OS: $(uname -s)" >&2
  exit 1
fi
command -v xcodebuild >/dev/null 2>&1 || {
  echo "error: xcodebuild not found. Install Xcode and run: sudo xcodebuild -license accept" >&2
  exit 1
}
command -v flutter >/dev/null 2>&1 || {
  echo "error: flutter not found. Install Flutter and ensure it is on PATH." >&2
  exit 1
}

# --- team id -----------------------------------------------------------------
# The team id lives in ios/Runner/xcconfig/Secrets.xcconfig (committed with an
# EMPTY default on purpose; fill it in locally — never push a personal team id).
LOCAL_XC="ios/Runner/xcconfig/Secrets.xcconfig"
if [ ! -f "$LOCAL_XC" ]; then
  echo "error: $LOCAL_XC not found. It should exist in the repo with an empty" >&2
  echo "       DEVELOPMENT_TEAM; fill it in with your 10-character Apple team id." >&2
  exit 1
fi
if ! grep -Eq 'DEVELOPMENT_TEAM *=[[:space:]]*[^[:space:]]' "$LOCAL_XC"; then
  echo "error: DEVELOPMENT_TEAM in $LOCAL_XC is empty." >&2
  echo "       Set it to your 10-character Apple team id (or remove the include" >&2
  echo "       and rely on the default team of your Xcode Apple-ID account)." >&2
  exit 1
fi

# --- bundle id (single source of truth lives in the Xcode project) ------------
BUNDLE_ID="$(grep -oE 'PRODUCT_BUNDLE_IDENTIFIER = de\.harryneufeld\.qontract_app;' \
  ios/Runner.xcodeproj/project.pbxproj | head -1 | sed 's/.*= //; s/;//')"
if [ -z "$BUNDLE_ID" ]; then
  echo "error: could not read PRODUCT_BUNDLE_IDENTIFIER for the Runner target." >&2
  exit 1
fi

# --- optional backend override -----------------------------------------------
DART_DEFINE=()
if [ -n "${QONTRACT_API_BASE_URL:-}" ]; then
  DART_DEFINE=(--dart-define=QONTRACT_API_BASE_URL="$QONTRACT_API_BASE_URL")
fi

# --- build -------------------------------------------------------------------
# `flutter build ipa` runs the full pipeline:
#   flutter pub get
#   xcodebuild archive -configuration Release ... -allowProvisioningUpdates
#   xcodebuild -exportArchive -exportOptionsPlist <ipa>
# Automatic signing (CODE_SIGN_STYLE=Automatic in the project) resolves the
# App Store cert + profile for $BUNDLE_ID from your team.
echo "==> flutter build ipa (bundle: ${BUNDLE_ID})"
flutter build ipa --release ${DART_DEFINE[@]+"${DART_DEFINE[@]}"}

# --- locate the produced artifact --------------------------------------------
# Recent Flutter places it under build/ios/ipa/ (a fresh copy is generated
# each run); older versions used a timestamped dir. Find the newest .ipa.
IPA="$(ls -1t build/ios/ipa/*.ipa 2>/dev/null | head -1 || true)"
[ -n "$IPA" ] || IPA="$(find build/ios -name '*.ipa' -type f 2>/dev/null | xargs ls -1t 2>/dev/null | head -1 || true)"
if [ -z "$IPA" ]; then
  echo "error: no .ipa found under build/ios after the build." >&2
  exit 1
fi

echo ""
echo "Built iOS release:"
echo "  $IPA  (bundle: $BUNDLE_ID)"
echo ""
echo "Next: upload to App Store Connect (see DEPLOY.md \"Uploading\"):"
echo "  xcrun altool --upload-app --type ios -f \"$IPA\" \\"
echo "    --apiKey <APP_STORE_CONNECT_API_KEY_ID> --apiIssuer <ISSUER_ID>"
echo ""
echo "Verify the embedded signing is App Store distribution (not development):"
echo "  unzip -p \"$IPA\" Payload/*.app/Info.plist 2>/dev/null | head"
echo "  # or inspect:  codesign -dv --verbose=2 Payload/*.app"
