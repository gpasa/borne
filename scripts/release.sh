#!/bin/zsh
# Version publique : assemble, signe en Developer ID (runtime renforcé,
# horodatage), notarise, agrafe et zippe dans dist/ : une version Apple
# silicon, une version Intel.
#   scripts/release.sh            # complet
#   scripts/release.sh --no-notarize
# La notarisation échoue si l'écran est verrouillé (message trompeur sur les
# identifiants) : déverrouiller d'abord.
set -euo pipefail
cd "${0:A:h}/.."
APP=build/Build/Products/Release/Borne.app
PROFILE=${NOTARY_PROFILE:-TreeLevelMC}
ID=$(scripts/devid_identity.sh)

mkdir -p dist
# Deux versions, noms stables pour que les liens « latest » du site restent bons.
for ARCH in arm64 x86_64; do
    NAME=$([[ $ARCH == arm64 ]] && echo AppleSilicon || echo Intel)
    ARCH=$ARCH scripts/build_app.sh
    VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' $APP/Contents/Info.plist)
    FW=$APP/Contents/Frameworks/SDL3.framework

    sign() { codesign --force --timestamp --options runtime --sign $ID "$@"; }
    # Tout Mach-O d'un dossier, du plus profond au moins profond.
    sign_inside() {
        local dir=$1; shift
        [[ -d $dir ]] || return 0
        find $dir -type f \( -name '*.dylib' -o -perm +111 \) -print0 | xargs -0 file | grep -E 'Mach-O' | cut -d: -f1 |
            awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2- | while read -r f; do sign "$@" "$f"; done
    }
    sign $FW
    # Sparkle (mises à jour) : ses services d'abord, puis le framework.
    SP=$APP/Contents/Frameworks/Sparkle.framework
    if [[ -d $SP ]]; then
        sign $SP/Versions/B/XPCServices/Installer.xpc
        sign --preserve-metadata=entitlements $SP/Versions/B/XPCServices/Downloader.xpc
        sign $SP/Versions/B/Autoupdate
        sign $SP/Versions/B/Updater.app
        sign $SP
    fi
    for f in $APP/Contents/Frameworks/*.dylib(N); do sign $f; done
    [[ -x $APP/Contents/MacOS/vkquake ]] && sign $APP/Contents/MacOS/vkquake
    sign_inside $APP/Contents/Resources/Engines/Quake3e
    sign_inside $APP/Contents/Resources/Engines/yquake2
    # Moteurs embarqués : UZDoom/GZDoom compilent leurs scripts à la volée (JIT), comme MAME ;
    # DOSBox Staging aussi (recompilateur dynamique).
    for a in $APP/Contents/Resources/Engines/*.app(N); do
        ent=()
        [[ $a == *Doom.app || $a == *DOSBox* ]] && ent=(--entitlements Resources/mame.entitlements)
        sign_inside $a/Contents/Frameworks
        sign_inside $a/Contents/MacOS $ent
        sign $ent $a
    done
    sign --entitlements Resources/mame.entitlements $APP/Contents/MacOS/mame
    sign $APP
    codesign --verify --deep --strict --verbose=2 $APP

    ZIP=dist/Borne-$NAME.zip
    rm -f $ZIP
    ditto -c -k --keepParent $APP $ZIP

    if [[ ${1:-} != --no-notarize ]]; then
        xcrun notarytool submit $ZIP --keychain-profile $PROFILE --wait
        xcrun stapler staple $APP
        rm -f $ZIP
        ditto -c -k --keepParent $APP $ZIP
        spctl --assess --type execute --verbose=2 $APP
    fi
    echo "$NAME $VERSION : $(shasum -a 256 $ZIP)"
done
echo "Prêt : dist/Borne-AppleSilicon.zip et dist/Borne-Intel.zip"
echo "Ensuite : scripts/appcast.sh notes.html (flux de mise à jour), puis gh release create"
