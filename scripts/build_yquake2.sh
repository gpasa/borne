#!/bin/zsh
# Compile Yamagi Quake II 8.70 (Quake II, GPL-2.0) et le code de jeu de ses
# extensions, The Reckoning (xatrix 2.17), Ground Zero (rogue 2.16) et Capture
# The Flag (ctf 1.13), en universel. SDL3 : celle de Borne (rangement dans Resources/Engines/yquake2,
# trois niveaux sous Contents) ; son par SDL (pas d'OpenAL à embarquer).
# Résultat : ../Engines/build/yquake2/{quake2,ref_*.dylib,baseq2,rogue,xatrix,ctf}
set -euo pipefail
BORNE=${0:A:h:h}
E=${ENGINES_DIR:-$BORNE/../Engines}
D=$E/downloads
OUT=$E/build/yquake2
SDL3=/Library/Frameworks/SDL3.xcframework/macos-arm64_x86_64/SDL3.framework
[[ -x $OUT/quake2 ]] && { echo "Yamagi Quake II déjà compilé : $OUT"; exit 0; }
src() { [[ -d $D/$1 ]] || git clone -q --depth 1 --branch $3 https://github.com/yquake2/$2.git $D/$1; }
src yquake2-8.70 yquake2 QUAKE2_8_70
src yquake2-rogue-2.16 rogue ROGUE_2_16
src yquake2-xatrix-2.17 xatrix XATRIX_2_17
src yquake2-ctf-1.13 ctf CTF_1_13
common=(-G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64"
        -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0)
B=$E/build/yquake2-build
cmake -S $D/yquake2-8.70 -B $B/main $common -DSDL3_SUPPORT=ON -DSDL3_DIR=$SDL3/Resources/CMake \
    -DCMAKE_FRAMEWORK_PATH=${SDL3:h} -DOPENAL_SUPPORT=OFF -DCURL_SUPPORT=OFF -DXDG_SUPPORT=OFF \
    > $E/build/yquake2.log 2>&1
ninja -C $B/main >> $E/build/yquake2.log 2>&1
for pack in rogue xatrix ctf; do
    dir=($D/yquake2-$pack-*)
    cmake -S $dir[1] -B $B/$pack $common >> $E/build/yquake2.log 2>&1
    ninja -C $B/$pack >> $E/build/yquake2.log 2>&1
done
rm -rf $OUT && mkdir -p $OUT/licenses
ditto $B/main/release $OUT
for pack in rogue xatrix ctf; do
    mkdir -p $OUT/$pack
    cp $(find $B/$pack -name 'game.dylib' | head -1) $OUT/$pack/game.dylib
done
cp $D/yquake2-8.70/LICENSE $OUT/licenses/yquake2-LICENSE.txt
cp $D/yquake2-rogue-2.16/LICENSE $OUT/licenses/rogue-LICENSE.txt
cp $D/yquake2-xatrix-2.17/LICENSE $OUT/licenses/xatrix-LICENSE.txt
cp $D/yquake2-ctf-1.13/LICENSE $OUT/licenses/ctf-LICENSE.txt
for f in $OUT/quake2 $OUT/ref_*.dylib; do
    otool -L $f | grep -q SDL3 && install_name_tool -add_rpath @loader_path/../../../Frameworks $f
done
if otool -L $OUT/quake2 $OUT/*.dylib $OUT/*/game.dylib | grep -E '^\s*(/opt/homebrew|/usr/local|/opt/local|/Library/Frameworks)'; then
    echo "Yamagi Quake II : dépendances externes (ci-dessus)"; exit 1
fi
codesign --force --sign - $OUT/quake2 $OUT/*.dylib $OUT/*/game.dylib 2>/dev/null
echo "Yamagi Quake II : $(lipo -archs $OUT/quake2) ; $(ls $OUT | tr '\n' ' ')"
