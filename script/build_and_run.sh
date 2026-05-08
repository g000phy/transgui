#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="TransmissionRemoteMac"
BUNDLE_ID="com.g000phy.TransmissionRemoteMac"
MIN_SYSTEM_VERSION="15.0"
VERSION="0.1.3"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SWIFT_DIR="$ROOT_DIR/native-mac"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SOURCE="$ROOT_DIR/setup/macosx/transgui.icns"
ICON_NAME="TransmissionRemoteMac.icns"
ICONSET_DIR="$DIST_DIR/$APP_NAME.iconset"
ICON_BASE_PNG="$DIST_DIR/$APP_NAME-icon.png"

BUILD_CONFIGURATION="debug"
if [[ "$MODE" == "--release" || "$MODE" == "release" ]]; then
  BUILD_CONFIGURATION="release"
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

cd "$SWIFT_DIR"
if [[ "$BUILD_CONFIGURATION" == "release" ]]; then
  swift build -c release
  BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"
else
  swift build
  BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

build_app_icon() {
  rm -rf "$ICONSET_DIR" "$ICON_BASE_PNG"
  mkdir -p "$ICONSET_DIR"

  sips -s format png "$ICON_SOURCE" --out "$ICON_BASE_PNG" >/dev/null
  sips -z 16 16 "$ICON_BASE_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_BASE_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_BASE_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_BASE_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_BASE_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_BASE_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_BASE_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_BASE_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_BASE_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_BASE_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "$ICONSET_DIR" -o "$APP_RESOURCES/$ICON_NAME"
  rm -rf "$ICONSET_DIR" "$ICON_BASE_PNG"
}

if ! build_app_icon; then
  cp "$ICON_SOURCE" "$APP_RESOURCES/$ICON_NAME"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleDisplayName</key>
  <string>Transmission Remote Mac</string>
  <key>CFBundleIconFile</key>
  <string>${ICON_NAME%.icns}</string>
  <key>CFBundleIconName</key>
  <string>TransmissionRemoteMac</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$VERSION</string>
  <key>CFBundleName</key>
  <string>Transmission Remote Mac</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeIconFile</key>
      <string>${ICON_NAME%.icns}</string>
      <key>CFBundleTypeExtensions</key>
      <array>
        <string>torrent</string>
      </array>
      <key>LSItemContentTypes</key>
      <array>
        <string>org.bittorrent.torrent</string>
      </array>
      <key>CFBundleTypeName</key>
      <string>Torrent File</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
    </dict>
  </array>
  <key>UTImportedTypeDeclarations</key>
  <array>
    <dict>
      <key>UTTypeIdentifier</key>
      <string>org.bittorrent.torrent</string>
      <key>UTTypeDescription</key>
      <string>BitTorrent File</string>
      <key>UTTypeConformsTo</key>
      <array>
        <string>public.data</string>
      </array>
      <key>UTTypeTagSpecification</key>
      <dict>
        <key>public.filename-extension</key>
        <array>
          <string>torrent</string>
        </array>
        <key>public.mime-type</key>
        <array>
          <string>application/x-bittorrent</string>
        </array>
      </dict>
    </dict>
  </array>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>CFBundleURLName</key>
      <string>magnet</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>magnet</string>
      </array>
    </dict>
  </array>
  <key>NSLocalNetworkUsageDescription</key>
  <string>Transmission Remote Mac needs local network access to connect to Transmission servers on your LAN.</string>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
  </dict>
</dict>
</plist>
PLIST

xattr -cr "$APP_BUNDLE" 2>/dev/null || true
codesign --force --sign - "$APP_BUNDLE" >/dev/null

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  --release|release)
    echo "$APP_BUNDLE"
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify|--release]" >&2
    exit 2
    ;;
esac
