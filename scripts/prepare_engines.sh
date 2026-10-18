#!/bin/zsh
# Prépare les moteurs de jeux PC embarqués par Borne, pour arm64 et x86_64,
# dans ../Engines/payload/<arch>/ (build_app.sh les y prend).
#
#   Doom        UZDoom 5.0.3 (Apple silicon), GZDoom 4.14.2 (Intel) — versions officielles
#   Wolfenstein ECWolf 1.4.2 — version officielle, universelle, amincie
#   Quake       vkQuake 1.37.0 — compilé ici, corrigé (engines/patches) pour passer
#               par le chargeur Vulkan ; pilotes MoltenVK et, s'il est là, KosmicKrisp
#   (Freedoom se télécharge depuis Borne, sur demande.)
#
# Les téléchargements sont refaits seulement s'ils manquent.
set -euo pipefail
BORNE=${0:A:h:h}
E=${ENGINES_DIR:-$BORNE/../Engines}
D=$E/downloads
mkdir -p $D $E/deps $E/build $E/payload

fetch() {  # fetch <dossier> <commande…>
    local dir=$1; shift
    mkdir -p $D/$dir
    [[ -n "$(ls -A $D/$dir 2>/dev/null)" ]] || (cd $D/$dir && "$@")
}
fetch uzdoom   gh release download 5.0.3 -R UZDoom/UZDoom -p 'MacOS-UZDoom-Release-ARM64.dmg'
fetch gzdoom   gh release download g4.14.2 -R ZDoom/gzdoom -p 'gzdoom-4-14-2-macos.zip'
fetch moltenvk gh release download v1.4.2 -R KhronosGroup/MoltenVK -p 'MoltenVK-macos.tar'
# UZDoom (ZVulkan) affiche en vert avec MoltenVK >= 1.2.7 (vérifié par dichotomie, 1.2.6
# correct) ; GZDoom 4.14.2 officiel embarque d'ailleurs la 1.2.6.
fetch moltenvk-1.2.6 gh release download v1.2.6 -R KhronosGroup/MoltenVK -p 'MoltenVK-macos.tar'
fetch ecwolf   zsh -c 'curl -sfLO https://maniacsvault.net/ecwolf/files/ecwolf/1.x/ecwolf-1.4.2.dmg'
[[ -d $D/vkquake/src ]] || git clone -q --depth 1 --branch 1.37.0 https://github.com/Novum/vkQuake.git $D/vkquake/src
[[ -d $D/vulkan-loader ]] || git clone -q --depth 1 --branch vulkan-sdk-1.4.357 https://github.com/KhronosGroup/Vulkan-Loader.git $D/vulkan-loader
[[ -d $D/vulkan-headers ]] || git clone -q --depth 1 --branch vulkan-sdk-1.4.357 https://github.com/KhronosGroup/Vulkan-Headers.git $D/vulkan-headers

# Apps officielles hors de leurs images disque.
X=$E/x
mkdir -p $X
for dmg in $D/uzdoom/*.dmg $D/ecwolf/*.dmg; do
    app=$(basename ${dmg%.dmg})
    [[ -d $X/UZDoom.app && $dmg == *UZDoom* ]] && continue
    [[ -d $X/ECWolf.app && $dmg == *ecwolf* ]] && continue
    m=$(mktemp -d)
    hdiutil attach -readonly -nobrowse -mountpoint $m $dmg -quiet
    cp -R $m/*.app $X/
    hdiutil detach $m -quiet
done
[[ -d $X/GZDoom.app ]] || unzip -q -o $D/gzdoom/*.zip 'GZDoom.app/*' -d $X

# MoltenVK, Freedoom.
[[ -d $E/deps/MoltenVK ]] || tar -xf $D/moltenvk/MoltenVK-macos.tar -C $E/deps
[[ -d $E/deps/MoltenVK-1.2.6/MoltenVK ]] || { mkdir -p $E/deps/MoltenVK-1.2.6 && tar -xf $D/moltenvk-1.2.6/MoltenVK-macos.tar -C $E/deps/MoltenVK-1.2.6; }
MVK126=$E/deps/MoltenVK-1.2.6/MoltenVK/MoltenVK/dylib/macOS/libMoltenVK.dylib
MVK=$E/deps/MoltenVK/MoltenVK/dynamic/dylib/macOS

# Chargeur Vulkan universel.
if [[ ! -f $E/deps/vulkan/lib/libvulkan.1.dylib ]]; then
    cmake -S $D/vulkan-headers -B $E/build/vulkan-headers -DCMAKE_INSTALL_PREFIX=$E/deps/vulkan >/dev/null
    cmake --install $E/build/vulkan-headers >/dev/null
    cmake -S $D/vulkan-loader -B $E/build/vulkan-loader -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
        -DVULKAN_HEADERS_INSTALL_DIR=$E/deps/vulkan -DCMAKE_INSTALL_PREFIX=$E/deps/vulkan -DBUILD_TESTS=OFF >/dev/null
    cmake --build $E/build/vulkan-loader -j$(sysctl -n hw.ncpu) >/dev/null
    cmake --install $E/build/vulkan-loader >/dev/null
fi

# vkQuake corrigé, une compilation par architecture (x86_64 en compilation croisée).
(cd $D/vkquake/src && { git apply --check $BORNE/engines/patches/vkquake-1.37.0-borne.patch 2>/dev/null \
    && git apply $BORNE/engines/patches/vkquake-1.37.0-borne.patch || true; })
mkdir -p $E/deps/pkgconfig
cat > $E/deps/pkgconfig/sdl3.pc <<EOF
prefix=/Library/Frameworks/SDL3.xcframework/macos-arm64_x86_64
Name: sdl3
Description: SDL3 framework
Version: 3.2.28
Cflags: -F\${prefix}
Libs: -F\${prefix} -framework SDL3
EOF
for arch in arm64 x86_64; do
    out=$E/build/vkquake-$arch
    if [[ ! -x $out/vkquake ]]; then
        cross=()
        if [[ $arch != $(uname -m) ]]; then
            cat > $E/build/cross-$arch.ini <<EOF
[binaries]
c = 'clang'
objc = 'clang'
ar = 'ar'
strip = 'strip'
pkg-config = 'pkg-config'
[built-in options]
c_args = ['-arch', '$arch']
c_link_args = ['-arch', '$arch']
[host_machine]
system = 'darwin'
cpu_family = '$([[ $arch == x86_64 ]] && echo x86_64 || echo aarch64)'
cpu = '$arch'
endian = 'little'
EOF
            cross=(--cross-file $E/build/cross-$arch.ini)
        fi
        rm -rf $out
        (cd $D/vkquake/src && PKG_CONFIG_PATH=$E/deps/pkgconfig meson setup $out $cross --buildtype=release \
            -Ddo_userdirs=enabled -Duse_sdl3=enabled -Duse_codec_mp3=disabled -Duse_codec_flac=disabled \
            -Duse_codec_vorbis=disabled -Duse_codec_opus=disabled \
            -Dc_args="-arch $arch -mmacosx-version-min=14.0 -I$E/deps/vulkan/include" \
            -Dc_link_args="-arch $arch -mmacosx-version-min=14.0 -L$E/deps/vulkan/lib -Wl,-rpath,@executable_path/../Frameworks" >/dev/null)
        ninja -C $out >/dev/null
    fi
done

# KosmicKrisp (Apple silicon, macOS 26) : pris dans le Vulkan SDK de LunarG s'il est installé.
kk=(~/VulkanSDK/*/macOS/lib/libvulkan_kosmickrisp.dylib(N))
KK=${kk[-1]:-}

# Charge utile par architecture.
for arch in arm64 x86_64; do
    P=$E/payload/$arch
    rm -rf $P && mkdir -p $P/Engines $P/MacOS $P/Frameworks $P/vulkan
    if [[ $arch == arm64 ]]; then
        ditto $X/UZDoom.app $P/Engines/UZDoom.app
        lipo -thin arm64 $MVK126 -output $P/Engines/UZDoom.app/Contents/Frameworks/libMoltenVK.dylib
    else
        ditto --arch x86_64 $X/GZDoom.app $P/Engines/GZDoom.app
    fi
    ditto --arch $arch $X/ECWolf.app $P/Engines/ECWolf.app
    cp $E/build/vkquake-$arch/vkquake $P/MacOS/vkquake
    strip -x $P/MacOS/vkquake
    lipo -thin $arch $E/deps/vulkan/lib/libvulkan.1.dylib -output $P/Frameworks/libvulkan.1.dylib
    lipo -thin $arch $MVK/libMoltenVK.dylib -output $P/Frameworks/libMoltenVK.dylib
    # Les manifestes de pilotes pointent vers Contents/Frameworks.
    cat > $P/vulkan/MoltenVK_icd.json <<'EOF'
{ "file_format_version": "1.0.0",
  "ICD": { "library_path": "../../Frameworks/libMoltenVK.dylib", "api_version": "1.4.0", "is_portability_driver": true } }
EOF
    if [[ $arch == arm64 && -n $KK ]]; then
        cp $KK $P/Frameworks/libvulkan_kosmickrisp.dylib
        cat > $P/vulkan/kosmickrisp_icd.json <<'EOF'
{ "file_format_version": "1.0.1",
  "ICD": { "library_path": "../../Frameworks/libvulkan_kosmickrisp.dylib", "api_version": "1.4.0" } }
EOF
    fi
    # Licences des moteurs (UZDoom garde les siennes dans son app : licenses.zip).
    L=$P/licenses
    mkdir -p $L/vkQuake $L/Vulkan-Loader $L/MoltenVK $L/ECWolf
    cp $D/vkquake/src/LICENSE.txt $L/vkQuake/
    cp $BORNE/engines/patches/vkquake-1.37.0-borne.patch $L/vkQuake/
    cp $D/vulkan-loader/LICENSE.txt $L/Vulkan-Loader/
    cp $E/deps/MoltenVK/LICENSE $L/MoltenVK/
    if [[ ! -d $D/ecwolf/src ]]; then
        mkdir -p $D/ecwolf/src
        curl -sfL https://maniacsvault.net/ecwolf/files/ecwolf/1.x/ecwolf-1.4.2-src.tar.xz | tar -xJ -C $D/ecwolf/src --strip-components=1
    fi
    cp $D/ecwolf/src/docs/{copyright,license-gpl.txt,license-id.txt,license-mame.txt} $L/ECWolf/
    [[ $arch == x86_64 ]] && ditto $X/Licenses $L/GZDoom
    echo "Moteurs ($arch) : $(du -sh $P | cut -f1)$([[ $arch == arm64 && -n $KK ]] && echo ', KosmicKrisp inclus')"
done
