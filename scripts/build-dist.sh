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
# Signing identities (auto-detected if not set)
# ---------------------------------------------------------------------------
if [[ -z "${SIGNING_IDENTITY:-}" ]]; then
    SIGNING_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/' || true)
fi
if [[ -z "${INSTALLER_IDENTITY:-}" ]]; then
    INSTALLER_IDENTITY=$(security find-identity -v | grep "Developer ID Installer" | head -1 | sed 's/.*"\(.*\)".*/\1/' || true)
fi

echo "==> Building $APP_NAME (release)..."
swift build -c release

echo "==> Computing version..."
BUILD_NUMBER=$(git rev-list --count HEAD)
VERSION="${WISP_VERSION:-1.0}"
echo "    Version: $VERSION  Build: $BUILD_NUMBER"

echo "==> Creating app bundle..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

rm -rf "$BUILD_DIR/$APP_BUNDLE"
mkdir -p "$BUILD_DIR/$APP_BUNDLE/Contents/MacOS"
mkdir -p "$BUILD_DIR/$APP_BUNDLE/Contents/Resources"

cp ".build/release/$APP_NAME"              "$BUILD_DIR/$APP_BUNDLE/Contents/MacOS/"
cp "Support/Info.plist"                    "$BUILD_DIR/$APP_BUNDLE/Contents/"
cp -r ".build/release/${APP_NAME}_${APP_NAME}.bundle" "$BUILD_DIR/$APP_BUNDLE/Contents/Resources/"

# Stamp version into the built bundle (not the source file)
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$BUILD_DIR/$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$BUILD_DIR/$APP_BUNDLE/Contents/Info.plist"

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

# Step 1: build a component package
COMPONENT_PKG="$BUILD_DIR/component.pkg"
rm -f "$COMPONENT_PKG"
pkgbuild \
    --component "$BUILD_DIR/$APP_BUNDLE" \
    --install-location /Applications \
    --version "$VERSION.$BUILD_NUMBER" \
    "$COMPONENT_PKG"

# Step 2: wrap into a distribution (product archive) — required by MDM
if [[ -n "${INSTALLER_IDENTITY:-}" ]]; then
    echo "==> Signing pkg with: $INSTALLER_IDENTITY"
    productbuild \
        --package "$COMPONENT_PKG" \
        --sign "$INSTALLER_IDENTITY" \
        "$BUILD_DIR/$PKG_NAME"
else
    echo "==> Skipping pkg signing (INSTALLER_IDENTITY not set)"
    productbuild \
        --package "$COMPONENT_PKG" \
        "$BUILD_DIR/$PKG_NAME"
fi
rm -f "$COMPONENT_PKG"

if [[ -n "${INSTALLER_IDENTITY:-}" ]]; then
    echo "==> Notarizing $PKG_NAME..."
    xcrun notarytool submit "$BUILD_DIR/$PKG_NAME" \
        --keychain-profile "wisp-notarize" \
        --wait

    echo "==> Stapling notarization ticket..."
    xcrun stapler staple "$BUILD_DIR/$PKG_NAME"
fi

echo ""
echo "Done! Artifacts in $BUILD_DIR/:"
ls -lh "$BUILD_DIR/$DMG_NAME" "$BUILD_DIR/$PKG_NAME"
