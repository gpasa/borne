#!/bin/zsh
# Compile GZDoom 4.14.2 et Raze 1.11.0, universels, avec le correctif
# engines/patches/zdoom-cocoa-cursor-warp.patch : sans lui, ces moteurs
# replacent le pointeur par un événement simulé, et macOS demande l'accès
# d'accessibilité au nom de Borne. Outillage officiel des builds macOS :
# github.com/ZDoom/zdoom-macos-deps (dépendances précompilées, apps autonomes),
# MoltenVK lié en statique comme dans les builds officiels (en bibliothèque à
# part, le moteur ne la trouve pas et retombe sur OpenGL).
#   scripts/build_zdoom_ports.sh [gzdoom|raze]   # les deux par défaut
# Résultat : ../Engines/build/zdoom-ports/{GZDoom.app,Raze.app}
set -euo pipefail
BORNE=${0:A:h:h}
E=${ENGINES_DIR:-$BORNE/../Engines}
D=$E/downloads
OUT=$E/build/zdoom-ports
PATCH=$BORNE/engines/patches/zdoom-cocoa-cursor-warp.patch
PY=$(brew --prefix)/bin/python3.13
mkdir -p $OUT

[[ -d $D/zdoom-macos-deps/core/aedi ]] || {
    git clone -q --depth 1 https://github.com/ZDoom/zdoom-macos-deps.git $D/zdoom-macos-deps
    git -C $D/zdoom-macos-deps submodule update --init --depth 1 -q
}

port() {  # port <nom> <dépôt> <étiquette> <dossier source> <app>
    local name=$1 repo=$2 tag=$3 srcdir=$4 app=$5
    local src=$D/$name-$tag
    [[ -d $src ]] || git clone -q --depth 1 --branch $tag https://github.com/ZDoom/$repo.git $src
    local mm=$src/$srcdir/common/platform/posix/cocoa/i_input.mm
    grep -q CGWarpMouseCursorPosition $mm || patch -s $mm < $PATCH
    [[ -d $OUT/$app ]] && { echo "$app déjà compilé"; return; }
    local work=$E/build/zdoom-$name
    $PY $D/zdoom-macos-deps/build.py --static-moltenvk --source $src --build-path $work/build \
        --output-path $work/output --temp-path $work/temp > $E/build/zdoom-$name.log 2>&1
    local built=($work/output/**/$app(N))
    [[ -n ${built:-} ]] || { echo "$name : échec, voir $E/build/zdoom-$name.log"; exit 1; }
    ditto $built[1] $OUT/$app
    echo "$app : $(lipo -archs $OUT/$app/Contents/MacOS/*(.x[1]))"
}

[[ ${1:-gzdoom} == gzdoom || -z ${1:-} ]] && port gzdoom gzdoom g4.14.2 src GZDoom.app
[[ ${1:-raze} == raze ]] && port raze Raze 1.11.0 source Raze.app
exit 0
