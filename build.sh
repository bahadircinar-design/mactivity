#!/bin/bash
# Builds Mactivity.app from source and opens it.
#   ./build.sh            build into ./build and launch
#   ./build.sh --install  build, copy to /Applications and launch
# Needs Xcode or the Command Line Tools (xcode-select --install).
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Mactivity"
APP="build/${APP_NAME}.app"

if ! command -v swift >/dev/null 2>&1; then
  echo "Swift isn't installed. Install Xcode from the App Store, or run: xcode-select --install"
  exit 1
fi

echo "▸ Compiling ${APP_NAME} (the first build takes a minute or two)…"
swift build -c release --product "${APP_NAME}"
BIN_DIR="$(swift build -c release --show-bin-path)"

echo "▸ Assembling ${APP}…"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "${BIN_DIR}/${APP_NAME}" "${APP}/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "${APP}/Contents/Info.plist"
cp Resources/AppIcon.icns "${APP}/Contents/Resources/AppIcon.icns"

echo "▸ Signing for this Mac…"
codesign --force --sign - "${APP}" >/dev/null 2>&1 || echo "  (signing skipped)"

if [[ "${1:-}" == "--install" ]]; then
  rm -rf "/Applications/${APP_NAME}.app"
  cp -R "${APP}" /Applications/
  echo "✓ Installed to /Applications/${APP_NAME}.app"
  open "/Applications/${APP_NAME}.app"
else
  echo "✓ Built ${APP}"
  open "${APP}"
fi
