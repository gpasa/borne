#!/bin/zsh
# Assemble Borne.app (Release) avec mame embarqué : binaire allégé, SDL3,
# fichiers de support et licences. Signature ad hoc ; release.sh re-signe.
# Les ROM, samples, artwork et images restent sur le disque des jeux.
set -euo pipefail
cd "${0:A:h}/.."
MAME=${MAME_DIR:-../MAME}
SDL3=/Library/Frameworks/SDL3.xcframework/macos-arm64_x86_64/SDL3.framework
APP=build/Build/Products/Release/Borne.app

[[ -x $MAME/mame ]] || { echo "mame introuvable dans $MAME (le compiler d'abord)"; exit 1; }

xcodegen generate -q
xcodebuild -project Borne.xcodeproj -scheme Borne -configuration Release \
    -derivedDataPath build -quiet build

# Binaire : allégé, rpath vers Contents/Frameworks au lieu de /Library.
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

# Licences : Borne (GPL-3.0), MAME (GPL-2.0+ et licences de ses parties), SDL3 (zlib).
L=$APP/Contents/Resources/Licenses
rm -rf $L && mkdir -p $L/MAME $L/SDL3
cp LICENSE $L/Borne-GPL-3.0.txt
cp $MAME/COPYING $L/MAME/COPYING
ditto $MAME/docs/legal $L/MAME/legal
cp $SDL3/Resources/LICENSE.txt $L/SDL3/LICENSE.txt

codesign --force --sign - $FW
codesign --force --sign - $APP/Contents/MacOS/mame
codesign --force --sign - $APP
echo "Assemblé : $APP"
