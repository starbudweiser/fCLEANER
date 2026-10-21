<p align="center"><img src="assets/icon.png" width="128" alt="fCLEANER"></p>

# fCLEANER

**Cleans the leftovers of a flattened mod setup: metadata, backups, duplicates, sources, readmes…**  
*Nettoie les résidus d'une installation de mods aplatie : métadonnées, sauvegardes, doublons, sources, lisez-moi…*

🇬🇧 [English](#-english) · 🇫🇷 [Français](#-français)

---
## 🇬🇧 English

### What it does

After flattening a mod list (with mO2FLATTENER or by hand), the game folder is full of files the game never uses. fCLEANER scans a folder, shows what would be removed (dry run) and purges it only when you ask.

### Features

- **Scan** first (dry run): nothing is deleted, the full list is shown with sizes.
- Removes OS caches (thumbs.db, desktop.ini, .DS_Store) and MO2 hidden files (`*.mohidden`).
- Removes xEdit modgroups and Vortex / Nexus collection metadata and staging leftovers.
- Removes backups and temporary files (`*.bak`, `*.tmp`, `* - copy.*`), office documents and graphic sources (.psd, .xcf, .pdn).
- Removes readmes, changelogs and licenses.
- Built-in **filtering rules** window listing everything that is targeted.
- Interface in **English, French, Italian and Spanish** (follows your Mac's language; can be changed in the app).

### Screenshots

![Dry-run scan of a mods folder](docs/screenshots/02_scan.png)
*Dry-run scan of a mods folder*

### Requirements

A Mac with **Apple Silicon** (M1 or later), **macOS 13 Ventura** or later. No Python, no Wine, no virtual machine needed.

### Installation

1. Download the zip from Nexus Mods (or from the GitHub releases) and unzip it.
2. Move **fCLEANER.app** to your **Applications** folder.
3. First launch: the app is signed with a personal certificate but **not notarized by Apple**, so macOS blocks it. Open **System Settings → Privacy & Security**, scroll down and click **Open Anyway** next to fCLEANER, then confirm. On macOS 14 or earlier you can also right-click the app → **Open** → **Open**.
4. Still blocked? In Terminal: `xattr -dr com.apple.quarantine /Applications/fCLEANER.app`

### How to use

1. Click **Choose a folder** and select the assembled game folder (or a mods collection).
2. Click **SCAN** and read the log.
3. If the list is right, click **Purge leftovers**.

### FAQ

**Is the purge reversible?**  
No: deleted files are not moved to the Trash. Always read the scan first, and keep a backup of your modlist.

### Building from source

Requires Python 3.12 with PyQt6 and PyInstaller. From the repository folder:

```bash
./build_app.sh
```

### License

Released under the **MIT License**: free to use, modify and share. Part of the **Skyrim Mac Toolkit**, a set of modding tools built for Skyrim players on Mac.

---

## 🇫🇷 Français

### À quoi ça sert

Après l'aplatissement d'une liste de mods (avec mO2FLATTENER ou à la main), le dossier du jeu est plein de fichiers que le jeu n'utilise jamais. fCLEANER analyse un dossier, montre ce qui serait supprimé (simulation) et ne purge que sur demande.

### Fonctions

- **Analyse** d'abord (simulation) : rien n'est supprimé, la liste complète s'affiche avec les tailles.
- Supprime les caches système (thumbs.db, desktop.ini, .DS_Store) et les fichiers masqués de MO2 (`*.mohidden`).
- Supprime les modgroups xEdit et les métadonnées et restes de staging des collections Vortex / Nexus.
- Supprime les sauvegardes et fichiers temporaires (`*.bak`, `*.tmp`, `* - copie.*`), les documents bureautiques et les sources graphiques (.psd, .xcf, .pdn).
- Supprime les lisez-moi, journaux de modifications et licences.
- Fenêtre **Règles de filtrage** qui liste tout ce qui est ciblé.
- Interface en **français, anglais, italien et espagnol** (suit la langue du Mac ; modifiable dans l'appli).

### Captures d'écran

![Analyse simulée d'un dossier de mods](docs/screenshots/02_scan.png)
*Analyse simulée d'un dossier de mods*

### Configuration requise

Un Mac **Apple Silicon** (M1 ou plus récent), **macOS 13 Ventura** ou plus récent. Ni Python, ni Wine, ni machine virtuelle.

### Installation

1. Téléchargez le zip sur Nexus Mods (ou dans les releases GitHub) et décompressez-le.
2. Placez **fCLEANER.app** dans votre dossier **Applications**.
3. Premier lancement : l'appli est signée avec un certificat personnel mais **pas notarisée par Apple**, macOS la bloque donc. Ouvrez **Réglages Système → Confidentialité et sécurité**, descendez et cliquez sur **Ouvrir quand même** à côté de fCLEANER, puis confirmez. Sous macOS 14 ou antérieur, vous pouvez aussi faire clic droit sur l'appli → **Ouvrir** → **Ouvrir**.
4. Toujours bloquée ? Dans le Terminal : `xattr -dr com.apple.quarantine /Applications/fCLEANER.app`

### Utilisation

1. Cliquez sur **Choisir un dossier** et sélectionnez le dossier de jeu assemblé (ou une collection de mods).
2. Cliquez sur **ANALYSER** et lisez le journal.
3. Si la liste convient, cliquez sur **Purger les résidus**.

### Questions fréquentes

**La purge est-elle réversible ?**  
Non : les fichiers supprimés ne vont pas dans la Corbeille. Lisez toujours l'analyse d'abord et gardez une sauvegarde de votre modlist.

### Compiler depuis les sources

Nécessite Python 3.12 avec PyQt6 et PyInstaller. Depuis le dossier du dépôt :

```bash
./build_app.sh
```

### Licence

Publié sous **licence MIT** : libre d'utilisation, de modification et de partage. Fait partie du **Skyrim Mac Toolkit**, un ensemble d'outils de modding pensés pour les joueurs de Skyrim sur Mac.
