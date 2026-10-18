#!/bin/zsh
# Assemble Borne et l'installe dans ~/Applications (rm -rf + ditto).
set -euo pipefail
cd "${0:A:h}/.."
APP=build/Build/Products/Release/Borne.app
scripts/build_app.sh
osascript -e 'tell application "Borne" to quit' 2>/dev/null || true
rm -rf ~/Applications/Borne.app
ditto $APP ~/Applications/Borne.app
echo "Installé : ~/Applications/Borne.app ($(du -sh ~/Applications/Borne.app | cut -f1))"
