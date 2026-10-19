#!/bin/zsh
# Raze corrigé (scripts/build_zdoom_ports.sh raze), signé Developer ID et
# notarisé, publié dans une release à part du dépôt de Borne, que Borne
# télécharge sur demande (Raze n'est pas embarqué : licence Build).
# La licence Build permet la redistribution non commerciale avec le source :
# source amont à l'étiquette 1.11.0 + engines/patches/zdoom-cocoa-cursor-warp.patch.
#   scripts/release_raze.sh   # prépare dist/Raze-1.11.0-borne.zip
set -euo pipefail
cd "${0:A:h}/.."
E=${ENGINES_DIR:-../Engines}
TAG=raze-1.11.0-borne
ZIP=dist/Raze-1.11.0-borne.zip
ID=$(scripts/devid_identity.sh)
PROFILE=${NOTARY_PROFILE:-TreeLevelMC}

scripts/build_zdoom_ports.sh raze
W=$(mktemp -d)
ditto $E/build/zdoom-ports/Raze.app $W/Raze.app
L=$W/Raze.app/Contents/Resources/licenses
mkdir -p $L
cp $E/downloads/raze-1.11.0/package/common/buildlic.txt $L/BUILDLIC.TXT
cp $E/downloads/raze-1.11.0/package/common/gpl-2.0.txt $L/
cp engines/patches/zdoom-cocoa-cursor-warp.patch $L/
cat > $L/SOURCE.txt <<'TXT'
Raze 1.11.0 built by Borne (https://github.com/gpasa/borne) with one change:
engines/patches/zdoom-cocoa-cursor-warp.patch (included here), so that Raze
recenters the pointer without asking for macOS Accessibility access.
Upstream source: https://github.com/ZDoom/Raze/tree/1.11.0
Build tooling: https://github.com/ZDoom/zdoom-macos-deps
The patched file (common/platform/posix/cocoa/i_input.mm) is GPL code, not Build source.

// "Build Engine & Tools" Copyright (c) 1993-1997 Ken Silverman
// Ken Silverman's official web site: "http://www.advsys.net/ken"
// See the included license file "BUILDLIC.TXT" for license info.
TXT

sign() { codesign --force --timestamp --options runtime --sign $ID "$@"; }
# Un seul Mach-O (MoltenVK est lié en statique). Les données rangées dans
# MacOS (raze.pk3, soundfonts) doivent être signées une à une (signature en
# attributs étendus, que ditto garde dans le zip), puis l'app.
find $W/Raze.app/Contents/MacOS -type f ! -name raze | while read -r f; do sign "$f"; done
sign $W/Raze.app
codesign --verify --deep --strict $W/Raze.app
mkdir -p dist && rm -f $ZIP
ditto -c -k --keepParent $W/Raze.app $ZIP
xcrun notarytool submit $ZIP --keychain-profile $PROFILE --wait
xcrun stapler staple $W/Raze.app
rm -f $ZIP && ditto -c -k --keepParent $W/Raze.app $ZIP
spctl --assess --type execute --verbose=2 $W/Raze.app
rm -rf $W
echo "Raze : $ZIP $(shasum -a 256 $ZIP | cut -d' ' -f1)"
echo "Publier : gh release create $TAG $ZIP --latest=false --title 'Raze 1.11.0 for Borne' --notes-file …"
