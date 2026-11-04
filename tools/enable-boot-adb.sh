#!/system/bin/sh
# Diagnostic du premier démarrage : à lancer depuis TWRP, via ADB.
#   adb push enable-boot-adb.sh /tmp/
#   adb shell sh /tmp/enable-boot-adb.sh        (active)
#   adb shell sh /tmp/enable-boot-adb.sh off    (désactive)
#
# Active ADB dès le démarrage, sans demande d'autorisation, et l'enregistrement
# du journal Android (logcat) dans /data/misc/logd, lisible ensuite depuis TWRP.
# Ne modifie que build.prop dans la partition SYSTEM.

SYS_DEV=/dev/block/platform/13540000.dwmmc0/by-name/SYSTEM
MNT=${MNT:-/mnt/j5sys}
TAG="# --- diagnostic (enable-boot-adb.sh) ---"

if [ -z "$SKIP_MOUNT" ]; then
  umount /system_root 2>/dev/null; umount /system 2>/dev/null; umount "$MNT" 2>/dev/null
  mkdir -p "$MNT"
  mount -t ext4 -o rw "$SYS_DEV" "$MNT" || { echo "ERREUR : impossible de monter SYSTEM en écriture"; exit 1; }
fi

MAIN="$MNT/system/build.prop"
[ -f "$MAIN" ] || { echo "ERREUR : $MAIN introuvable"; [ -z "$SKIP_MOUNT" ] && umount "$MNT"; exit 1; }

# On retire toute définition existante de ces propriétés (et un ancien bloc de diagnostic).
for f in "$MNT/system/build.prop" "$MNT/system/product/etc/build.prop" \
         "$MNT/system/system_ext/etc/build.prop"; do
  [ -f "$f" ] || continue
  sed -i -e '/^ro\.adb\.secure=/d' -e '/^persist\.sys\.usb\.config=/d' \
         -e '/^persist\.logd\.logpersistd=/d' -e "/^$TAG\$/d" "$f"
done

if [ "$1" != "off" ]; then
  {
    echo "$TAG"
    echo "ro.adb.secure=0"
    echo "persist.sys.usb.config=mtp,adb"
    echo "persist.logd.logpersistd=logcatd"
  } >> "$MAIN"
  echo "OK : ADB au démarrage + journal persistant ACTIVÉS"
else
  echo "ro.adb.secure=1" >> "$MAIN"
  echo "OK : diagnostic DÉSACTIVÉ"
fi

grep -n -E '^(ro\.adb\.secure|persist\.sys\.usb\.config|persist\.logd\.logpersistd)=' "$MAIN"
sync
[ -z "$SKIP_MOUNT" ] && umount "$MNT"
exit 0
