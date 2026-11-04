#!/system/bin/sh
# Correctifs sur une ROM déjà installée, à lancer depuis TWRP via ADB :
#   adb push j5-hotfix.sh /tmp/
#   adb shell sh /tmp/j5-hotfix.sh
#
# 1. Bluetooth / NFC : le pilote Mali-T830 (libGLES_mali.so, propriétaire) met le
#    registre x18 à zéro quand zygote précharge OpenGL ; x18 est hérité par les
#    processus lancés ensuite et les bibliothèques compilées avec ShadowCallStack
#    (libbluetooth_jni, libnfc_nci_jni) plantent dès leur première instruction.
#    -> ro.zygote.disable_gl_preload=true
# 2. Wi-Fi : le pilote bcmdhd du noyau charge le calibrage depuis
#    /etc/wifi/nvram_net.txt (= /system/etc/wifi/nvram_net.txt), absent ;
#    la ROM fournit /vendor/etc/wifi/nvram.txt. -> copie au chemin attendu.
# 3. Wi-Fi : Android 15 démarre wpa_supplicant par son interface AIDL
#    (aidl/android.hardware.wifi.supplicant.ISupplicant/default), mais le
#    init.wifi.rc de la plateforme commune ne déclare que les anciennes
#    interfaces HIDL : le Wi-Fi s'allume sans jamais trouver de réseau.
#    -> service supplémentaire /vendor/etc/init/wpa_supplicant_aidl.rc
# 4. SIM : les builds sans le patch 0012 forcent tous les J530F en double SIM ;
#    sur un J530F mono-SIM le modem et le RIL sont alors mal configurés et la
#    carte n'est jamais détectée. Le vrai nombre d'emplacements est écrit à
#    l'usine dans /efs/factory.prop (lu ici en LECTURE SEULE).
#    -> ro.vendor.j5.simslotcount dans /vendor/build.prop et, si mono-SIM,
#       règle /vendor/etc/init/zz_j5y17lte_single_sim.rc

BLK=/dev/block/platform/13540000.dwmmc0/by-name
SYS=${SYS:-/mnt/j5sys}
VEN=${VEN:-/mnt/j5ven}
EFS=${EFS:-/mnt/j5efs}
PROP=ro.zygote.disable_gl_preload=true

if [ -z "$SKIP_MOUNT" ]; then
  umount /system_root 2>/dev/null; umount /system 2>/dev/null; umount /vendor 2>/dev/null
  umount "$SYS" 2>/dev/null; umount "$VEN" 2>/dev/null
  mkdir -p "$SYS" "$VEN"
  mount -t ext4 -o rw "$BLK/SYSTEM" "$SYS" || { echo "ERREUR : montage de SYSTEM impossible"; exit 1; }
  mount -t ext4 -o rw "$BLK/VENDOR" "$VEN" || { echo "ERREUR : montage de VENDOR impossible"; umount "$SYS"; exit 1; }
  umount "$EFS" 2>/dev/null; mkdir -p "$EFS"
  mount -t ext4 -o ro "$BLK/EFS" "$EFS" || echo "ATTENTION : EFS non lisible, étape SIM ignorée"
fi

fail() { echo "ERREUR : $1"; [ -z "$SKIP_MOUNT" ] && { umount "$SYS"; umount "$VEN"; umount "$EFS" 2>/dev/null; }; exit 1; }

BP="$SYS/system/build.prop"
[ -f "$BP" ] || fail "$BP introuvable"
NV="$VEN/etc/wifi/nvram.txt"
[ -f "$NV" ] || fail "$NV introuvable"

# 1. Propriété zygote (une seule fois)
sed -i '/^ro\.zygote\.disable_gl_preload=/d' "$BP"
echo "$PROP" >> "$BP"
echo "OK : $PROP"

# 2. Calibrage Wi-Fi au chemin attendu par le noyau
mkdir -p "$SYS/system/etc/wifi"
cp "$NV" "$SYS/system/etc/wifi/nvram_net.txt" || fail "copie de nvram.txt impossible"
chmod 0644 "$SYS/system/etc/wifi/nvram_net.txt"
chcon u:object_r:system_file:s0 "$SYS/system/etc/wifi" "$SYS/system/etc/wifi/nvram_net.txt" 2>/dev/null
echo "OK : nvram.txt copié en /system/etc/wifi/nvram_net.txt"

# 3. Service wpa_supplicant déclaré en AIDL
RC="$VEN/etc/init/wpa_supplicant_aidl.rc"
mkdir -p "$VEN/etc/init"
cat > "$RC" <<'EOF'
# Android 15 starts the supplicant through its AIDL interface; the common
# init.wifi.rc only declares the legacy HIDL ones.
service vendor.wpa_supplicant_aidl /vendor/bin/hw/wpa_supplicant \
    -O/data/vendor/wifi/wpa/sockets -puse_p2p_group_interface=1 \
    -g@android:wpa_wlan0
    interface aidl android.hardware.wifi.supplicant.ISupplicant/default
    socket wpa_wlan0 dgram 660 wifi wifi
    class main
    disabled
    oneshot
EOF
chmod 0644 "$RC"
chcon u:object_r:vendor_configs_file:s0 "$RC" 2>/dev/null
echo "OK : service wpa_supplicant AIDL ajouté ($RC)"

# 4. Nombre d'emplacements SIM (même lecture que cbd : 1er chiffre après le 1er '=')
SIMS=""
[ -f "$EFS/factory.prop" ] && SIMS=$(head -c 256 "$EFS/factory.prop" | tr '\n' ' ' | sed -n 's/^[^=]*=\([0-9]\).*/\1/p')
SRC="$VEN/etc/init/zz_j5y17lte_single_sim.rc"
VBP="$VEN/build.prop"
if [ "$SIMS" = 1 ] || [ "$SIMS" = 2 ]; then
  [ -f "$VBP" ] && { sed -i '/^ro\.vendor\.j5\.simslotcount=/d' "$VBP"; echo "ro.vendor.j5.simslotcount=$SIMS" >> "$VBP"; }
fi
if [ "$SIMS" = 1 ]; then
  cat > "$SRC" <<'EOF'
# Single-SIM SM-J530F on a build whose init forces two SIM slots
# (installed by tools/j5-hotfix.sh after reading /efs/factory.prop).
# Runs after the common rules on the same triggers (parsed later).
on property:ro.vendor.multisim.simslotcount=*
    write /sys/module/modem_ctrl_ss310ap/parameters/ds_detect 1
    setprop persist.radio.multisim.config ss

on property:ro.multisim.simslotcount=*
    setprop persist.radio.multisim.config ss

on property:init.svc.ril-daemon1=running
    stop ril-daemon1
EOF
  chmod 0644 "$SRC"
  chcon u:object_r:vendor_configs_file:s0 "$SRC" 2>/dev/null
  echo "OK : téléphone mono-SIM (factory.prop) -> configuration mono-SIM installée"
elif [ "$SIMS" = 2 ]; then
  rm -f "$SRC"
  echo "OK : téléphone double SIM (factory.prop) -> configuration double SIM conservée"
else
  echo "ATTENTION : nombre de SIM introuvable dans /efs/factory.prop, étape SIM ignorée"
fi

grep -n '^ro\.zygote\.disable_gl_preload=' "$BP"
ls -l "$SYS/system/etc/wifi/nvram_net.txt"
sync
[ -z "$SKIP_MOUNT" ] && { umount "$SYS"; umount "$VEN"; umount "$EFS" 2>/dev/null; }
exit 0
