#!/bin/sh
# Builds SVG Cleaner.app and installs it in ~/Applications.
# Usage: ./build.sh [--no-install]
set -eu

cd "$(dirname "$0")"

APP_NAME="SVG Cleaner"
BUNDLE="build/$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"

if [ ! -f Resources/svgo.js ]; then
    (cd vendor && npm install && npm run build)
fi

swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources"
cp "$BIN_DIR/SVGCleaner" "$BUNDLE/Contents/MacOS/"
cp Resources/Info.plist "$BUNDLE/Contents/"
cp Resources/AppIcon.icns Resources/svgo.js "$BUNDLE/Contents/Resources/"

codesign --force --deep --sign - "$BUNDLE"
echo "Built $BUNDLE"

if [ "${1:-}" != "--no-install" ]; then
    mkdir -p "$INSTALL_DIR"
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
    cp -R "$BUNDLE" "$INSTALL_DIR/"
    echo "Installed in $INSTALL_DIR/$APP_NAME.app"
fi
