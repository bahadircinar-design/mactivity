#!/bin/bash
# Folio is an iOS 27+ app. Build and run it from Xcode on a Mac.
set -euo pipefail
cd "$(dirname "$0")"

echo "Folio targets iPhone Duo (iOS 27)."
echo "Open the Xcode project:"
echo "  open Folio.xcodeproj"
echo ""
echo "Then pick an iPhone Duo simulator (or any iOS 27 simulator) and press Run."
echo "For a device build, set your Development Team under Signing & Capabilities."

if [[ "$(uname -s)" == "Darwin" ]] && command -v open >/dev/null 2>&1; then
  open Folio.xcodeproj
fi
