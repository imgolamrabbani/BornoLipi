#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/BornoLipi.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🔨 Building বর্ণলিপি (BornoLipi.app)..."

rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

cp "${SCRIPT_DIR}/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
cp "${SCRIPT_DIR}/Resources/BijoyClassic.xml" "${RESOURCES_DIR}/BijoyClassic.xml"
cp "${SCRIPT_DIR}/Resources/Unicode.xml" "${RESOURCES_DIR}/Unicode.xml"
cp "${SCRIPT_DIR}/Resources/bijoy_keymap.png" "${RESOURCES_DIR}/bijoy_keymap.png"

if [[ -d "${SCRIPT_DIR}/Resources/Assets" ]]; then
    cp "${SCRIPT_DIR}/Resources/Assets/"*.png "${RESOURCES_DIR}/"
fi

if [[ -f "${SCRIPT_DIR}/Resources/AppIcon.icns" ]]; then
    cp "${SCRIPT_DIR}/Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

swiftc \
    -O \
    -framework Cocoa \
    -framework ApplicationServices \
    "${SCRIPT_DIR}/Sources/Models/KeyboardLayoutModel.swift" \
    "${SCRIPT_DIR}/Sources/Engine/BijoyLayoutParser.swift" \
    "${SCRIPT_DIR}/Sources/Engine/BijoyTypingEngine.swift" \
    "${SCRIPT_DIR}/Sources/Engine/EncodingConverter.swift" \
    "${SCRIPT_DIR}/Sources/Engine/GlobalKeyboardHook.swift" \
    "${SCRIPT_DIR}/Sources/UI/FloatingToolbarWindow.swift" \
    "${SCRIPT_DIR}/Sources/UI/SplashCanvasWindow.swift" \
    "${SCRIPT_DIR}/Sources/UI/KeymapOverlayWindow.swift" \
    "${SCRIPT_DIR}/Sources/UI/StudioWindowController.swift" \
    "${SCRIPT_DIR}/Sources/UI/AppDelegate.swift" \
    "${SCRIPT_DIR}/Sources/main.swift" \
    -o "${MACOS_DIR}/BornoLipi"

codesign --force --deep --sign - "${APP_BUNDLE}"

echo "✅ Built successfully at: ${APP_BUNDLE}"
