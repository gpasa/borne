#!/bin/zsh
# Compile UZDoom 5.0.3 pour Apple silicon avec le correctif de Borne
# (engines/patches/uzdoom-5.0.3-clear-render-targets.patch), puis l'empaquette
# comme l'intégration continue d'UZDoom : bibliothèques Homebrew rangées dans
# Contents/Frameworks par dylibbundler, plus SDL3 et MoltenVK (dernière version).
#
# Le correctif efface les images de rendu à leur création : sans lui, l'image
# Vulkan sort verte avec MoltenVK >= 1.2.7.
#
# Dépendances (Homebrew) : dylibbundler fluid-synth openal-soft vulkan-volk
#                          molten-vk libvpx sdl2 sdl3
# Résultat : ../Engines/x/UZDoom-borne.app
set -euo pipefail
BORNE=${0:A:h:h}
E=${ENGINES_DIR:-$BORNE/../Engines}
SRC=$E/downloads/uzdoom-src
OUT=$E/build/uzdoom
PATCH=$BORNE/engines/patches/uzdoom-5.0.3-clear-render-targets.patch

[[ -d $SRC ]] || git clone -q --depth 1 --branch 5.0.3 https://github.com/UZDoom/UZDoom.git $SRC
(cd $SRC && git checkout -q -- . && git apply $PATCH)

# SDL2 de Homebrew, pas un SDL2.framework de /Library/Frameworks que dylibbundler ne recopierait pas.
rm -rf $OUT
cmake -S $SRC -B $OUT -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_FIND_FRAMEWORK=LAST -DSDL2_DIR=$(brew --prefix sdl2)/lib/cmake/SDL2 \
    -DHAVE_VULKAN=ON -DHAVE_GLES2=OFF -DDYN_OPENAL=OFF -DDYN_SNDFILE=OFF \
    -DOPENAL_INCLUDE_DIR=/opt/homebrew/opt/openal-soft/include/AL \
    -DOPENAL_LIBRARY=/opt/homebrew/opt/openal-soft/lib/libopenal.dylib > $OUT.cmake.log
cmake --build $OUT -j$(sysctl -n hw.ncpu) > $OUT.build.log

APP=$E/x/UZDoom-borne.app
rm -rf $APP
ditto $OUT/uzdoom.app $APP
FW=$APP/Contents/Frameworks
mkdir -p $FW
dylibbundler -od -b -cd -x $APP/Contents/MacOS/uzdoom -d $FW -p @executable_path/../Frameworks/ \
    -s /opt/homebrew/lib > $OUT.bundle.log
# dylibbundler peut ajouter deux fois le même rpath : dyld refuse alors de lancer.
for rp in $(otool -l $APP/Contents/MacOS/uzdoom | awk '/LC_RPATH/{getline; getline; print $2}' | sort | uniq -d); do
    while (( $(otool -l $APP/Contents/MacOS/uzdoom | grep -c "path $rp ") > 1 )); do
        install_name_tool -delete_rpath $rp $APP/Contents/MacOS/uzdoom
    done
done
# SDL2 de Homebrew (sdl2-compat) charge SDL3 à l'exécution ; volk cherche MoltenVK par son nom.
cp -L $(brew --prefix sdl3)/lib/libSDL3.dylib $FW/libSDL3.dylib
cp -L $(brew --prefix molten-vk)/lib/libMoltenVK.dylib $FW/libMoltenVK.dylib
chmod u+w $FW/*.dylib
install_name_tool -id @rpath/libSDL3.dylib $FW/libSDL3.dylib
install_name_tool -id @rpath/libMoltenVK.dylib $FW/libMoltenVK.dylib
# Licences d'UZDoom, comme dans ses versions officielles.
(cd $SRC/docs/licenses && rm -f $APP/Contents/Resources/licenses.zip && zip -q -r $APP/Contents/Resources/licenses.zip .)
codesign --force --deep --sign - $APP > /dev/null
echo "UZDoom corrigé : $APP (MoltenVK $(strings -a $FW/libMoltenVK.dylib | grep -m1 -E '^1\.[0-9]+\.[0-9]+$'))"
