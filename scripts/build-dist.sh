#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

APP_NAME="Wisp"
APP_BUNDLE="$APP_NAME.app"
DMG_NAME="$APP_NAME.dmg"
PKG_NAME="$APP_NAME.pkg"
BUILD_DIR="dist"

# ---------------------------------------------------------------------------
# Optional: set SIGNING_IDENTITY to your Developer ID to sign the app.
# e.g. export SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
# If unset, the app is built unsigned.
# ---------------------------------------------------------------------------

echo "==> Building $APP_NAME (release)..."
swift build -c release

echo "==> Creating app bundle..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

rm -rf "$BUILD_DIR/$APP_BUNDLE"
mkdir -p "$BUILD_DIR/$APP_BUNDLE/Contents/MacOS"
mkdir -p "$BUILD_DIR/$APP_BUNDLE/Contents/Resources"

cp ".build/release/$APP_NAME"              "$BUILD_DIR/$APP_BUNDLE/Contents/MacOS/"
cp "Support/Info.plist"                    "$BUILD_DIR/$APP_BUNDLE/Contents/"
cp -r ".build/release/${APP_NAME}_${APP_NAME}.bundle" "$BUILD_DIR/$APP_BUNDLE/"

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
    echo "==> Signing with: $SIGNING_IDENTITY"
    codesign \
        --deep --force --verify --verbose \
        --sign "$SIGNING_IDENTITY" \
        --entitlements "$REPO_ROOT/Wisp.entitlements" \
        --options runtime \
        "$BUILD_DIR/$APP_BUNDLE"
else
    echo "==> Skipping signing (SIGNING_IDENTITY not set)"
fi

echo "==> Creating $DMG_NAME..."
rm -f "$BUILD_DIR/$DMG_NAME"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$BUILD_DIR/$APP_BUNDLE" \
    -ov -format UDZO \
    "$BUILD_DIR/$DMG_NAME"

echo "==> Creating $PKG_NAME (for Jamf / MDM)..."
rm -f "$BUILD_DIR/$PKG_NAME"
pkgbuild \
    --component "$BUILD_DIR/$APP_BUNDLE" \
    --install-location /Applications \
    "$BUILD_DIR/$PKG_NAME"

echo ""
echo "Done! Artifacts in $BUILD_DIR/:"
ls -lh "$BUILD_DIR/$DMG_NAME" "$BUILD_DIR/$PKG_NAME"
