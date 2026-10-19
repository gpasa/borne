#!/bin/zsh
# Compile iortcw (Return to Castle Wolfenstein, solo) pour arm64 et x86_64.
# zlib et FreeType internes ne compilent plus avec le SDK de macOS 26 : zlib du
# système (PATH sans MacPorts/Homebrew pour ne pas lier leur libz), sans FreeType.
# Résultat : ../Engines/build/iortcw-<arch>/iowolfsp.app
set -euo pipefail
BORNE=${0:A:h:h}
E=${ENGINES_DIR:-$BORNE/../Engines}
SRC=$E/downloads/iortcw
[[ -d $SRC ]] || git clone -q --depth 1 https://github.com/iortcw/iortcw.git $SRC
for arch in arm64 x86_64; do
    out=$E/build/iortcw-$arch
    [[ -d $out/iowolfsp.app ]] && continue
    (cd $SRC/SP && rm -rf build/release-darwin-$arch && \
        env PATH=/usr/bin:/bin:/usr/sbin:/sbin USE_INTERNAL_ZLIB=0 USE_FREETYPE=0 ./make-macosx.sh $arch > $E/build/iortcw-$arch.log 2>&1)
    rm -rf $out && mkdir -p $out
    ditto $SRC/SP/build/release-darwin-$arch/iowolfsp.app $out/iowolfsp.app
    echo "iortcw ($arch) : $out/iowolfsp.app"
done
