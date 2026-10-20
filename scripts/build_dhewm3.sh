#!/bin/zsh
# Compile dhewm3 1.5.5 (Doom 3 et Resurrection of Evil, code source GPL d'id
# Software maintenu) en universel : SDL3 de Borne (/Library/Frameworks, celui
# qu'embarque Borne pour MAME), OpenAL Soft statique de zdoom-macos-deps.
# Résultat : ../Engines/build/dhewm3/dhewm3.app, bibliothèques de jeu (base, d3xp)
# dans Contents/MacOS/base, où dhewm3 les cherche dans une app. SDL3 : celle de Borne, l'app étant
# rangée dans Borne.app/Contents/Resources/Engines (cinq niveaux plus haut).
set -euo pipefail
BORNE=${0:A:h:h}
E=${ENGINES_DIR:-$BORNE/../Engines}
SRC=$E/downloads/dhewm3-1.5.5
OUT=$E/build/dhewm3
OAL=$E/downloads/zdoom-macos-deps/deps/openal
SDL3=/Library/Frameworks/SDL3.xcframework/macos-arm64_x86_64/SDL3.framework
[[ -d $SRC ]] || git clone -q --depth 1 --branch 1.5.5 https://github.com/dhewm/dhewm3.git $SRC
[[ -d $OAL ]] || $BORNE/scripts/build_zdoom_ports.sh gzdoom   # récupère zdoom-macos-deps
# Le portage Mac de 1.5.5 n'a jamais compilé avec SDL3 : petit correctif.
grep -q SDL_EVENT_QUIT $SRC/neo/sys/osx/SDLMain.m || patch -s -d $SRC/neo -p0 < $BORNE/engines/patches/dhewm3-1.5.5-macos-sdl3.patch
[[ -d $OUT/dhewm3.app ]] && { echo "dhewm3 déjà compilé : $OUT"; exit 0; }
B=$E/build/dhewm3-build
[[ -f $B/build.ninja ]] || cmake -S $SRC/neo -B $B -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
    -DSDL2=OFF -DSDL3=ON -DSDL3_DIR=$SDL3/Resources/CMake -DCMAKE_FRAMEWORK_PATH=${SDL3:h} \
    -DOPENAL_INCLUDE_DIR=$OAL/include -DOPENAL_LIBRARY="$OAL/lib/libopenal.a;-framework CoreAudio;-framework AudioToolbox;-framework AudioUnit;-framework CoreFoundation" \
    -DCMAKE_DISABLE_FIND_PACKAGE_CURL=ON -DIMGUI=ON \
    > $E/build/dhewm3.log 2>&1
ninja -C $B >> $E/build/dhewm3.log 2>&1
rm -rf $OUT && mkdir -p $OUT
A=$OUT/dhewm3.app
ditto $B/dhewm3.app $A
mkdir -p $A/Contents/MacOS/base
cp $B/base.dylib $B/d3xp.dylib $A/Contents/MacOS/base/
mkdir -p $A/Contents/Resources/licenses
install_name_tool -add_rpath @executable_path/../../../../../Frameworks $A/Contents/MacOS/dhewm3
cp $SRC/COPYING.txt $SRC/README.md $A/Contents/Resources/licenses/
cp $BORNE/engines/patches/dhewm3-1.5.5-macos-sdl3.patch $A/Contents/Resources/licenses/
if otool -L $A/Contents/MacOS/* | grep -E '^\s*(/opt/homebrew|/usr/local|/opt/local|/Library/Frameworks)'; then
    echo "dhewm3 : dépendances externes (ci-dessus)"; exit 1
fi
codesign --force --deep --sign - $A
echo "dhewm3 : $(lipo -archs $A/Contents/MacOS/dhewm3)"
