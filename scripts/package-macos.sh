#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

VERSION="${1:-$(tr -d '[:space:]' < VERSION)}"
APP_NAME="Frozen Bubble Swift"
EXECUTABLE_NAME="FrozenBubbleSwift"
BUNDLE_ID="de.twocent.frozenbubble"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
RESOURCE_BUNDLE="FrozenBubbleSwift_FrozenBubbleSwift.bundle"
ICON_SOURCE="$ROOT_DIR/Assets/Icon/frozen-bubble-swift-icon-source.png"
ICONSET="$DIST_DIR/AppIcon.iconset"
ZIP_PATH="$DIST_DIR/FrozenBubbleSwift-v$VERSION-macOS.zip"

rm -rf "$DIST_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

swift build -c release

cp "$ROOT_DIR/.build/release/$EXECUTABLE_NAME" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
cp -R "$ROOT_DIR/.build/release/$RESOURCE_BUNDLE" "$APP_BUNDLE/Contents/Resources/$RESOURCE_BUNDLE"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
PLIST

if [[ -f "$ICON_SOURCE" ]]; then
    mkdir -p "$ICONSET"
    sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET/icon_16x16.png" >/dev/null
    sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
    sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET/icon_32x32.png" >/dev/null
    sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
    sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET/icon_128x128.png" >/dev/null
    sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
    sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET/icon_256x256.png" >/dev/null
    sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
    sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET/icon_512x512.png" >/dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
    iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    rm -rf "$ICONSET"
fi

IDENTITY="${CODESIGN_IDENTITY:-}"
if [[ -z "$IDENTITY" ]]; then
    IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F '\"' '/Developer ID Application/ { print $2; exit }')"
fi

if [[ -n "$IDENTITY" ]]; then
    codesign --force --deep --options runtime --timestamp --sign "$IDENTITY" "$APP_BUNDLE"
    codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
else
    echo "warning: no Developer ID Application identity found; package remains unsigned" >&2
fi

ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
echo "$ZIP_PATH"
