# LineageOS 22.2 (Android 15) — Galaxy J5 2017 européen

| | |
|---|---|
| Modèle | **SM-J530F** (aussi J530FM, J530G, J530GM) |
| Nom de code | `j5y17lte` |
| SoC | Exynos 7870 · noyau Linux 3.18 · 2 Go RAM · Wi-Fi/BT Broadcom |
| Statut | **Non officiel, jamais compilé ni testé sur J5** |

## D'où vient ce kit

La communauté [samsungexynos7870](https://github.com/samsungexynos7870) maintient
une pile LineageOS 22.2 complète pour l'Exynos 7870 (plateforme commune, noyau
avec eBPF rétroporté, HAL, blobs). Elle publie des builds 22.2 pour l'**A3 2017**,
mais l'arbre du **J5 2017** n'existe qu'en `lineage-20`.

Ce kit fige cet arbre `lineage-20` (commit `52defb3`, 4 oct. 2026, déjà
modernisé pour la plateforme commune 22.2) et y applique 7 patchs qui
reproduisent les changements faits sur l'A3 pour passer en 22.2 :

| Patch | Changement |
|---|---|
| 0001 | Tolérances de build clang, `AB_OTA_UPDATER := false`, nom du contrôleur USB (`13600000.dwc3`) |
| 0002 | Bibliothèque init déclarée via `soong_config_set` (nouvelle méthode Android 15) |
| 0003 | Wi-Fi : HAL AIDL `android.hardware.wifi-service-legacy` (remplace le HIDL 1.0) |
| 0004 | NFC : retrait de `NfcNci`, fourni par l'APEX nfcservices sur Android 15 |
| 0005 | Manifeste VINTF : FCM 3 → 5, retrait DRM clearkey/default et SehNfc, ajout soundtrigger 2.2 |
| 0006 | SELinux : étiquettes du shim `libbauthserver` (empreinte) et du HAL NFC |
| 0007 | init : `ro.multisim.simslotcount`, détection J530GM corrigée (avant J530G), log corrigé |

Ce qui a été **vérifié** : les 11 dépôts et branches existent, les patchs
s'appliquent sans conflit, la config noyau `exynos7870-j5y17lte_defconfig`
est présente dans la branche noyau 22.2, et toutes les options attendues par la
plateforme commune sont définies par le J5 (seules différences avec l'A3 :
ampli TFA9890 au lieu de 9896, pas de radio FM).

Ce qui **n'a pas** été vérifié : la compilation complète et le démarrage sur
un vrai téléphone.

## Contenu

| Fichier | Rôle |
|---|---|
| `local_manifests/j5y17lte.xml` | Les 11 dépôts à ajouter aux sources LineageOS 22.2 |
| `patches/0001…0007` | Le portage de l'arbre j5y17lte vers 22.2 |
| `build.sh` | Tout de A à Z : paquets → `repo sync` → patchs → `mka bacon` |

## Machine nécessaire

- Linux x86_64 (Ubuntu 22.04 ou 24.04)
- **300 Go** libres sur SSD
- **16 Go de RAM au minimum** (32 conseillés ; sinon ajoutez 16 Go de swap)
- Première compilation : 3 à 10 h selon le processeur

## Compiler

```bash
./build.sh
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

> ⚠️ Tout sera effacé. Knox sera grillé définitivement. À vos risques.

1. **Sauvegardez vos données**, et dans TWRP faites une **sauvegarde de la
   partition EFS** (IMEI, Wi-Fi/BT MAC) sur la carte SD ou le PC.
2. Activez *Options de développement → Déverrouillage OEM*.
3. Flashez un **TWRP pour j5y17lte** avec Odin (mode Download : Vol- + Home + Power).
4. La plateforme Exynos 7870 de la communauté a besoin d'une **partition `VENDOR`**
   (≈ 418 Mo), absente du firmware Samsung. Si vous n'avez jamais installé de
   LineageOS 18.1/20 de cette communauté, utilisez leur méthode de
   repartitionnement (TWRP communautaire). Tailles minimales attendues par le
   build (`BoardConfigCommon.mk`) : SYSTEM ≥ 2 739 Mio, VENDOR ≥ 415 Mio.
5. Dans TWRP : *Wipe → Format Data* (tapez `yes`), puis *Advanced Wipe* :
   System, Vendor, Cache, Dalvik.
6. Flashez le `.zip`. Facultatif : **MindTheGapps 15 arm64** juste après.
7. Redémarrez. Le premier démarrage peut prendre 5 à 10 minutes.

## Limites connues

- Le J530F est souvent **mono-SIM** mais l'init déclare toujours 2 emplacements
  (comportement hérité de l'arbre d'origine) : un 2ᵉ emplacement vide peut
  apparaître.
- Android 15 sur 2 Go de RAM : fluide pour l'usage de base, limité en multitâche.
- Mises à jour OTA : non (build non officiel), il faut reflasher.
