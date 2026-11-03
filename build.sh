#!/usr/bin/env bash
# LineageOS 22.2 (Android 15) pour Galaxy J5 2017 européen (SM-J530F / j5y17lte).
# Prérequis : Ubuntu 22.04/24.04 x86_64, >= 300 Go libres, >= 16 Go RAM (32 conseillés).
#
# Usage : ./build.sh [dossier_sources]           (défaut : ~/android/lineage)
#   REGEN_BLOBS=1 ./build.sh   régénère vendor/samsung/j5y17lte depuis les dumps
#                              publics du firmware J530F (quelques Go en plus)
#   SKIP_SYNC=1  ./build.sh    recompile sans refaire repo sync
#   LOW_DISK=1   ./build.sh    économise ~80-100 Go : sources sans historique Git
#                              (--depth=1) et pas de cache ccache (~200-250 Go suffisent)
set -euo pipefail
KIT="$(cd "$(dirname "$0")" && pwd)"
SRC="${1:-$HOME/android/lineage}"
JOBS="$(nproc)"
step(){ printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

step "1/7 Dépendances système"
sudo apt-get update
sudo apt-get install -y bc bison build-essential ccache curl flex g++-multilib gcc-multilib \
  git git-lfs gnupg gperf imagemagick lib32readline-dev lib32z1-dev libelf-dev liblz4-tool \
  libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools \
  xsltproc zip zlib1g-dev python3 python-is-python3 patchelf
sudo apt-get install -y lib32ncurses5-dev libncurses5 libncurses5-dev 2>/dev/null \
  || echo "(libncurses5 absent sur cette version d'Ubuntu : ignoré)"

mkdir -p "$HOME/bin"; export PATH="$HOME/bin:$PATH"
if ! command -v repo >/dev/null; then
  curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o "$HOME/bin/repo"
  chmod a+x "$HOME/bin/repo"
fi
git config --global user.name  >/dev/null || git config --global user.name  "builder"
git config --global user.email >/dev/null || git config --global user.email "builder@localhost"
git config --global color.ui >/dev/null || git config --global color.ui auto   # évite la question de repo init

step "2/7 Sources LineageOS 22.2"
mkdir -p "$SRC" && cd "$SRC"
DEPTH=(); [ "${LOW_DISK:-0}" = 1 ] && DEPTH=(--depth=1)
[ -d .repo ] || repo init -u https://github.com/LineageOS/android.git -b lineage-22.2 --git-lfs --no-clone-bundle "${DEPTH[@]}"
mkdir -p .repo/local_manifests
cp "$KIT/local_manifests/j5y17lte.xml" .repo/local_manifests/

if [ "${SKIP_SYNC:-0}" != 1 ]; then
  step "3/7 Synchronisation (~100 Go, plusieurs heures)"
  repo sync -c -j"$JOBS" --force-sync --no-clone-bundle --no-tags --optimized-fetch --prune
fi

step "4/7 Portage de l'arbre j5y17lte vers 22.2 (patches/)"
DEV="$SRC/device/samsung/j5y17lte"
if git -C "$DEV" log --format=%s | grep -q "^j5y17lte: initial lineage-22.2$"; then
  echo "Patches déjà appliqués."
else
  git -C "$DEV" am --3way "$KIT"/patches/*.patch
fi

if [ "${REGEN_BLOBS:-0}" = 1 ]; then
  step "5/7 Régénération des blobs depuis les dumps J530F publics"
  ( cd "$DEV" && ./extract-files-j5y17lte.sh )
else
  step "5/7 Blobs : vendor/samsung/j5y17lte du dépôt communautaire (REGEN_BLOBS=1 pour régénérer)"
fi

if [ "${LOW_DISK:-0}" = 1 ]; then
  step "6/7 Cache de compilation : désactivé (LOW_DISK=1)"
  export USE_CCACHE=0
else
  step "6/7 Cache de compilation (50 Go)"
  export USE_CCACHE=1 CCACHE_EXEC="$(command -v ccache)"
  ccache -M 50G >/dev/null
fi

step "7/7 Compilation"
set +u
source build/envsetup.sh
breakfast j5y17lte userdebug
mka bacon -j"$JOBS"
set -u

step "Terminé"
ls -lh "$SRC"/out/target/product/j5y17lte/lineage-22.2-*-UNOFFICIAL-j5y17lte.zip
