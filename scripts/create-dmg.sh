#!/bin/bash
set -euo pipefail

APP_BUNDLE="${1:?Usage: create-dmg.sh <app-bundle-path> [version]}"
VERSION="${2:-1.0.0}"
APP_NAME="MakeMyMacFastAgain"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
VOLUME_NAME="Make My Mac Fast Again"
STAGING_DIR=""
trap 'if [ -n "$STAGING_DIR" ]; then rm -rf "$STAGING_DIR"; fi' EXIT

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: App bundle not found at $APP_BUNDLE"
    exit 1
fi

# Clean up any previous DMG
rm -f "$DMG_NAME"

# Try create-dmg (brew install create-dmg) for a polished DMG
if command -v create-dmg &> /dev/null; then
    echo "Using create-dmg for polished DMG layout..."
    create-dmg \
        --volname "$VOLUME_NAME" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 128 \
        --icon "$APP_NAME.app" 150 190 \
        --app-drop-link 450 190 \
        --no-internet-enable \
        "$DMG_NAME" \
        "$APP_BUNDLE"
else
    echo "create-dmg not found, using hdiutil fallback..."
    echo "  (Install create-dmg for a polished layout: brew install create-dmg)"

    # Create a temporary directory for DMG contents
    STAGING_DIR=$(mktemp -d)

    # Copy app bundle and create Applications symlink
    cp -R "$APP_BUNDLE" "$STAGING_DIR/"
    ln -s /Applications "$STAGING_DIR/Applications"

    # Create DMG from staging directory
    hdiutil create -volname "$VOLUME_NAME" \
        -srcfolder "$STAGING_DIR" \
        -ov -format UDZO \
        "$DMG_NAME"
fi

echo ""
echo "DMG created: $DMG_NAME"
ls -lh "$DMG_NAME"
