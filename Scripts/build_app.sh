#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

echo "🔨 Building Batt Universal Binary (arm64 + x86_64)..."
if DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c release --arch arm64 --arch x86_64 2>/dev/null; then
    echo "✅ Built using Xcode multi-arch driver"
else
    echo "⚠️ Falling back to CommandLineTools dual-slice build + lipo..."
    swift build -c release --triple arm64-apple-macosx
    swift build -c release --triple x86_64-apple-macosx
    mkdir -p .build/universal/release
    lipo -create -output .build/universal/release/Batt .build/arm64-apple-macosx/release/Batt .build/x86_64-apple-macosx/release/Batt
fi

APP_NAME="Batt"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Creating macOS App Bundle ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy universal binary
if [ -f ".build/universal/release/${APP_NAME}" ]; then
    cp ".build/universal/release/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
elif [ -f ".build/apple/Products/Release/${APP_NAME}" ]; then
    cp ".build/apple/Products/Release/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
else
    cp ".build/release/${APP_NAME}" "${MACOS_DIR}/${APP_NAME}"
fi
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Verify architectures
echo "🔍 Verifying binary architectures:"
lipo -info "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist and PkgInfo
cp "Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

# Copy Icon
if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

# Code sign (ad-hoc with deep entitlements)
echo "✍️  Ad-hoc codesigning ${APP_BUNDLE}..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "✅ Batt.app created successfully at ${DIR}/${APP_BUNDLE}"
