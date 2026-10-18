#!/bin/zsh
# Assemble Borne.app (Release) pour une architecture, avec mame embarqué : binaire allégé, SDL3,
# fichiers de support et licences. Signature ad hoc ; release.sh re-signe.
# Les ROM, samples, artwork et images restent sur le disque des jeux.
set -euo pipefail
cd "${0:A:h}/.."
# Deux versions séparées : ARCH=arm64 (Apple silicon) ou ARCH=x86_64 (Intel).
ARCH=${ARCH:-$(uname -m)}
case $ARCH in
    arm64)  MAME=${MAME_DIR:-../MAME} ;;
    x86_64) MAME=${MAME_X64_DIR:-../MAME-x64} ;;   # compilé sous Rosetta
    *) echo "ARCH inconnue : $ARCH"; exit 1 ;;
esac
SDL3=/Library/Frameworks/SDL3.xcframework/macos-arm64_x86_64/SDL3.framework
APP=build/Build/Products/Release/Borne.app

[[ -x $MAME/mame ]] || { echo "mame introuvable dans $MAME (le compiler d'abord)"; exit 1; }

xcodegen generate -q
xcodebuild -project Borne.xcodeproj -scheme Borne -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath build -quiet \
    ARCHS=$ARCH ONLY_ACTIVE_ARCH=NO build

# Binaire : allégé, rpath vers Contents/Frameworks au lieu de /Library.
[[ $(lipo -archs $MAME/mame) == $ARCH ]] || { echo "$MAME/mame n'est pas en $ARCH"; exit 1; }
strip -x -o $APP/Contents/MacOS/mame $MAME/mame
for old in $(otool -l $APP/Contents/MacOS/mame | awk '/LC_RPATH/{getline; getline; print $2}'); do
    install_name_tool -delete_rpath $old $APP/Contents/MacOS/mame
done
install_name_tool -add_rpath @executable_path/../Frameworks $APP/Contents/MacOS/mame

# SDL3 : le framework de /Library a ses liens aplatis en copies ; on
# reconstruit la structure Versions/A + liens, sans les en-têtes.
FW=$APP/Contents/Frameworks/SDL3.framework
rm -rf $FW && mkdir -p $FW/Versions
ditto $SDL3/Versions/A $FW/Versions/A
rm -rf $FW/Versions/A/Headers
# Le framework de SDL est universel : on ne garde que l'architecture visée.
lipo -thin $ARCH $FW/Versions/A/SDL3 -output $FW/Versions/A/SDL3.thin
mv $FW/Versions/A/SDL3.thin $FW/Versions/A/SDL3
ln -s A $FW/Versions/Current
ln -s Versions/Current/SDL3 $FW/SDL3
ln -s Versions/Current/Resources $FW/Resources

# Fichiers de support (les .po des traductions ne servent pas, seuls les .mo).
R=$APP/Contents/Resources/mame
rm -rf $R && mkdir -p $R
for d in hash plugins bgfx artwork ctrlr keymaps samples; do
    ditto $MAME/$d $R/$d
done
rsync -a --include='*/' --include='*.mo' --exclude='*' $MAME/language/ $R/language/
cp $MAME/uismall.bdf $R/ 2>/dev/null || true
# Touches adaptées au clavier Mac (pas de Ctrl : Ctrl+flèche est à macOS).
cp Resources/ctrlr/borne_mac.cfg $R/ctrlr/

# Moteurs de jeux PC (scripts/prepare_engines.sh) : Doom, Quake, Wolfenstein 3D, Freedoom.
PAYLOAD=${ENGINES_DIR:-../Engines}/payload/$ARCH
# Le dossier de compilation sert aux deux architectures : on repart de zéro.
rm -rf $APP/Contents/Resources/{Engines,vulkan,freedoom,Licenses-engines} $APP/Contents/MacOS/vkquake \
    $APP/Contents/Frameworks/{libvulkan.1.dylib,libMoltenVK.dylib,libvulkan_kosmickrisp.dylib}
if [[ -d $PAYLOAD ]]; then
    ditto $PAYLOAD/Engines $APP/Contents/Resources/Engines
    cp $PAYLOAD/MacOS/vkquake $APP/Contents/MacOS/vkquake
    cp $PAYLOAD/Frameworks/*.dylib $APP/Contents/Frameworks/
    ditto $PAYLOAD/vulkan $APP/Contents/Resources/vulkan
    ditto $PAYLOAD/freedoom $APP/Contents/Resources/freedoom
    ditto $PAYLOAD/licenses $APP/Contents/Resources/Licenses-engines
else
    echo "Pas de moteurs de jeux PC pour $ARCH (lancer scripts/prepare_engines.sh)"
fi

# Licences : Borne (GPL-3.0), MAME (GPL-2.0+ et licences de ses parties), SDL3 (zlib).
L=$APP/Contents/Resources/Licenses
rm -rf $L && mkdir -p $L/MAME $L/SDL3
cp LICENSE $L/Borne-GPL-3.0.txt
cp $MAME/COPYING $L/MAME/COPYING
ditto $MAME/docs/legal $L/MAME/legal
cp $SDL3/Resources/LICENSE.txt $L/SDL3/LICENSE.txt
if [[ -d $APP/Contents/Resources/Licenses-engines ]]; then
    ditto $APP/Contents/Resources/Licenses-engines $L
    rm -rf $APP/Contents/Resources/Licenses-engines
fi

codesign --force --sign - $FW
for f in $APP/Contents/Frameworks/*.dylib(N) $APP/Contents/MacOS/vkquake(N); do codesign --force --sign - $f; done
for a in $APP/Contents/Resources/Engines/*.app(N); do codesign --force --deep --sign - $a; done
codesign --force --sign - $APP/Contents/MacOS/mame
codesign --force --sign - $APP
echo "Assemblé ($ARCH) : $APP"
