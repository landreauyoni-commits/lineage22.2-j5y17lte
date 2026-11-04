# Compiler la ROM sur Google Cloud (crédit d'essai gratuit)

Ce guide permet d'obtenir le fichier `lineage-22.2-…-j5y17lte.zip` sans rien
installer sur ton PC : un serveur Google Cloud compile la ROM à ta place.

| | |
|---|---|
| Coût réel | **0 €** : le crédit d'essai de 300 $ couvre tout (une compilation en consomme ~5 à 10 $) |
| Durée | ~5 à 6 h avec 16 vCPU, ~10 à 12 h avec 8 vCPU |
| Il te faut | Un compte Google, une carte bancaire (vérification uniquement) |

> **Pas de prélèvement surprise** : un compte d'essai Google Cloud n'est jamais
> facturé tant que tu ne cliques pas toi-même sur « Activer le compte complet ».
> À la fin de l'essai, ou si le crédit est épuisé, tout s'arrête simplement.

---

## Étape 1 — Créer le compte d'essai (10 min)

1. Va sur <https://cloud.google.com/free> → **Commencer gratuitement**.
2. Connecte-toi avec ton compte Google, choisis **France**, accepte les
   conditions, renseigne ta carte (une autorisation temporaire peut apparaître,
   elle est annulée).
3. La console s'ouvre avec un projet « My First Project » déjà créé. C'est lui
   qu'on utilise.

L'essai n'est possible que si tu n'as jamais été client payant de Google Cloud.

## Étape 2 — Activer Compute Engine (2 min)

Menu ☰ → **Compute Engine** → bouton **Activer** → attends 1 à 2 min que la
page « Instances de VM » s'affiche.

Les comptes d'essai ont parfois un quota de processeurs réduit. Inutile de le
vérifier à l'avance : à l'étape 3, essaie d'abord `n2-standard-16` ; si Google
refuse avec un message parlant de **quota**, recommence avec `n2-standard-8`
(plus lent, tout aussi gratuit).

## Étape 3 — Créer le serveur (5 min)

1. Menu ☰ → **Compute Engine** → **Instances de VM** → **Créer une instance**.
   (Si on te demande d'activer l'API Compute Engine : **Activer**.)
2. **Nom** : `lineage-build`
3. **Région** : `europe-west1 (Belgique)` — zone : n'importe laquelle.
4. **Configuration de la machine** : série **N2**, type **n2-standard-16**
   (ou **n2-standard-8** selon l'étape 2).
5. **Disque de démarrage** → **Modifier** :
   - Système d'exploitation : **Ubuntu**, version **Ubuntu 24.04 LTS**
     (x86/64, *pas* « Minimal » ni « Arm64 »)
   - Si la liste ne propose que **Debian** : prends **Debian GNU/Linux 12
     (bookworm)**, version **x86/64** (*pas* « arm64 »). `build.sh` fonctionne
     aussi sur Debian.
   - Type de disque : **Disque persistant avec équilibrage** (*Balanced persistent disk*)
   - Taille : **500** Go
   - **Sélectionner**
6. Dans les options avancées (*Gestion* / *Disponibilité*), vérifie que le
   **modèle de provisionnement** est **Standard** et **pas « Spot »** (une VM
   Spot peut être coupée en pleine compilation).
7. **Créer**. Le serveur démarre en ~1 minute ; Google affiche une estimation
   mensuelle : ignore-la, tu ne le garderas que quelques heures.

## Étape 4 — Lancer la compilation (5 min, puis on attend)

1. Sur la ligne `lineage-build`, clique sur **SSH**. Un terminal s'ouvre dans
   le navigateur (accepte l'autorisation).
2. Copie-colle ces commandes, **une par une** :

```bash
sudo apt-get update && sudo apt-get install -y git tmux
```

```bash
git clone https://github.com/landreauyoni-commits/lineage22.2-j5y17lte
```

```bash
tmux new -s build
```

```bash
cd lineage22.2-j5y17lte && LOW_DISK=1 ./build.sh 2>&1 | tee ~/build.log
```

`tmux` garde la compilation en vie même si tu fermes l'onglet ou éteins ton PC.
Tu es bien dans `tmux` si une **barre verte** s'affiche en bas du terminal.

- **Laisser tourner** : ferme simplement l'onglet SSH. (Le raccourci tmux
  `Ctrl + b` puis `d` est souvent intercepté par le navigateur : inutile ici.)
- **Revenir voir plus tard** : rouvre **SSH**, puis :

```bash
tmux attach -t build
```

Le script enchaîne : installation des outils → téléchargement des sources
(~1 h) → patchs → compilation (le plus long). Tant que des lignes défilent,
tout va bien. C'est fini quand tu vois `==> Terminé` suivi du nom du `.zip`.

## Étape 5 — Récupérer le fichier `.zip` (10 min)

Le menu « Télécharger le fichier » de la fenêtre SSH échoue souvent avec un
fichier de cette taille (~900 Mo). On passe par Cloud Storage.

1. Dans le terminal SSH, note l'empreinte du fichier :

```bash
sha256sum ~/android/lineage/out/target/product/j5y17lte/lineage-22.2-*-UNOFFICIAL-j5y17lte.zip
```

2. Connecte le serveur à ton compte (ouvre le lien affiché, **Autoriser**,
   recopie le code dans le terminal) :

```bash
gcloud auth login --no-launch-browser
```

3. Crée un espace de stockage et copie le zip dedans :

```bash
B=gs://j5-rom-$(date +%s) && gcloud storage buckets create $B --location=europe-west1 && gcloud storage cp ~/android/lineage/out/target/product/j5y17lte/lineage-22.2-*-UNOFFICIAL-j5y17lte.zip $B/ && echo "OK : $B"
```

4. Console : menu ☰ → **Cloud Storage** → **Buckets** → `j5-rom-…` → clique
   sur le `.zip` → **Télécharger**.
5. Sur ton PC (Windows, dans `cmd`, depuis le dossier Téléchargements),
   vérifie que l'empreinte est identique à celle de l'étape 1 :

```
certutil -hashfile lineage-22.2-AAAAMMJJ-UNOFFICIAL-j5y17lte.zip SHA256
```

## Étape 6 — Supprimer le serveur (2 min) ⚠️ ne pas oublier

1. **Compute Engine** → **Instances de VM** → coche `lineage-build` →
   **Supprimer** (le disque est supprimé avec).
2. Va dans **Compute Engine** → **Disques** : la liste doit être vide.
3. **Cloud Storage** → **Buckets** → coche `j5-rom-…` → **Supprimer**.

Sans ça, le serveur continue de consommer ton crédit (~10 à 20 $ par jour).

---

## En cas de problème

| Situation | Que faire |
|---|---|
| La compilation s'arrête sur une erreur (`failed to build some targets`) | `head -c 8000 ~/android/lineage/out/error.log` et envoie-moi ce qui s'affiche. Après correction : `SKIP_SYNC=1 LOW_DISK=1 ./build.sh 2>&1 \| tee ~/build.log` |
| Blobs propriétaires manquants | `SKIP_SYNC=1 LOW_DISK=1 REGEN_BLOBS=1 ./build.sh 2>&1 \| tee ~/build.log` |
| Tu dois t'absenter plusieurs jours en plein dépannage | **Arrêter** la VM (pas supprimer) : le processeur n'est plus facturé, seul le disque l'est (~2 $/jour) |
| Création refusée « quota dépassé » | Prends `n2-standard-8` |
| Voir le crédit restant | Menu ☰ → **Facturation** → **Présentation** |

Une fois le `.zip` récupéré, l'installation sur le téléphone est décrite dans
le [README](README.md#installer-sur-le-téléphone).
