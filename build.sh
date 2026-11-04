#!/usr/bin/env bash
# LineageOS 22.2 (Android 15) pour Galaxy J5 2017 européen (SM-J530F / j5y17lte).
# Prérequis : Ubuntu 22.04/24.04 ou Debian 12/13 x86_64, >= 300 Go libres, >= 16 Go RAM (32 conseillés).
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
# Indispensables : noms valables sur Ubuntu 22.04/24.04 et Debian 12/13.
REQUIRED=(bc bison build-essential ccache curl flex git git-lfs gnupg gperf libelf-dev
  libssl-dev libxml2-utils lz4 lzop python3 rsync squashfs-tools unzip xsltproc zip
  zlib1g-dev patchelf)
# Utiles mais pas bloquants : installés un par un, ignorés s'ils n'existent pas.
OPTIONAL=(python-is-python3 gcc-multilib g++-multilib lib32readline-dev lib32z1-dev
  imagemagick pngcrush schedtool libsdl1.2-dev lib32ncurses5-dev libncurses5 libncurses5-dev)
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y "${REQUIRED[@]}"
for p in "${OPTIONAL[@]}"; do
  sudo apt-get install -y "$p" >/dev/null 2>&1 || echo "  (paquet facultatif $p indisponible : ignoré)"
done
# Certains scripts appellent « python » : on le crée s'il manque.
command -v python >/dev/null || { mkdir -p "$HOME/bin"; ln -sf "$(command -v python3)" "$HOME/bin/python"; }

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

step "4/7 Portage vers 22.2 (patches/ + calibration audio TFA9890)"
DEV="$SRC/device/samsung/j5y17lte"
# Applique chaque patch d'un dossier qui ne l'est pas encore (comparaison sur
# le titre du commit). $1 = dossier de patchs, $2 = dépôt cible.
apply_patches() {
  local dir="$1" repo="$2" p subj
  ls "$dir"/*.patch >/dev/null 2>&1 || return 0
  echo "  -> ${repo#$SRC/}"
  for p in "$dir"/*.patch; do
    subj="$(sed -n 's/^Subject: \[PATCH[^]]*\] //p' "$p" | head -1 | cut -c1-45)"
    if git -C "$repo" log --format=%s | grep -qF -- "$subj"; then
      echo "     déjà appliqué : $(basename "$p")"
    else
      echo "     application   : $(basename "$p")"
      git -C "$repo" am --3way "$p"
    fi
  done
}
apply_patches "$KIT/patches"             "$DEV"
apply_patches "$KIT/patches/exynos7870"  "$SRC/hardware/samsung_slsi-linaro/exynos7870"
apply_patches "$KIT/patches/slsi-exynos" "$SRC/hardware/samsung_slsi-linaro/exynos"

# Calibration de l'ampli audio TFA9890 du J5 : le dépôt vendor commun ne contient
# que Tfa9896.cnt (A3 2017). On la récupère du dump public du firmware officiel
# J530FXXS8CUE4 (commit figé) et on vérifie son empreinte.
TFA="$SRC/vendor/samsung/universal7870-common/audio/sec_tfa/proprietary/vendor/etc/Tfa9890.cnt"
TFA_URL="https://raw.githubusercontent.com/Exynos7870-labs/samsung_j5y17lte_dump/73ad4c2db861d352333854510c958f25e18002fb/system/vendor/etc/Tfa9890.cnt"
TFA_SHA256="de2810e0398b38213d386308a2c42f810059a0dd09803abe40cdd73305c3842e"
if echo "$TFA_SHA256  $TFA" | sha256sum -c --status 2>/dev/null; then
  echo "  déjà présent  : Tfa9890.cnt"
else
  echo "  téléchargement : Tfa9890.cnt (calibration de l'ampli audio)"
  mkdir -p "$(dirname "$TFA")"
  curl -fsSL -o "$TFA.tmp" "$TFA_URL"
  if ! echo "$TFA_SHA256  $TFA.tmp" | sha256sum -c --status; then
    rm -f "$TFA.tmp"; echo "ERREUR : empreinte de Tfa9890.cnt incorrecte"; exit 1
  fi
  mv "$TFA.tmp" "$TFA"
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
