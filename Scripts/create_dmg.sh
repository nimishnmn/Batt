#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

echo "🔨 Ensuring Batt.app is built..."
./Scripts/build_app.sh

DMG_NAME="Batt-1.0.0.dmg"
VOLUME_NAME="Batt Installer"
STAGING_DIR="dmg_staging"

echo "📦 Preparing DMG staging directory..."
rm -rf "$STAGING_DIR" "$DMG_NAME"
mkdir -p "$STAGING_DIR"

# Copy App into staging
cp -R "Batt.app" "$STAGING_DIR/"

# Create symlink to /Applications for easy drag-and-drop install
ln -s /Applications "$STAGING_DIR/Applications"

echo "💿 Creating compressed DMG image: ${DMG_NAME}..."
hdiutil create -volname "${VOLUME_NAME}" -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_NAME}"

# Clean up staging directory
rm -rf "$STAGING_DIR"

echo "✅ DMG created successfully at ${DIR}/${DMG_NAME}"
ls -lh "${DMG_NAME}"
