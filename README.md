# LineageOS 22.2 (Android 15) — Galaxy J5 2017 européen

| | |
|---|---|
| Modèle | **SM-J530F** (aussi J530FM, J530G, J530GM) |
| Nom de code | `j5y17lte` |
| SoC | Exynos 7870 · noyau Linux 3.18 · 2 Go RAM · Wi-Fi/BT Broadcom |
| Statut | **Non officiel. Compile et démarre sur un SM-J530F (4 nov. 2026)** ; Wi-Fi, Bluetooth, NFC vérifiés, reste du matériel en cours de test |

## D'où vient ce kit

La communauté [samsungexynos7870](https://github.com/samsungexynos7870) maintient
une pile LineageOS 22.2 complète pour l'Exynos 7870 (plateforme commune, noyau
avec eBPF rétroporté, HAL, blobs). Elle publie des builds 22.2 pour l'**A3 2017**,
mais l'arbre du **J5 2017** n'existe qu'en `lineage-20`.

Ce kit fige cet arbre `lineage-20` (commit `52defb3`, 4 oct. 2026, déjà
modernisé pour la plateforme commune 22.2) et y applique 12 patchs (les 7
premiers reproduisent les changements faits sur l'A3 pour passer en 22.2) :

| Patch | Changement |
|---|---|
| 0001 | Tolérances de build clang, `AB_OTA_UPDATER := false`, nom du contrôleur USB (`13600000.dwc3`) |
| 0002 | Bibliothèque init déclarée via `soong_config_set` (nouvelle méthode Android 15) |
| 0003 | Wi-Fi : HAL AIDL `android.hardware.wifi-service-legacy` (remplace le HIDL 1.0) |
| 0004 | NFC : retrait de `NfcNci`, fourni par l'APEX nfcservices sur Android 15 |
| 0005 | Manifeste VINTF : FCM 3 → 5, retrait DRM clearkey/default et SehNfc, ajout soundtrigger 2.2 |
| 0006 | SELinux : étiquettes du shim `libbauthserver` (empreinte) et du HAL NFC |
| 0007 | init : `ro.multisim.simslotcount`, détection J530GM corrigée (avant J530G), log corrigé |
| 0008 | Bluetooth Broadcom : `libbt-vendor` configuré via Soong (`brcm_libbt`), obligatoire depuis LineageOS 22.2 |
| 0009 | SELinux : retrait de l'étiquette privée `/cpefs`, en conflit avec celle de la plateforme commune 22.2 |
| 0010 | `ro.zygote.disable_gl_preload=true` : le pilote Mali efface le registre x18 (ShadowCallStack) et faisait planter Bluetooth et NFC au démarrage |
| 0011 | Wi-Fi : service `wpa_supplicant` déclaré en AIDL (Android 15) et calibrage `nvram` installé là où le pilote `bcmdhd` le cherche |
| 0012 | SIM : le J530F démarre en mono-SIM par défaut (le forcer en double SIM empêchait toute détection de la carte) ; `ro.vendor.j5.simslotcount=2` dans `/vendor/build.prop` pour un J530F/DS |

Ce qui a été **vérifié** : les 12 dépôts et branches existent, les patchs
s'appliquent sans conflit, la config noyau `exynos7870-j5y17lte_defconfig`
est présente dans la branche noyau 22.2, et toutes les options attendues par la
plateforme commune sont définies par le J5 (seules différences avec l'A3 :
ampli TFA9890 au lieu de 9896, pas de radio FM).

**Noyau compilé avec succès** (test du 3 nov. 2026) : branche `lineage-22.2`
au commit `1606da29`, `exynos7870-j5y17lte_defconfig`, GCC 4.9 de LineageOS
(comme le fait `build.sh`). Résultat : Linux 3.18.140 arm64 (`Image` 19,7 Mo)
et 6 DTB `exynos7870-j5y17lte_eur_open_00…07` (révisions de carte du modèle
européen), sans erreur. Les options eBPF requises par Android 15 sont
activées : `BPF_SYSCALL`, `CGROUP_BPF`, `BPF_JIT`, `NETFILTER_XT_MATCH_BPF`,
`NET_CLS_BPF`, `NET_ACT_BPF`.

**ROM complète compilée avec succès** (4 nov. 2026, Google Cloud, Debian 12,
`LOW_DISK=1`) : `lineage-22.2-20261104-UNOFFICIAL-j5y17lte.zip`, 894 Mo.

**Démarrage réussi sur un vrai SM-J530F** (4 nov. 2026), bootloader et modem
d'origine Android 7 (`J530FXXU1AQI3`), avec MindTheGapps 15.

**Vérifié sur le téléphone** : démarrage, Wi-Fi, Bluetooth, NFC (après les
patchs 0010 et 0011, ou `tools/j5-hotfix.sh` sur une ROM déjà installée).

Ce qui **n'a pas encore** été vérifié : réseau mobile, caméra, audio, GPS,
empreinte, capteurs.

## Contenu

| Fichier | Rôle |
|---|---|
| `local_manifests/j5y17lte.xml` | Les 12 dépôts à ajouter aux sources LineageOS 22.2 |
| `patches/0001…0012` | Le portage de l'arbre j5y17lte vers 22.2 |
| `build.sh` | Tout de A à Z : paquets → `repo sync` → patchs → `mka bacon` |
| `GUIDE-GOOGLE-CLOUD.md` | Compiler gratuitement sur un serveur Google Cloud (crédit d'essai) |
| `tools/j5-hotfix.sh` | Depuis TWRP, sur une ROM déjà installée : correctifs Bluetooth/NFC (x18), Wi-Fi (supplicant AIDL, `nvram`) et SIM (nombre d'emplacements lu dans `/efs/factory.prop`, en lecture seule) |
| `tools/enable-boot-adb.sh` | Diagnostic du premier démarrage depuis TWRP : ADB sans autorisation + journal persistant (`off` pour désactiver) |

## Machine nécessaire

- Linux x86_64 (Ubuntu 22.04 ou 24.04)
- **300 Go** libres sur SSD
- **16 Go de RAM au minimum** (32 conseillés ; sinon ajoutez 16 Go de swap)
- Première compilation : 3 à 10 h selon le processeur

## Compiler

> Pas assez de place sur ton PC ? Compile gratuitement sur un serveur
> Google Cloud : **[GUIDE-GOOGLE-CLOUD.md](GUIDE-GOOGLE-CLOUD.md)**.

```bash
./build.sh
```

Mode économe (~200-250 Go au lieu de ~300 Go : sources sans historique Git,
pas de cache de compilation) :

```bash
LOW_DISK=1 ./build.sh
```

Résultat : `~/android/lineage/out/target/product/j5y17lte/lineage-22.2-AAAAMMJJ-UNOFFICIAL-j5y17lte.zip`

Recompiler sans tout resynchroniser :

```bash
SKIP_SYNC=1 ./build.sh
```

Si la compilation échoue sur des blobs manquants, régénérez-les depuis les dumps
publics du firmware J530F (aucun téléphone requis) :

```bash
SKIP_SYNC=1 REGEN_BLOBS=1 ./build.sh
```

## Erreurs possibles et pistes

| Symptôme | Piste |
|---|---|
| Fichier manquant sous `vendor/samsung/j5y17lte` | `REGEN_BLOBS=1` (voir ci-dessus) |
| `checkfc` : spec en double dans `file_contexts` | Retirer la ligne en double de `device/samsung/j5y17lte/sepolicy/vendor/file_contexts` |
| Erreur VINTF sur un HAL | Comparer `configs/manifest.xml` avec celui de l'A3 22.2 (`android_device_samsung_a3y17lte`, branche `lineage-22.2`) |
| `git am` échoue | La branche a été resynchronisée : `git -C device/samsung/j5y17lte am --abort`, puis relancer |

L'arbre de l'A3 2017 en 22.2 est la meilleure référence : même SoC, même
plateforme commune, et ses builds tournent.

## Installer sur le téléphone

> ⚠️ Tout le contenu du téléphone sera effacé. Knox sera grillé définitivement.
> À vos risques. Gardez le firmware Samsung d'origine complet du SM-J530F
> (BL/AP/CP/CSC) : flashé avec Odin, CSC compris, il remet les partitions
> d'origine en cas de problème.

Procédure réellement utilisée sur un SM-J530F, sans carte SD, tout par ADB
depuis un PC Windows ([SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools)).
Les commandes `adb` se tapent dans `cmd`, dans le dossier de platform-tools.

### 1. TWRP communautaire

1. *Options de développement → Déverrouillage OEM*.
2. Flashez le TWRP communautaire **3.7.1_12-0** pour j5y17lte avec Odin, case
   **AP**, « Auto Reboot » décoché :
   <https://github.com/samsungexynos7870/android_device_samsung_j5y17lte/releases/download/3.7.1_12-0/recovery.img.tar>
3. Démarrez directement dedans : Vol- + Power pour éteindre, puis tout de suite
   **Vol+ + Home + Power**.

### 2. Sauvegarde EFS (IMEI) — fortement conseillée

TWRP ne propose pas EFS dans sa liste et la mémoire interne est illisible
(0 Mo) tant qu'elle n'est pas formatée : on copie les partitions vers le PC.

```
adb shell dd if=/dev/block/platform/13540000.dwmmc0/by-name/EFS of=/tmp/efs.img
adb shell dd if=/dev/block/platform/13540000.dwmmc0/by-name/CPEFS of=/tmp/cpefs.img
adb pull /tmp/efs.img
adb pull /tmp/cpefs.img
```

### 3. Partitions VENDOR et MISC

La plateforme 22.2 a besoin d'une partition `VENDOR` et d'une partition `MISC`,
absentes du firmware Samsung. On utilise le script de la communauté
[`repartition-add-misc-and-vendor-lineage-22-2.zip`](https://github.com/Exynos7870-labs/universal_repartition_script7870/releases/download/lineage-22.2/repartition-add-misc-and-vendor-lineage-22-2.zip)
(SHA-256 `5e9cfdb9179961c3d517674bdd36c73c7949f7cea8a5c5c2f3eb33516a164edc`).

**Ne pas le flasher tel quel** : son programme d'installation est trop ancien
pour ce TWRP (« Error 7 », appareil « non compatible ») et son script cherche
`sgdisk` dans `/sbin` alors que ce TWRP l'a dans `/system/bin`. On lance donc le
script directement :

1. Extrayez `repartition.sh` du zip (clic droit → Extraire tout) dans le
   dossier de platform-tools.
2. Vérifiez la table actuelle (gardez une copie du résultat) :

```
adb shell /system/bin/sgdisk --print /dev/block/mmcblk0
```

3. Lancez le script :

```
adb push repartition.sh /tmp/repartition.sh
adb shell "sed -i 's#^SGDISK=.*#SGDISK=/system/bin/sgdisk#' /tmp/repartition.sh"
adb shell grep ^SGDISK= /tmp/repartition.sh
adb shell umount /system /vendor /cache /data
adb shell /system/bin/bash /tmp/repartition.sh
adb shell /system/bin/sgdisk --print /dev/block/mmcblk0
adb reboot recovery
```

Résultat attendu (16 Go) : partitions 1 à 17 (EFS, modem, bootloader…)
**inchangées**, puis SYSTEM 4 GiB, VENDOR 512 MiB, CACHE 64 MiB, CP_DEBUG,
NAD_FW, NAD_REFER, MISC 8 MiB, USERDATA (le reste). HIDDEN disparaît.

### 4. Formater

1. *Wipe → Format Data* → `yes`.
2. *Wipe → Advanced Wipe* → **System**, puis **Vendor** : *Repair or Change
   File System → Change File System → EXT4*.
3. **Cache : formatez-la en ligne de commande**, pas avec TWRP. Le formatage de
   TWRP a produit un système de fichiers au superbloc invalide ; Android
   n'arrivait alors pas à monter `/cache`, `installd` ne démarrait jamais et le
   système plantait en boucle (`SettingsProvider` : `settings.db` introuvable).

```
adb shell umount /cache
adb shell /system/bin/mke2fs -F -t ext4 -O ^metadata_csum /dev/block/platform/13540000.dwmmc0/by-name/CACHE
adb shell /system/bin/e2fsck -fn /dev/block/platform/13540000.dwmmc0/by-name/CACHE
```

`e2fsck` doit se terminer sans aucune erreur.

### 5. Installer la ROM (et les GApps)

*Advanced → ADB Sideload* → glisser, puis :

```
adb sideload lineage-22.2-AAAAMMJJ-UNOFFICIAL-j5y17lte.zip
```

Applications Google (facultatif, **avant** le premier démarrage) :
MindTheGapps **15** arm64. Son script cherche la partition système dans
`/dev/block/bootdevice/by-name/system`, qui n'existe pas sur les Exynos
(« Could not mount /mnt/system », Error 1). Créez ce chemin juste avant,
**dans la même session TWRP** :

```
adb shell mkdir -p /dev/block/bootdevice/by-name
adb shell ln -sf /dev/block/platform/13540000.dwmmc0/by-name/SYSTEM /dev/block/bootdevice/by-name/system
```

S'il manque de place (« Not enough space ») : *Advanced Wipe → System → Repair
or Change File System → **Resize File System***, puis recréez le chemin
ci-dessus. Enfin *ADB Sideload* :

```
adb sideload MindTheGapps-15.0.0-arm64-….zip
```

### 6. Premier démarrage

*Reboot → System*. Comptez 5 à 15 minutes.

**S'il ne finit jamais**, récupérez les journaux :

1. Dans TWRP, activez ADB au démarrage et le journal persistant avec
   [`tools/enable-boot-adb.sh`](tools/enable-boot-adb.sh) :

```
adb push enable-boot-adb.sh /tmp/
adb shell sh /tmp/enable-boot-adb.sh
```

2. Démarrez ; après 3 minutes : `adb logcat -d -b crash > crash.txt` et
   `adb logcat -d -b all > logcat.txt`. Trace du noyau du démarrage précédent,
   depuis TWRP : `adb shell cat /proc/last_kmsg`.
3. **Une fois le problème réglé, désactivez-le** (sinon n'importe quel câble USB
   donne un accès root sans confirmation) : depuis TWRP,
   `adb shell sh /tmp/enable-boot-adb.sh off`.

Note : un `Kernel panic` avec `hard_reset_hook_callback` dans `last_kmsg` n'est
pas un plantage : c'est le redémarrage forcé Vol- + Power.

## Limites connues

- Le J530F est souvent **mono-SIM** mais l'init déclare toujours 2 emplacements
  (comportement hérité de l'arbre d'origine) : un 2ᵉ emplacement vide peut
  apparaître.
- Android 15 sur 2 Go de RAM : fluide pour l'usage de base, limité en multitâche.
- Mises à jour OTA : non (build non officiel), il faut reflasher.
- Testé avec le bootloader/modem **Android 7** d'origine (`J530FXXU1AQI3`) alors
  que les blobs viennent du firmware Android 9 (`J530FXXS8CUE4`) : si le réseau
  mobile ne marche pas, passez d'abord au dernier firmware Samsung Android 9
  (avant de repartitionner : flasher le firmware complet remet les partitions
  d'origine).
- `/cache` est obligatoire dans le `fstab` de la plateforme commune : une
  partition cache illisible bloque tout le démarrage (voir étape 4).
