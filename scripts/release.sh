#!/bin/zsh
# Version publique : assemble, signe en Developer ID (runtime renforcé,
# horodatage), notarise, agrafe et zippe dans dist/.
#   scripts/release.sh            # complet
#   scripts/release.sh --no-notarize
# La notarisation échoue si l'écran est verrouillé (message trompeur sur les
# identifiants) : déverrouiller d'abord.
set -euo pipefail
cd "${0:A:h}/.."
APP=build/Build/Products/Release/Borne.app
PROFILE=${NOTARY_PROFILE:-TreeLevelMC}
ID=$(scripts/devid_identity.sh)

scripts/build_app.sh
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' $APP/Contents/Info.plist)
FW=$APP/Contents/Frameworks/SDL3.framework

sign() { codesign --force --timestamp --options runtime --sign $ID "$@"; }
sign $FW
sign --entitlements Resources/mame.entitlements $APP/Contents/MacOS/mame
sign $APP
codesign --verify --deep --strict --verbose=2 $APP

mkdir -p dist
ZIP=dist/Borne-$VERSION.zip
rm -f $ZIP
ditto -c -k --keepParent $APP $ZIP

if [[ ${1:-} != --no-notarize ]]; then
    xcrun notarytool submit $ZIP --keychain-profile $PROFILE --wait
    xcrun stapler staple $APP
    rm -f $ZIP
    ditto -c -k --keepParent $APP $ZIP
    spctl --assess --type execute --verbose=2 $APP
fi
shasum -a 256 $ZIP
echo "Prêt : $ZIP"
