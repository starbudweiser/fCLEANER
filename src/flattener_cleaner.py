#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
fCLEANER GUI (PyQt6)
Outil universel de post-assemblage multilingue (FR / EN / IT / ES) pour scanner
et purger les résidus d'assemblage, sauvegardes, doublons, sources de travail,
métadonnées de gestionnaires de mods (MO2, Vortex, xEdit) et licences/lisez-moi.
Interface : design system Socle (module socle_qt).
"""

import html
import os
import re
import shutil
import sys
import time
from typing import List, Tuple

import socle_qt
import update_check
from PyQt6.QtCore import Qt, QThread, pyqtSignal, QSettings
from PyQt6.QtWidgets import (
    QApplication,
    QMainWindow,
    QWidget,
    QVBoxLayout,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QPushButton,
    QPlainTextEdit,
    QTextBrowser,
    QFileDialog,
    QMessageBox,
    QFrame,
    QDialog,
    QButtonGroup,
)
from PyQt6.QtGui import QIcon


def resource_path(relative_path: str) -> str:
    """Chemin d'une ressource, compatible PyInstaller et exécution depuis les sources."""
    if hasattr(sys, "_MEIPASS"):
        return os.path.join(sys._MEIPASS, relative_path)
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", relative_path)


# ----------------------------------------------------------------------
# Motifs ciblés (insensibles à la casse). Lus aussi par preview/tools/extract.py.
# ----------------------------------------------------------------------
FILE_PATTERNS = [
    # Système / OS
    r"^thumbs\.db$",
    r"^desktop\.ini$",
    r"^\.DS_Store$",
    # Mod Organizer 2
    r"\.mohidden$",
    # xEdit (SSEEdit / FO4Edit)
    r"\.modgroups$",
    r"^modgroups\.json$",
    # Vortex & Collections Nexus Mods (.vortex_backup couvre ActiveMods.json / Engine.log)
    r"^vortex\.deployment\.json$",
    r"^__?folder_managed_by_vortex$",
    r"\.vortex_backup",
    r"\.vortex_lnk$",
    r"^(collection\.json|collection\.meta|manifest\.json)$",
    # Sauvegardes & temporaires
    r"\.(bak|tmp|crdownload)$",
    # Copies & doublons de fichiers (dont noms mal décodés)
    r" - cop(y|ie|ia)\.[^.]+$",
    r" - [©▒¥\?]+\.[^.]+$",
    # Sources graphiques de travail non compilées
    r"\.(pdn|xcf|psd)$",
    # Documents bureautiques inutiles en jeu
    r"\.(docx?|rtf|odt)$",
    # Fichiers de test / factices
    r"^(dummy texture|faketexture)\.dds$",
    # Documentation & licences UNIQUEMENT (les .txt fonctionnels sont préservés)
    r"^(readme|read_me|read me|lisezmoi|lisez_moi|lisez moi|instructions?|changelog|licen[sc]e|eula|copying)\.(txt|md)$",
]

DIR_PATTERNS = [
    r"\.mohidden$",
    r" - cop(y|ie|ia)$",
    r"^__vortex_",
    r"^\.vortex_staging$",
    r"^__?folder_managed_by_vortex$",
    r"^modgroups$",
]

# Une seule expression par catégorie : un test par nom au lieu d'une boucle sur chaque motif.
FILE_RE = re.compile("|".join(f"(?:{p})" for p in FILE_PATTERNS), re.IGNORECASE)
DIR_RE = re.compile("|".join(f"(?:{p})" for p in DIR_PATTERNS), re.IGNORECASE)


# ----------------------------------------------------------------------
# Dictionnaire de traduction (i18n) : FR, EN, IT, ES
# ----------------------------------------------------------------------
TRANSLATIONS = {
    "fr": {
        "app_title": "fCLEANER – Nettoyeur d'instance",
        "header_title": "🧹 fCLEANER",
        "header_subtitle": (
            "Purge les résidus d'assemblage d'une instance ou d'une collection (MO2, Vortex, Nexus) : "
            "métadonnées, modgroups xEdit, caches système, sauvegardes (.BAK), doublons, documents bureautiques, "
            "sources graphiques (.PSD, .XCF, .PDN), lisez-moi et licences."
        ),
        "path_placeholder": "Choisissez le dossier assemblé ou la collection à nettoyer.",
        "btn_browse": "Choisir un dossier",
        "log_title": "Journal",
        "status_ready": "Choisissez un dossier pour commencer.",
        "status_loaded": "Dossier prêt. Lancez l'analyse.",
        "btn_rules": "Règles de filtrage",
        "btn_scan": "ANALYSER",
        "btn_clean": "Purger les résidus",
        "btn_confirm_clean": "Supprimer",
        "btn_cancel": "Annuler",
        "dialog_rules_title": "Règles de filtrage",
        "dialog_rules_header": "📋 Éléments ciblés par la purge",
        "dialog_rules_btn_close": "Fermer",
        "dialog_choose_dir": "Choisir le dossier à nettoyer",
        "warn_missing_dir_title": "Dossier introuvable",
        "warn_missing_dir_msg": "Ce dossier n'existe pas ou n'est plus accessible. Choisissez-en un autre avec « {btn} ».",
        "confirm_clean_title": "Purger les résidus",
        "confirm_clean_msg": (
            "Supprimer définitivement {files} fichier(s) et {dirs} dossier(s) détectés ?\n\n"
            "Les autres fichiers .TXT des mods ne sont pas touchés. Cette opération est irréversible."
        ),
        "clean_complete_title": "Purge terminée",
        "log_selected_dir": "📁 Dossier sélectionné : ",
        "worker_processing": "Traitement en cours ({mode})…",
        "worker_mode_clean": "PURGE",
        "worker_mode_sim": "SIMULATION, aucune modification",
        "worker_target": "Dossier :",
        "worker_mode_label": "Mode :",
        "worker_no_residues": "✓ Aucun résidu détecté. Le dossier est propre.",
        "worker_status_clean": "Analyse terminée : aucun résidu.",
        "worker_detected_summary": "Détectés : {files} fichier(s), {dirs} dossier(s), {size}",
        "worker_walk_errors": "⚠ {count} dossier(s) illisible(s) ignoré(s).",
        "worker_tag_deleted": "[SUPPRIMÉ]",
        "worker_tag_detected": "[DÉTECTÉ]",
        "worker_tag_dir_deleted": "[DOSSIER SUPPRIMÉ]",
        "worker_tag_dir_detected": "[DOSSIER DÉTECTÉ]",
        "worker_tag_error": "[ERREUR]",
        "worker_tag_dir_error": "[ERREUR DOSSIER]",
        "worker_clean_done": "Purge terminée : {files} fichier(s) et {dirs} dossier(s) supprimés.",
        "worker_clean_errors": "Erreur : {count} élément(s) n'ont pas pu être supprimés. Vérifiez qu'ils ne sont pas ouverts ou protégés.",
        "worker_sim_done": "Analyse terminée : {files} fichier(s) et {dirs} dossier(s) à purger.",
        "worker_sim_hint": "Rien n'a été supprimé. Cliquez sur « {btn} » pour les supprimer.",
        "unit_bytes": "octets",
        "unit_kb": "Ko",
        "unit_mb": "Mo",
        "unit_gb": "Go",
        "rules_html": """
            <h3>1. Caches et fichiers système</h3>
            <ul>
                <li><code>thumbs.db</code> (miniatures Windows)</li>
                <li><code>desktop.ini</code> (réglages de dossier Windows)</li>
                <li><code>.DS_Store</code> (métadonnées macOS)</li>
            </ul>
            <h3>2. Mod Organizer 2</h3>
            <ul>
                <li>Fichiers et dossiers masqués : <code>*.mohidden</code></li>
            </ul>
            <h3>3. xEdit (SSEEdit / FO4Edit)</h3>
            <ul>
                <li>Groupes de mods : <code>*.modgroups</code>, <code>modgroups.json</code></li>
                <li>Dossiers : <code>modgroups/</code></li>
            </ul>
            <h3>4. Vortex et collections Nexus Mods</h3>
            <ul>
                <li>Déploiement : <code>vortex.deployment.json</code></li>
                <li>Marqueurs : <code>folder_managed_by_vortex</code>, <code>__folder_managed_by_vortex</code></li>
                <li>Sauvegardes : <code>ActiveMods.json.vortex_backup</code>, <code>Engine.log.vortex_backup</code>, <code>*.vortex_backup*</code></li>
                <li>Liens symboliques résiduels : <code>*.vortex_lnk</code></li>
                <li>Métadonnées Nexus : <code>collection.json</code>, <code>collection.meta</code>, <code>manifest.json</code></li>
                <li>Dossiers temporaires : <code>__vortex_*</code>, <code>.vortex_staging/</code></li>
            </ul>
            <h3>5. Sauvegardes, temporaires et doublons</h3>
            <ul>
                <li>Sauvegardes : <code>*.bak</code>, <code>*.tmp</code>, <code>*.crdownload</code></li>
                <li>Copies de fichiers : <code> - copy.*</code>, <code> - copie.*</code>, <code> - copia.*</code></li>
                <li>Dossiers doublons : <code> - copy</code>, <code> - copie</code>, <code> - copia</code></li>
            </ul>
            <h3>6. Documents bureautiques</h3>
            <ul>
                <li>Traitements de texte : <code>*.doc</code>, <code>*.docx</code>, <code>*.rtf</code>, <code>*.odt</code></li>
            </ul>
            <h3>7. Sources graphiques et fichiers factices</h3>
            <ul>
                <li>Projets graphiques : <code>*.pdn</code>, <code>*.xcf</code>, <code>*.psd</code></li>
                <li>Textures de test : <code>dummy texture.dds</code>, <code>faketexture.dds</code></li>
            </ul>
            <h3>8. Documentation et licences uniquement</h3>
            <ul>
                <li>Notices : <code>readme</code>, <code>read_me</code>, <code>lisezmoi</code>, <code>instructions</code>, <code>changelog</code> (.txt/.md)</li>
                <li>Licences : <code>license</code>, <code>licence</code>, <code>eula</code>, <code>copying</code> (.txt/.md)</li>
            </ul>
            <p class="note"><b>Protégé :</b> tous les autres fichiers <code>.txt</code> de configuration des mods sont conservés.</p>
        """,
    },
    "en": {
        "app_title": "fCLEANER – Instance cleaner",
        "header_title": "🧹 fCLEANER",
        "header_subtitle": (
            "Purges assembly leftovers from an instance or a collection (MO2, Vortex, Nexus): "
            "metadata, xEdit modgroups, OS caches, backups (.BAK), duplicates, office documents, "
            "graphics sources (.PSD, .XCF, .PDN), readmes and licenses."
        ),
        "path_placeholder": "Choose the assembled folder or collection to clean.",
        "btn_browse": "Choose a folder",
        "log_title": "Log",
        "status_ready": "Choose a folder to get started.",
        "status_loaded": "Folder ready. Run the scan.",
        "btn_rules": "Filtering rules",
        "btn_scan": "SCAN",
        "btn_clean": "Purge leftovers",
        "btn_confirm_clean": "Delete",
        "btn_cancel": "Cancel",
        "dialog_rules_title": "Filtering rules",
        "dialog_rules_header": "📋 Items targeted by the purge",
        "dialog_rules_btn_close": "Close",
        "dialog_choose_dir": "Choose the folder to clean",
        "warn_missing_dir_title": "Folder not found",
        "warn_missing_dir_msg": "This folder does not exist or is no longer reachable. Choose another one with “{btn}”.",
        "confirm_clean_title": "Purge leftovers",
        "confirm_clean_msg": (
            "Permanently delete {files} detected file(s) and {dirs} folder(s)?\n\n"
            "Other mod .TXT files are not touched. This cannot be undone."
        ),
        "clean_complete_title": "Purge complete",
        "log_selected_dir": "📁 Selected folder: ",
        "worker_processing": "Processing ({mode})…",
        "worker_mode_clean": "PURGE",
        "worker_mode_sim": "DRY RUN, nothing is changed",
        "worker_target": "Folder:",
        "worker_mode_label": "Mode:",
        "worker_no_residues": "✓ No leftovers detected. The folder is clean.",
        "worker_status_clean": "Scan complete: no leftovers.",
        "worker_detected_summary": "Detected: {files} file(s), {dirs} folder(s), {size}",
        "worker_walk_errors": "⚠ {count} unreadable folder(s) skipped.",
        "worker_tag_deleted": "[DELETED]",
        "worker_tag_detected": "[DETECTED]",
        "worker_tag_dir_deleted": "[FOLDER DELETED]",
        "worker_tag_dir_detected": "[FOLDER DETECTED]",
        "worker_tag_error": "[ERROR]",
        "worker_tag_dir_error": "[FOLDER ERROR]",
        "worker_clean_done": "Purge complete: {files} file(s) and {dirs} folder(s) deleted.",
        "worker_clean_errors": "Error: {count} item(s) could not be deleted. Check that they are not open or protected.",
        "worker_sim_done": "Scan complete: {files} file(s) and {dirs} folder(s) to purge.",
        "worker_sim_hint": "Nothing was deleted. Click “{btn}” to delete them.",
        "unit_bytes": "bytes",
        "unit_kb": "KB",
        "unit_mb": "MB",
        "unit_gb": "GB",
        "rules_html": """
            <h3>1. OS caches and system files</h3>
            <ul>
                <li><code>thumbs.db</code> (Windows thumbnail cache)</li>
                <li><code>desktop.ini</code> (Windows folder settings)</li>
                <li><code>.DS_Store</code> (macOS metadata)</li>
            </ul>
            <h3>2. Mod Organizer 2</h3>
            <ul>
                <li>Hidden files and folders: <code>*.mohidden</code></li>
            </ul>
            <h3>3. xEdit (SSEEdit / FO4Edit)</h3>
            <ul>
                <li>Modgroup files: <code>*.modgroups</code>, <code>modgroups.json</code></li>
                <li>Folders: <code>modgroups/</code></li>
            </ul>
            <h3>4. Vortex and Nexus Mods collections</h3>
            <ul>
                <li>Deployment: <code>vortex.deployment.json</code></li>
                <li>Markers: <code>folder_managed_by_vortex</code>, <code>__folder_managed_by_vortex</code></li>
                <li>Backups: <code>ActiveMods.json.vortex_backup</code>, <code>Engine.log.vortex_backup</code>, <code>*.vortex_backup*</code></li>
                <li>Residual symlinks: <code>*.vortex_lnk</code></li>
                <li>Nexus metadata: <code>collection.json</code>, <code>collection.meta</code>, <code>manifest.json</code></li>
                <li>Staging folders: <code>__vortex_*</code>, <code>.vortex_staging/</code></li>
            </ul>
            <h3>5. Backups, temporary files and duplicates</h3>
            <ul>
                <li>Backups: <code>*.bak</code>, <code>*.tmp</code>, <code>*.crdownload</code></li>
                <li>File copies: <code> - copy.*</code>, <code> - copie.*</code>, <code> - copia.*</code></li>
                <li>Duplicate folders: <code> - copy</code>, <code> - copie</code>, <code> - copia</code></li>
            </ul>
            <h3>6. Office documents</h3>
            <ul>
                <li>Word processing: <code>*.doc</code>, <code>*.docx</code>, <code>*.rtf</code>, <code>*.odt</code></li>
            </ul>
            <h3>7. Graphics sources and dummy files</h3>
            <ul>
                <li>Graphics projects: <code>*.pdn</code>, <code>*.xcf</code>, <code>*.psd</code></li>
                <li>Test textures: <code>dummy texture.dds</code>, <code>faketexture.dds</code></li>
            </ul>
            <h3>8. Documentation and licenses only</h3>
            <ul>
                <li>Guides: <code>readme</code>, <code>read_me</code>, <code>instructions</code>, <code>changelog</code> (.txt/.md)</li>
                <li>Licenses: <code>license</code>, <code>licence</code>, <code>eula</code>, <code>copying</code> (.txt/.md)</li>
            </ul>
            <p class="note"><b>Protected:</b> all other mod configuration <code>.txt</code> files are kept.</p>
        """,
    },
    "it": {
        "app_title": "fCLEANER – Pulitore di istanze",
        "header_title": "🧹 fCLEANER",
        "header_subtitle": (
            "Elimina i residui di assemblaggio di un'istanza o di una collezione (MO2, Vortex, Nexus): "
            "metadati, modgroups xEdit, cache di sistema, backup (.BAK), duplicati, documenti d'ufficio, "
            "sorgenti grafiche (.PSD, .XCF, .PDN), leggimi e licenze."
        ),
        "path_placeholder": "Scelga la cartella assemblata o la collezione da pulire.",
        "btn_browse": "Scegli una cartella",
        "log_title": "Registro",
        "status_ready": "Scelga una cartella per iniziare.",
        "status_loaded": "Cartella pronta. Avvii l'analisi.",
        "btn_rules": "Regole di filtro",
        "btn_scan": "ANALIZZA",
        "btn_clean": "Elimina residui",
        "btn_confirm_clean": "Elimina",
        "btn_cancel": "Annulla",
        "dialog_rules_title": "Regole di filtro",
        "dialog_rules_header": "📋 Elementi presi di mira dalla pulizia",
        "dialog_rules_btn_close": "Chiudi",
        "dialog_choose_dir": "Scegli la cartella da pulire",
        "warn_missing_dir_title": "Cartella non trovata",
        "warn_missing_dir_msg": "Questa cartella non esiste o non è più accessibile. Ne scelga un'altra con « {btn} ».",
        "confirm_clean_title": "Elimina residui",
        "confirm_clean_msg": (
            "Eliminare definitivamente {files} file e {dirs} cartella/e rilevati?\n\n"
            "Gli altri file .TXT delle mod non vengono toccati. L'operazione è irreversibile."
        ),
        "clean_complete_title": "Pulizia completata",
        "log_selected_dir": "📁 Cartella selezionata: ",
        "worker_processing": "Elaborazione in corso ({mode})…",
        "worker_mode_clean": "ELIMINAZIONE",
        "worker_mode_sim": "SIMULAZIONE, nessuna modifica",
        "worker_target": "Cartella:",
        "worker_mode_label": "Modalità:",
        "worker_no_residues": "✓ Nessun residuo rilevato. La cartella è pulita.",
        "worker_status_clean": "Analisi completata: nessun residuo.",
        "worker_detected_summary": "Rilevati: {files} file, {dirs} cartella/e, {size}",
        "worker_walk_errors": "⚠ {count} cartella/e illeggibile/i ignorata/e.",
        "worker_tag_deleted": "[ELIMINATO]",
        "worker_tag_detected": "[RILEVATO]",
        "worker_tag_dir_deleted": "[CARTELLA ELIMINATA]",
        "worker_tag_dir_detected": "[CARTELLA RILEVATA]",
        "worker_tag_error": "[ERRORE]",
        "worker_tag_dir_error": "[ERRORE CARTELLA]",
        "worker_clean_done": "Pulizia completata: {files} file e {dirs} cartella/e eliminati.",
        "worker_clean_errors": "Errore: {count} elemento/i non eliminato/i. Verifichi che non siano aperti o protetti.",
        "worker_sim_done": "Analisi completata: {files} file e {dirs} cartella/e da eliminare.",
        "worker_sim_hint": "Nulla è stato eliminato. Faccia clic su « {btn} » per eliminarli.",
        "unit_bytes": "byte",
        "unit_kb": "KB",
        "unit_mb": "MB",
        "unit_gb": "GB",
        "rules_html": """
            <h3>1. Cache del sistema operativo</h3>
            <ul>
                <li><code>thumbs.db</code>, <code>desktop.ini</code>, <code>.DS_Store</code></li>
            </ul>
            <h3>2. Mod Organizer 2</h3>
            <ul>
                <li>File e cartelle nascosti: <code>*.mohidden</code></li>
            </ul>
            <h3>3. xEdit (SSEEdit / FO4Edit)</h3>
            <ul>
                <li>File modgroups: <code>*.modgroups</code>, <code>modgroups.json</code></li>
                <li>Cartelle: <code>modgroups/</code></li>
            </ul>
            <h3>4. Vortex e collezioni Nexus</h3>
            <ul>
                <li>Deployment: <code>vortex.deployment.json</code></li>
                <li>Marcatori: <code>folder_managed_by_vortex</code>, <code>__folder_managed_by_vortex</code></li>
                <li>Backup: <code>ActiveMods.json.vortex_backup</code>, <code>Engine.log.vortex_backup</code>, <code>*.vortex_backup*</code></li>
                <li>Collegamenti simbolici: <code>*.vortex_lnk</code></li>
                <li>Metadati: <code>collection.json</code>, <code>collection.meta</code>, <code>manifest.json</code></li>
                <li>Cartelle di staging: <code>__vortex_*</code>, <code>.vortex_staging/</code></li>
            </ul>
            <h3>5. Backup, temporanei e duplicati</h3>
            <ul>
                <li>Backup: <code>*.bak</code>, <code>*.tmp</code>, <code>*.crdownload</code></li>
                <li>Copie di file: <code> - copy.*</code>, <code> - copie.*</code>, <code> - copia.*</code></li>
                <li>Cartelle duplicate: <code> - copy</code>, <code> - copie</code>, <code> - copia</code></li>
            </ul>
            <h3>6. Documenti d'ufficio</h3>
            <ul>
                <li>Videoscrittura: <code>*.doc</code>, <code>*.docx</code>, <code>*.rtf</code>, <code>*.odt</code></li>
            </ul>
            <h3>7. Sorgenti grafiche e file fittizi</h3>
            <ul>
                <li>Progetti grafici: <code>*.pdn</code>, <code>*.xcf</code>, <code>*.psd</code></li>
                <li>Texture di prova: <code>dummy texture.dds</code>, <code>faketexture.dds</code></li>
            </ul>
            <h3>8. Solo documentazione e licenze</h3>
            <ul>
                <li>Istruzioni: <code>readme</code>, <code>read_me</code>, <code>instructions</code>, <code>changelog</code> (.txt/.md)</li>
                <li>Licenze: <code>license</code>, <code>licence</code>, <code>eula</code>, <code>copying</code> (.txt/.md)</li>
            </ul>
            <p class="note"><b>Protetti:</b> tutti gli altri file <code>.txt</code> di configurazione delle mod vengono conservati.</p>
        """,
    },
    "es": {
        "app_title": "fCLEANER – Limpiador de instancias",
        "header_title": "🧹 fCLEANER",
        "header_subtitle": (
            "Elimina los residuos de ensamblado de una instancia o colección (MO2, Vortex, Nexus): "
            "metadatos, modgroups de xEdit, cachés del sistema, copias de seguridad (.BAK), duplicados, ofimática, "
            "fuentes gráficas (.PSD, .XCF, .PDN), léame y licencias."
        ),
        "path_placeholder": "Elija la carpeta ensamblada o la colección que desea limpiar.",
        "btn_browse": "Elegir una carpeta",
        "log_title": "Registro",
        "status_ready": "Elija una carpeta para empezar.",
        "status_loaded": "Carpeta lista. Inicie el análisis.",
        "btn_rules": "Reglas de filtrado",
        "btn_scan": "ANALIZAR",
        "btn_clean": "Purgar residuos",
        "btn_confirm_clean": "Eliminar",
        "btn_cancel": "Cancelar",
        "dialog_rules_title": "Reglas de filtrado",
        "dialog_rules_header": "📋 Elementos objetivo de la purga",
        "dialog_rules_btn_close": "Cerrar",
        "dialog_choose_dir": "Elegir la carpeta que desea limpiar",
        "warn_missing_dir_title": "Carpeta no encontrada",
        "warn_missing_dir_msg": "Esta carpeta no existe o ya no es accesible. Elija otra con « {btn} ».",
        "confirm_clean_title": "Purgar residuos",
        "confirm_clean_msg": (
            "¿Eliminar definitivamente {files} archivo(s) y {dirs} carpeta(s) detectados?\n\n"
            "Los demás archivos .TXT de los mods no se tocan. Esta operación es irreversible."
        ),
        "clean_complete_title": "Purga completada",
        "log_selected_dir": "📁 Carpeta seleccionada: ",
        "worker_processing": "Procesando ({mode})…",
        "worker_mode_clean": "PURGA",
        "worker_mode_sim": "SIMULACIÓN, sin modificaciones",
        "worker_target": "Carpeta:",
        "worker_mode_label": "Modo:",
        "worker_no_residues": "✓ No se detectaron residuos. La carpeta está limpia.",
        "worker_status_clean": "Análisis completado: sin residuos.",
        "worker_detected_summary": "Detectados: {files} archivo(s), {dirs} carpeta(s), {size}",
        "worker_walk_errors": "⚠ {count} carpeta(s) ilegible(s) omitida(s).",
        "worker_tag_deleted": "[ELIMINADO]",
        "worker_tag_detected": "[DETECTADO]",
        "worker_tag_dir_deleted": "[CARPETA ELIMINADA]",
        "worker_tag_dir_detected": "[CARPETA DETECTADA]",
        "worker_tag_error": "[ERROR]",
        "worker_tag_dir_error": "[ERROR DE CARPETA]",
        "worker_clean_done": "Purga completada: {files} archivo(s) y {dirs} carpeta(s) eliminados.",
        "worker_clean_errors": "Error: {count} elemento(s) no se pudieron eliminar. Compruebe que no estén abiertos o protegidos.",
        "worker_sim_done": "Análisis completado: {files} archivo(s) y {dirs} carpeta(s) por purgar.",
        "worker_sim_hint": "No se eliminó nada. Haga clic en « {btn} » para eliminarlos.",
        "unit_bytes": "bytes",
        "unit_kb": "KB",
        "unit_mb": "MB",
        "unit_gb": "GB",
        "rules_html": """
            <h3>1. Cachés y archivos del sistema</h3>
            <ul>
                <li><code>thumbs.db</code>, <code>desktop.ini</code>, <code>.DS_Store</code></li>
            </ul>
            <h3>2. Mod Organizer 2</h3>
            <ul>
                <li>Archivos y carpetas ocultos: <code>*.mohidden</code></li>
            </ul>
            <h3>3. xEdit (SSEEdit / FO4Edit)</h3>
            <ul>
                <li>Archivos modgroups: <code>*.modgroups</code>, <code>modgroups.json</code></li>
                <li>Carpetas: <code>modgroups/</code></li>
            </ul>
            <h3>4. Vortex y colecciones Nexus</h3>
            <ul>
                <li>Despliegue: <code>vortex.deployment.json</code></li>
                <li>Marcadores: <code>folder_managed_by_vortex</code>, <code>__folder_managed_by_vortex</code></li>
                <li>Copias: <code>ActiveMods.json.vortex_backup</code>, <code>Engine.log.vortex_backup</code>, <code>*.vortex_backup*</code></li>
                <li>Enlaces simbólicos residuales: <code>*.vortex_lnk</code></li>
                <li>Metadatos: <code>collection.json</code>, <code>collection.meta</code>, <code>manifest.json</code></li>
                <li>Carpetas de staging: <code>__vortex_*</code>, <code>.vortex_staging/</code></li>
            </ul>
            <h3>5. Copias, temporales y duplicados</h3>
            <ul>
                <li>Copias de seguridad: <code>*.bak</code>, <code>*.tmp</code>, <code>*.crdownload</code></li>
                <li>Copias de archivos: <code> - copy.*</code>, <code> - copie.*</code>, <code> - copia.*</code></li>
                <li>Carpetas duplicadas: <code> - copy</code>, <code> - copie</code>, <code> - copia</code></li>
            </ul>
            <h3>6. Documentos de oficina</h3>
            <ul>
                <li>Procesadores de texto: <code>*.doc</code>, <code>*.docx</code>, <code>*.rtf</code>, <code>*.odt</code></li>
            </ul>
            <h3>7. Fuentes gráficas y archivos ficticios</h3>
            <ul>
                <li>Proyectos gráficos: <code>*.pdn</code>, <code>*.xcf</code>, <code>*.psd</code></li>
                <li>Texturas de prueba: <code>dummy texture.dds</code>, <code>faketexture.dds</code></li>
            </ul>
            <h3>8. Solo documentación y licencias</h3>
            <ul>
                <li>Guías: <code>readme</code>, <code>read_me</code>, <code>instructions</code>, <code>changelog</code> (.txt/.md)</li>
                <li>Licencias: <code>license</code>, <code>licence</code>, <code>eula</code>, <code>copying</code> (.txt/.md)</li>
            </ul>
            <p class="note"><b>Protegidos:</b> todos los demás archivos <code>.txt</code> de configuración de los mods se conservan.</p>
        """,
    },
}

LANGUAGES = [("fr", "🇫🇷 FR"), ("en", "🇬🇧 EN"), ("it", "🇮🇹 IT"), ("es", "🇪🇸 ES")]


def tr(lang: str) -> dict:
    return TRANSLATIONS.get(lang, TRANSLATIONS["fr"])


def format_size(size_bytes: int, t: dict) -> str:
    if size_bytes < 1024:
        return f"{size_bytes} {t['unit_bytes']}"
    if size_bytes < 1024 ** 2:
        return f"{size_bytes / 1024:.1f} {t['unit_kb']}"
    if size_bytes < 1024 ** 3:
        return f"{size_bytes / 1024 ** 2:.2f} {t['unit_mb']}"
    return f"{size_bytes / 1024 ** 3:.2f} {t['unit_gb']}"


def tree_size(path: str) -> int:
    """Taille cumulée des fichiers d'un dossier (sans suivre les liens symboliques)."""
    if os.path.islink(path):
        return 0
    total = 0
    for root, _dirs, files in os.walk(path):
        for f in files:
            try:
                total += os.lstat(os.path.join(root, f)).st_size
            except OSError:
                pass
    return total


def span(color_token: str, text: str, bold: bool = False) -> str:
    weight = " font-weight: 700;" if bold else ""
    return f"<span style='color: {socle_qt.c(color_token)};{weight}'>{text}</span>"


# ----------------------------------------------------------------------
# Boîte de dialogue listant les règles de filtrage actives
# ----------------------------------------------------------------------
class FiltersDialog(QDialog):
    def __init__(self, lang: str = "fr", parent=None):
        super().__init__(parent)
        t = tr(lang)
        self.setWindowTitle(t["dialog_rules_title"])
        self.resize(600, 520)
        self.setMinimumSize(480, 400)

        sp = int(socle_qt.m("space-6"))
        layout = QVBoxLayout(self)
        layout.setContentsMargins(sp, sp, sp, sp)
        layout.setSpacing(int(socle_qt.m("space-3")))

        layout.addWidget(socle_qt.role(QLabel(t["dialog_rules_header"]), "heading"))

        content = QTextBrowser()
        content.document().setDefaultStyleSheet(
            f"h3 {{ color: {socle_qt.c('text-strong')}; font-size: {socle_qt.TOKENS['type']['title']['size']}px;"
            f" margin: 12px 0 4px 0; }}"
            f"ul {{ margin: 0 0 8px 0; }}"
            f"li {{ color: {socle_qt.c('text')}; margin-bottom: 2px; }}"
            f"code {{ color: {socle_qt.c('accent-text')}; }}"
            f".note {{ color: {socle_qt.c('success')}; margin-top: 12px; }}"
        )
        content.setHtml(t["rules_html"])
        layout.addWidget(content, 1)

        row = QHBoxLayout()
        row.addStretch(1)
        close_btn = QPushButton(t["dialog_rules_btn_close"])
        close_btn.setDefault(True)
        close_btn.clicked.connect(self.accept)
        row.addWidget(close_btn)
        layout.addLayout(row)


# ----------------------------------------------------------------------
# Worker Thread pour l'analyse et le nettoyage en arrière-plan
# ----------------------------------------------------------------------
class CleanerWorker(QThread):
    log_signal = pyqtSignal(str)
    status_signal = pyqtSignal(str)
    # mode purge, fichiers, dossiers, erreurs, résumé
    finished_signal = pyqtSignal(bool, int, int, int, str)

    FLUSH_LINES = 200
    FLUSH_SECONDS = 0.1

    def __init__(self, target_dir: str, clean_mode: bool, lang: str = "fr"):
        super().__init__()
        self.target_dir = target_dir
        self.clean_mode = clean_mode
        self.t = tr(lang)
        self._buf: List[str] = []
        self._last_flush = 0.0

    # Journal par paquets : un signal par ligne fige l'interface sur les grosses instances.
    def _log(self, line: str):
        self._buf.append(line)
        if len(self._buf) >= self.FLUSH_LINES or time.monotonic() - self._last_flush > self.FLUSH_SECONDS:
            self._flush()

    def _flush(self):
        if self._buf:
            self.log_signal.emit("<br>".join(self._buf))
            self._buf.clear()
        self._last_flush = time.monotonic()

    def _scan(self) -> Tuple[List[Tuple[str, int]], List[Tuple[str, int]], int]:
        """Parcours descendant : un dossier parasite est retenu en bloc et n'est pas exploré,
        ses fichiers ne sont donc ni comptés ni supprimés deux fois."""
        files_found: List[Tuple[str, int]] = []
        dirs_found: List[Tuple[str, int]] = []
        walk_errors: List[OSError] = []
        for root, dirs, files in os.walk(self.target_dir, onerror=walk_errors.append):
            if self.isInterruptionRequested():
                break
            kept = []
            for d in dirs:
                if DIR_RE.search(d):
                    path = os.path.join(root, d)
                    dirs_found.append((path, tree_size(path)))
                else:
                    kept.append(d)
            dirs[:] = kept
            for f in files:
                if FILE_RE.search(f):
                    path = os.path.join(root, f)
                    try:
                        size = os.lstat(path).st_size
                    except OSError:
                        size = 0
                    files_found.append((path, size))
        return files_found, dirs_found, len(walk_errors)

    def run(self):
        t = self.t
        mode_text = t["worker_mode_clean"] if self.clean_mode else t["worker_mode_sim"]
        self.status_signal.emit(t["worker_processing"].format(mode=mode_text))
        self._log(f"{span('accent-text', t['worker_target'], True)} {html.escape(self.target_dir)}")
        self._log(f"{span('accent-text', t['worker_mode_label'], True)} {mode_text}")
        self._flush()

        files_found, dirs_found, walk_errors = self._scan()
        if walk_errors:
            self._log(span("warning", t["worker_walk_errors"].format(count=walk_errors)))

        if not files_found and not dirs_found:
            self._log("<br>" + span("success", t["worker_no_residues"]))
            self._flush()
            self.finished_signal.emit(self.clean_mode, 0, 0, 0, t["worker_status_clean"])
            return

        total = sum(s for _, s in files_found) + sum(s for _, s in dirs_found)
        summary_det = t["worker_detected_summary"].format(
            files=len(files_found), dirs=len(dirs_found), size=format_size(total, t)
        )
        self._log(f"<br><b>{summary_det}</b><br>")

        rel = lambda p: html.escape(os.path.relpath(p, self.target_dir))
        nbsp = "&nbsp;&nbsp;"
        deleted_files = deleted_dirs = errors = 0

        for path, size in files_found:
            if self.isInterruptionRequested():
                break
            if not self.clean_mode:
                self._log(f"{nbsp}{span('warning', t['worker_tag_detected'])} {rel(path)} ({format_size(size, t)})")
                continue
            try:
                os.remove(path)
                deleted_files += 1
                self._log(f"{nbsp}{span('danger', t['worker_tag_deleted'])} {rel(path)} ({format_size(size, t)})")
            except OSError as err:
                errors += 1
                self._log(f"{nbsp}{span('danger', t['worker_tag_error'], True)} {rel(path)} : {html.escape(str(err))}")

        for dpath, size in dirs_found:
            if self.isInterruptionRequested():
                break
            if not self.clean_mode:
                self._log(f"{nbsp}{span('warning', t['worker_tag_dir_detected'])} {rel(dpath)}/ ({format_size(size, t)})")
                continue
            try:
                # rmtree refuse les liens symboliques : on supprime alors le lien seul.
                if os.path.islink(dpath):
                    os.unlink(dpath)
                else:
                    shutil.rmtree(dpath)
                deleted_dirs += 1
                self._log(f"{nbsp}{span('danger', t['worker_tag_dir_deleted'])} {rel(dpath)}/")
            except OSError as err:
                errors += 1
                self._log(f"{nbsp}{span('danger', t['worker_tag_dir_error'], True)} {rel(dpath)} : {html.escape(str(err))}")

        self._log("")
        if self.clean_mode:
            summary = t["worker_clean_done"].format(files=deleted_files, dirs=deleted_dirs)
            self._log(span("success", f"✓ {summary}"))
            if errors:
                self._log(span("danger", t["worker_clean_errors"].format(count=errors)))
            self._flush()
            self.finished_signal.emit(True, deleted_files, deleted_dirs, errors, summary)
        else:
            summary = t["worker_sim_done"].format(files=len(files_found), dirs=len(dirs_found))
            self._log(span("accent-text", f"✓ {summary}"))
            self._log(span("text-muted", t["worker_sim_hint"].format(btn=t["btn_clean"])))
            self._flush()
            self.finished_signal.emit(False, len(files_found), len(dirs_found), 0, summary)


# ----------------------------------------------------------------------
# Fenêtre Principale PyQt6
# ----------------------------------------------------------------------
class InstanceCleanerApp(QMainWindow):
    def __init__(self):
        super().__init__()
        self.settings = QSettings("FlattenerCleaner", "FlattenerCleaner")
        self.current_lang = self.settings.value("language", "fr")
        if self.current_lang not in TRANSLATIONS:
            self.current_lang = "fr"

        self.resize(920, 640)
        self.setMinimumSize(760, 520)

        icon_path = resource_path("icon.icns")
        if os.path.exists(icon_path):
            self.setWindowIcon(QIcon(icon_path))

        self.worker: CleanerWorker | None = None
        self.busy = False
        self.lang_buttons = {}
        # Dossier et volume de la dernière analyse : la purge n'est proposée qu'après une analyse non vide.
        self.scanned: Tuple[str, int, int] | None = None

        self._init_ui()
        self.retranslate_ui()
        socle_qt.fit_height(self)

    def _panel(self, kind: str = "true") -> QFrame:
        frame = QFrame()
        frame.setProperty("panel", kind)
        return frame

    def _init_ui(self):
        sp2, sp3 = int(socle_qt.m("space-2")), int(socle_qt.m("space-3"))
        central = QWidget()
        self.setCentralWidget(central)
        root = QVBoxLayout(central)
        root.setContentsMargins(sp3, sp3, sp3, sp3)
        root.setSpacing(sp3)

        # 1. En-tête : titre, sélecteur de langue, description
        header = self._panel("raised")
        header_layout = QVBoxLayout(header)
        header_layout.setContentsMargins(sp3, sp3, sp3, sp3)
        header_layout.setSpacing(sp2)

        top = QHBoxLayout()
        top.setSpacing(sp3)
        self.title_label = socle_qt.role(QLabel(), "heading")
        top.addWidget(self.title_label, 1)

        lang_switch = QFrame()
        lang_switch.setObjectName("langSwitch")
        lang_switch.setStyleSheet(
            f"QFrame#langSwitch {{ background-color: {socle_qt.c('bg-sunken')}; border: 1px solid {socle_qt.c('border')};"
            f" border-radius: {socle_qt.m('radius-md')}px; }}"
            f"QFrame#langSwitch QPushButton {{ background: transparent; border: 1px solid transparent; color: {socle_qt.c('text-muted')};"
            f" min-height: 22px; padding: 0 {sp2}px; }}"
            f"QFrame#langSwitch QPushButton:hover {{ background-color: {socle_qt.c('surface-hover')}; color: {socle_qt.c('text-strong')}; }}"
            f"QFrame#langSwitch QPushButton:checked {{ background-color: {socle_qt.c('control')}; color: {socle_qt.c('text-strong')}; }}"
            f"QFrame#langSwitch QPushButton:focus {{ border-color: {socle_qt.c('focus-ring')}; }}"
        )
        lang_layout = QHBoxLayout(lang_switch)
        lang_layout.setContentsMargins(2, 2, 2, 2)
        lang_layout.setSpacing(2)
        group = QButtonGroup(self)
        group.setExclusive(True)
        for code, label in LANGUAGES:
            btn = QPushButton(label)
            btn.setCheckable(True)
            btn.setChecked(code == self.current_lang)
            btn.clicked.connect(lambda _checked, c=code: self._set_language(c))
            self.lang_buttons[code] = btn
            group.addButton(btn)
            lang_layout.addWidget(btn)
        top.addWidget(lang_switch, 0, Qt.AlignmentFlag.AlignRight)
        header_layout.addLayout(top)

        self.subtitle_label = socle_qt.role(QLabel(), "muted")
        self.subtitle_label.setWordWrap(True)
        header_layout.addWidget(self.subtitle_label)
        root.addWidget(header)

        # 2. Dossier cible
        path_panel = self._panel()
        path_layout = QHBoxLayout(path_panel)
        path_layout.setContentsMargins(sp3, sp3, sp3, sp3)
        path_layout.setSpacing(sp2)
        self.path_entry = QLineEdit()
        self.path_entry.textChanged.connect(self._on_path_changed)
        self.browse_btn = QPushButton()
        self.browse_btn.clicked.connect(self._browse_folder)
        path_layout.addWidget(self.path_entry, 1)
        path_layout.addWidget(self.browse_btn)
        root.addWidget(path_panel)

        # 3. Journal
        log_panel = self._panel()
        log_layout = QVBoxLayout(log_panel)
        log_layout.setContentsMargins(sp3, sp3, sp3, sp3)
        log_layout.setSpacing(sp2)
        self.log_title = socle_qt.role(QLabel(), "title")
        self.log_text = QPlainTextEdit()
        self.log_text.setReadOnly(True)
        self._style_log()
        self.log_title.setBuddy(self.log_text)
        log_layout.addWidget(self.log_title)
        log_layout.addWidget(self.log_text, 1)
        root.addWidget(log_panel, 1)

        # 4. Statut et actions : un seul bouton principal (l'analyse)
        actions = self._panel()
        actions_layout = QHBoxLayout(actions)
        actions_layout.setContentsMargins(sp3, sp3, sp3, sp3)
        actions_layout.setSpacing(sp2)
        self.status_label = socle_qt.role(QLabel(), "muted")
        self.status_label.setWordWrap(True)
        self.rules_btn = socle_qt.variant(QPushButton(), "tertiary")
        self.rules_btn.clicked.connect(self._show_rules_dialog)
        self.clean_btn = QPushButton()
        self.clean_btn.clicked.connect(lambda: self._start_operation(clean_mode=True))
        self.scan_btn = socle_qt.variant(QPushButton(), "primary")
        self.scan_btn.setDefault(True)
        self.scan_btn.clicked.connect(lambda: self._start_operation(clean_mode=False))
        actions_layout.addWidget(self.status_label, 1)
        actions_layout.addWidget(self.rules_btn)
        actions_layout.addWidget(self.clean_btn)
        actions_layout.addWidget(self.scan_btn)
        root.addWidget(actions)

        self._update_buttons()

    def retranslate_ui(self):
        t = tr(self.current_lang)
        self.setWindowTitle(t["app_title"])
        self.title_label.setText(t["header_title"])
        self.subtitle_label.setText(t["header_subtitle"])
        self.path_entry.setPlaceholderText(t["path_placeholder"])
        self.browse_btn.setText(t["btn_browse"])
        self.log_title.setText(t["log_title"])
        self.rules_btn.setText(t["btn_rules"])
        self.scan_btn.setText(t["btn_scan"])
        self.clean_btn.setText(t["btn_clean"])
        if not self.busy:
            self._set_status(t["status_loaded"] if self._folder() else t["status_ready"])

    def _style_log(self):
        """Journal en mono-sm (taille Socle)."""
        mono = socle_qt.font("mono-sm")
        self.log_text.setFont(mono)
        self.log_text.setStyleSheet(f"font-family: \"{mono.family()}\"; font-size: {mono.pixelSize()}px;"
                                    f" color: {socle_qt.c('text-muted')};")

    # ------------------------------------------------------------------ état
    def _folder(self) -> str:
        """Dossier saisi s'il existe, sinon chaîne vide."""
        folder = self.path_entry.text().strip()
        return folder if folder and os.path.isdir(folder) else ""

    def _set_status(self, text: str, state: str = "none"):
        self.status_label.setText(text)
        socle_qt.status(self.status_label, state)

    def _update_buttons(self):
        busy = self.busy
        for w in (self.path_entry, self.browse_btn, self.rules_btn, self.scan_btn, *self.lang_buttons.values()):
            w.setEnabled(not busy)
        ready = self.scanned is not None and self.scanned[0] == self.path_entry.text().strip()
        self.clean_btn.setEnabled(not busy and ready)

    def _on_path_changed(self, _text: str):
        if self.scanned and self.scanned[0] != self.path_entry.text().strip():
            self.scanned = None
        self._update_buttons()

    def _set_language(self, lang_code: str):
        if lang_code and lang_code != self.current_lang:
            self.current_lang = lang_code
            self.settings.setValue("language", lang_code)
            self.retranslate_ui()

    # ------------------------------------------------------------------ actions
    def _browse_folder(self):
        t = tr(self.current_lang)
        folder = QFileDialog.getExistingDirectory(self, t["dialog_choose_dir"], self.path_entry.text().strip())
        if folder:
            self.path_entry.setText(folder)
            self.log_text.clear()
            self._append_log(f"{t['log_selected_dir']}{span('accent-text', html.escape(folder))}")
            self._set_status(t["status_loaded"])

    def _append_log(self, text: str):
        self.log_text.appendHtml(text)
        bar = self.log_text.verticalScrollBar()
        bar.setValue(bar.maximum())

    def _show_rules_dialog(self):
        FiltersDialog(self.current_lang, self).exec()

    def _confirm_clean(self) -> bool:
        t = tr(self.current_lang)
        _, files, dirs = self.scanned
        box = QMessageBox(self)
        box.setIcon(QMessageBox.Icon.Warning)
        box.setWindowTitle(t["confirm_clean_title"])
        box.setText(t["confirm_clean_msg"].format(files=files, dirs=dirs))
        delete_btn = box.addButton(t["btn_confirm_clean"], QMessageBox.ButtonRole.DestructiveRole)
        cancel_btn = box.addButton(t["btn_cancel"], QMessageBox.ButtonRole.RejectRole)
        box.setDefaultButton(cancel_btn)
        box.exec()
        return box.clickedButton() is delete_btn

    def _start_operation(self, clean_mode: bool):
        t = tr(self.current_lang)
        folder = self._folder()
        if not folder:
            QMessageBox.warning(self, t["warn_missing_dir_title"], t["warn_missing_dir_msg"].format(btn=t["btn_browse"]))
            return
        if clean_mode and not self._confirm_clean():
            return

        self.log_text.clear()
        if self.worker is not None:
            self.worker.wait()  # thread précédent : déjà terminé, on attend sa sortie de run()
        self.busy = True
        self.worker = CleanerWorker(folder, clean_mode, self.current_lang)
        self.worker.log_signal.connect(self._append_log)
        self.worker.status_signal.connect(self._set_status)
        self.worker.finished_signal.connect(self._on_worker_finished)
        self.worker.start()
        self._update_buttons()

    def _on_worker_finished(self, clean_mode: bool, files: int, dirs: int, errors: int, summary: str):
        t = tr(self.current_lang)
        folder = self.path_entry.text().strip()
        self.scanned = (folder, files, dirs) if not clean_mode and (files or dirs) else None
        self.busy = False
        self._update_buttons()
        if clean_mode:
            self._set_status(summary, "danger" if errors else "success")
            text = summary + ("\n\n" + t["worker_clean_errors"].format(count=errors) if errors else "")
            QMessageBox.information(self, t["clean_complete_title"], text)
        else:
            self._set_status(summary, "success" if not (files or dirs) else "none")

    def closeEvent(self, event):
        # Ne pas interrompre brutalement une suppression : on arrête proprement le thread.
        if self.worker is not None and self.worker.isRunning():
            self.worker.requestInterruption()
            self.worker.wait()
        super().closeEvent(event)


def main():
    app = QApplication(sys.argv)
    socle_qt.apply(app)  # design system Socle (feuille complète)
    window = InstanceCleanerApp()
    window.show()
    update_check.start_qt(window, "fCLEANER", lang=lambda: window.current_lang)  # nouvelle version ? (au plus une fois par jour)
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
