#!/bin/zsh
# Compile KosmicKrisp (pilote Vulkan de Mesa sur Metal 4 : Apple silicon,
# macOS 26) depuis la version stable de Mesa, sans le Vulkan SDK.
# Dépendances Homebrew : llvm libclc spirv-llvm-translator spirv-tools meson ninja ;
# Python ≥ 3.10 (python3.13 de Homebrew) : mako pyyaml packaging meson dans ~/venv_mesa.
# Résultat : ../Engines/build/kosmickrisp/libvulkan_kosmickrisp.dylib, autonome.
set -euo pipefail
BORNE=${0:A:h:h}
E=${ENGINES_DIR:-$BORNE/../Engines}
TAG=mesa-26.2.5
SRC=$E/downloads/mesa
OUT=$E/build/kosmickrisp
[[ -d $SRC ]] || git clone -q --depth 1 --branch $TAG https://gitlab.freedesktop.org/mesa/mesa.git $SRC
[[ -f $OUT/libvulkan_kosmickrisp.dylib ]] && { echo "KosmicKrisp déjà compilé : $OUT"; exit 0; }
[[ -x ~/venv_mesa/bin/python3.13 ]] || { $(brew --prefix)/bin/python3.13 -m venv --clear ~/venv_mesa && ~/venv_mesa/bin/pip -q install mako pyyaml packaging meson; }
# Clang d'Apple pour compiler ; llvm-config de Homebrew trouvé après /usr/bin.
export PATH=~/venv_mesa/bin:/usr/bin:/bin:/usr/sbin:/sbin:$(brew --prefix llvm)/bin:/opt/homebrew/bin
# LLVM ne sert qu'aux outils de compilation (mesa_clc), pas au pilote. Partagé :
# en statique, mesa_clc et libLLVMSPIRVLib en auraient deux copies (plantage).
# Ces outils demandent aussi zstd de Homebrew.
export LIBRARY_PATH=$(brew --prefix)/lib
B=$E/build/mesa-kk
[[ -f $B/build.ninja ]] || meson setup $B $SRC --buildtype=release -Dplatforms=macos -Dvulkan-drivers=kosmickrisp \
    -Dgallium-drivers= -Dopengl=false -Dzstd=disabled -Dshared-llvm=enabled --prefer-static \
    -Dprefix=$B/install > $E/build/kosmickrisp.log 2>&1
ninja -C $B install >> $E/build/kosmickrisp.log 2>&1
rm -rf $OUT && mkdir -p $OUT
lib=($B/install/lib/libvulkan_kosmickrisp.dylib(N))
[[ -n ${lib:-} ]] || { echo "KosmicKrisp : bibliothèque absente, voir $E/build/kosmickrisp.log"; exit 1; }
cp $lib[1] $OUT/
install_name_tool -id @rpath/libvulkan_kosmickrisp.dylib $OUT/libvulkan_kosmickrisp.dylib
cp $SRC/docs/license.rst $OUT/
# Seule bibliothèque externe du pilote : SPIRV-Tools (Apache-2.0), embarquée à côté.
SPT=$(brew --prefix spirv-tools)
cp $SPT/lib/libSPIRV-Tools.dylib $OUT/ && chmod u+w $OUT/libSPIRV-Tools.dylib
install_name_tool -id @rpath/libSPIRV-Tools.dylib $OUT/libSPIRV-Tools.dylib
install_name_tool -change $(otool -L $OUT/libvulkan_kosmickrisp.dylib | awk '/libSPIRV-Tools/{print $1}') \
    @loader_path/libSPIRV-Tools.dylib $OUT/libvulkan_kosmickrisp.dylib
cp $SPT/LICENSE $OUT/SPIRV-Tools-LICENSE
codesign -f -s - $OUT/*.dylib
if otool -L $OUT/libvulkan_kosmickrisp.dylib | grep -E '/opt/homebrew|/usr/local|/opt/local'; then
    echo "KosmicKrisp : dépend encore de bibliothèques externes (ci-dessus)"; exit 1
fi
echo "KosmicKrisp ($TAG) : $OUT"
