// fCLEANER — preview web de l'appli Swift (ContentView + Job.swift).
import "./chrome.css";
import "./cleaner.css";
import data from "virtual:app-data";
import { esc, sleep, messageBox, dialog, filePicker, STD } from "./qt.js";
import { MockFS, relpath } from "./mockfs.js";

const { strings: STRINGS, filePatterns, dirPatterns, rules: RULES, note: NOTE } = data.cleaner;
const LANGS = ["fr", "en", "it", "es"];
const INDEX = { en: 0, it: 1, es: 2 };
// Comme FILE_RE / DIR_RE côté Python : une seule expression par catégorie.
const combine = (pats) => new RegExp(pats.map((p) => `(?:${p.source})`).join("|"), "i");
const FILE_RE = combine(filePatterns);
const DIR_RE = combine(dirPatterns);

// Dossiers de démonstration proposés par « Parcourir »
const DEMO = {
  "/Volumes/SKYRIM/Instances/Skyrim Assembled": [
    { path: "Data/Skyrim.esm", size: 249_036_800 },
    { path: "Data/textures/actors/character/female/femalebody_1.dds", size: 22_369_776 },
    { path: "Data/textures/actors/character/female/femalebody_1 - copy.dds", size: 22_369_776 },
    { path: "Data/textures/landscape/dirt02.dds", size: 5_592_528 },
    { path: "Data/textures/landscape/thumbs.db", size: 18_432 },
    { path: "Data/textures/landscape/dirt02.psd", size: 31_457_280 },
    { path: "Data/meshes/armor/iron/cuirass.nif", size: 412_311 },
    { path: "Data/meshes/armor/iron/cuirass.nif.bak", size: 412_311 },
    { path: "Data/meshes/armor/iron/desktop.ini", size: 282 },
    { path: "Data/SKSE/Plugins/EngineFixes.toml", size: 6_120 },
    { path: "Data/SKSE/Plugins/EngineFixes.toml.tmp", size: 6_120 },
    { path: "Data/SKSE/Plugins/readme.txt", size: 3_410 },
    { path: "Data/SKSE/Plugins/settings.txt", size: 980 },
    { path: "Data/Interface/Translations/SkyUI_FRENCH.txt", size: 21_008 },
    { path: "Data/Unofficial Skyrim Patch - Changelog.rtf", size: 801_225 },
    { path: "Data/Docs.mohidden/Guide.docx", size: 412_000 },
    { path: "Data/OldPlugin.esp.mohidden", size: 102_400 },
    { path: "Data/modgroups/Main.modgroups", size: 1_204 },
    { path: "Data/textures/effects/dummy texture.dds", size: 2_048 },
    { path: "Data/scripts/source/MyQuestScript.psc", size: 4_120 },
    { path: "Data/scripts/MyQuestScript.pex", size: 3_288 },
    { path: "Data/meshes/clutter - copie/", size: 0 },
    { path: "Data/meshes/clutter - copie/bucket.nif", size: 88_120 },
    { path: "LICENSE.md", size: 1_068 },
    { path: "Data/.DS_Store", size: 6_148 },
  ],
  "/Volumes/SKYRIM/Collections/Lorerim (Vortex)": [
    { path: "collection.json", size: 184_220 },
    { path: "manifest.json", size: 2_304 },
    { path: "vortex.deployment.json", size: 912_400 },
    { path: "__folder_managed_by_vortex", size: 0 },
    { path: "Data/ActiveMods.json.vortex_backup", size: 12_400 },
    { path: "Data/Engine.log.vortex_backup", size: 44_100 },
    { path: "Data/meshes/weapons/sword.nif", size: 220_400 },
    { path: "Data/meshes/weapons/sword.nif.vortex_lnk", size: 120 },
    { path: "Data/SKSE/Plugins/po3_Tweaks.ini", size: 2_200 },
    { path: "Data/SKSE/Plugins/EULA.txt", size: 6_800, locked: true },
    { path: "__vortex_staging_tmp/", size: 0 },
    { path: "__vortex_staging_tmp/patch.esp", size: 40_960 },
    { path: ".vortex_staging/", size: 0 },
    { path: "Data/textures/sky/aurora.xcf", size: 18_200_000 },
    { path: "Data/textures/sky/aurora.dds", size: 4_194_432 },
  ],
  "/Volumes/SKYRIM/Instances/Clean Build": [
    { path: "Data/Skyrim.esm", size: 249_036_800 },
    { path: "Data/SKSE/Plugins/settings.txt", size: 980 },
    { path: "Data/textures/landscape/dirt02.dds", size: 5_592_528 },
  ],
};
const DEMO_NAMES = {
  fr: ["Instance assemblée (résidus MO2, sauvegardes, doublons)", "Collection Nexus (résidus Vortex, un fichier verrouillé)", "Instance déjà propre"],
  en: ["Assembled instance (MO2 leftovers, backups, duplicates)", "Nexus collection (Vortex leftovers, one locked file)", "Already clean instance"],
  it: ["Istanza assemblata (residui MO2, backup, duplicati)", "Collezione Nexus (residui Vortex, un file bloccato)", "Istanza già pulita"],
  es: ["Instancia ensamblada (residuos MO2, copias, duplicados)", "Colección Nexus (residuos Vortex, un archivo bloqueado)", "Instancia ya limpia"],
};

const fs = new MockFS(DEMO);
const $ = (id) => document.getElementById(id);
const host = $("host");
const ui = {
  title: $("title"), subtitle: $("subtitle"), path: $("path"), browse: $("browse"), logTitle: $("logTitle"),
  log: $("log"), status: $("status"), rules: $("rules"), scan: $("scan"), clean: $("clean"),
};

// Langue : l'appli la choisit dans son menu « Langue » (barre de menus macOS) ; la preview suit le navigateur,
// ou le paramètre ?lang=fr|en|es|it pour les essais.
const systemLang = () =>
  (navigator.languages || [navigator.language]).map((l) => (l || "").slice(0, 2).toLowerCase()).find((c) => LANGS.includes(c)) ?? "en";
const askedLang = new URLSearchParams(location.search).get("lang");
const currentLang = LANGS.includes(askedLang) ? askedLang : systemLang();
let busy = false;
let scanned = null; // [dossier, fichiers, dossiers] de la dernière analyse non vide
const fmt = (s, vars) => s.replace(/\{(\w+)\}/g, (m, k) => (k in vars ? vars[k] : m));
/** Le texte français sert de clé (comme L() dans l'appli) : traduction de la langue active, sinon le français. */
const L = (text, vars = {}) => fmt(currentLang === "fr" ? text : STRINGS[text]?.[INDEX[currentLang]] || text, vars);
const std = () => STD[currentLang] ?? STD.fr;
const span = (cls, text) => `<span class="${cls}">${text}</span>`;
const NBSP = "&nbsp;&nbsp;";

// ------------------------------------------------------------------ UI
const folder = () => {
  const f = ui.path.value.trim();
  return f && fs.isDir(f) ? f : "";
};

function setStatus(text, state = "none") {
  ui.status.textContent = text;
  ui.status.dataset.status = state;
}

function updateButtons() {
  for (const el of [ui.path, ui.browse, ui.rules, ui.scan]) el.disabled = busy;
  ui.clean.disabled = busy || !(scanned && scanned[0] === ui.path.value.trim());
}

function retranslateUi() {
  document.documentElement.lang = currentLang;
  $("wtitle").textContent = L("fCLEANER – Nettoyeur d'instance");
  ui.title.textContent = "🧹 fCLEANER";
  ui.subtitle.textContent = L("Purge les résidus d'assemblage d'une instance ou d'une collection (MO2, Vortex, Nexus) : métadonnées, modgroups xEdit, caches système, sauvegardes (.BAK), doublons, documents bureautiques, sources graphiques (.PSD, .XCF, .PDN), lisez-moi et licences.");
  ui.path.placeholder = L("Choisissez le dossier assemblé ou la collection à nettoyer.");
  ui.browse.textContent = L("Choisir un dossier");
  ui.logTitle.textContent = L("Journal");
  ui.rules.textContent = L("Règles de filtrage");
  ui.scan.textContent = L("ANALYSER");
  ui.clean.textContent = L("Purger les résidus");
  if (!busy) setStatus(folder() ? L("Dossier prêt. Lancez l'analyse.") : L("Choisissez un dossier pour commencer."));
}

function appendLog(html) {
  const p = document.createElement("p");
  p.innerHTML = html;
  ui.log.append(p);
  ui.log.scrollTop = ui.log.scrollHeight;
}

async function browseFolder() {
  const names = DEMO_NAMES[currentLang] ?? DEMO_NAMES.fr;
  const chosen = await filePicker(host, {
    title: L("Choisir le dossier à nettoyer"),
    choices: Object.keys(DEMO).map((path, i) => ({ name: names[i], path })),
    labels: std(),
    buttonClass: "cl-btn",
  });
  if (chosen) {
    ui.path.value = chosen;
    onPathChanged();
    ui.log.innerHTML = "";
    appendLog(`${L("📁 Dossier sélectionné : ")}${span("is-path", esc(chosen))}`);
    setStatus(L("Dossier prêt. Lancez l'analyse."));
  }
}

function onPathChanged() {
  if (scanned && scanned[0] !== ui.path.value.trim()) scanned = null;
  updateButtons();
}

// Feuille du QTextBrowser (document().setDefaultStyleSheet) ; les variables Socle traversent le shadow root.
const RULES_CSS = `
  :host { display: block; font: 12px/1.5 var(--font-sans); color: var(--text); }
  h3 { color: var(--text-strong); font-size: 14px; margin: 12px 0 4px; }
  h3:first-child { margin-top: 0; }
  ul { margin: 0 0 8px; padding-left: 20px; }
  li { margin-bottom: 2px; }
  code { font-family: var(--font-mono); color: var(--accent-text); }
  .note { color: var(--success); margin: 12px 0 0; }`;

const inline = (x) => esc(x).replace(/`(.*?)`/g, "<code>$1</code>").replace(/\*\*(.*?)\*\*/g, "<b>$1</b>");
const rulesHtml = () =>
  RULES.map((r) => `<h3>${esc(L(r.title))}</h3><ul>${r.items.map((i) => `<li>${inline(L(i))}</li>`).join("")}</ul>`).join("") +
  `<p class="note">${inline(L(NOTE))}</p>`;

function showRulesDialog() {
  const wrap = document.createElement("div");
  wrap.style.cssText = "display:flex;flex-direction:column;gap:12px;min-height:0;flex:1";
  const head = document.createElement("h2");
  head.className = "cl-rules-head";
  head.textContent = L("📋 Éléments ciblés par la purge");
  const box = document.createElement("div");
  box.className = "cl-rules";
  box.attachShadow({ mode: "open" }).innerHTML = `<style>${RULES_CSS}</style>${L("\n            <h3>1. Caches et fichiers système</h3>\n            <ul>\n                <li><code>thumbs.db</code> (miniatures Windows)</li>\n                <li><code>desktop.ini</code> (réglages de dossier Windows)</li>\n                <li><code>.DS_Store</code> (métadonnées macOS)</li>\n            </ul>\n            <h3>2. Mod Organizer 2</h3>\n            <ul>\n                <li>Fichiers et dossiers masqués : <code>*.mohidden</code></li>\n            </ul>\n            <h3>3. xEdit (SSEEdit / FO4Edit)</h3>\n            <ul>\n                <li>Groupes de mods : <code>*.modgroups</code>, <code>modgroups.json</code></li>\n                <li>Dossiers : <code>modgroups/</code></li>\n            </ul>\n            <h3>4. Vortex et collections Nexus Mods</h3>\n            <ul>\n                <li>Déploiement : <code>vortex.deployment.json</code></li>\n                <li>Marqueurs : <code>folder_managed_by_vortex</code>, <code>__folder_managed_by_vortex</code></li>\n                <li>Sauvegardes : <code>ActiveMods.json.vortex_backup</code>, <code>Engine.log.vortex_backup</code>, <code>*.vortex_backup*</code></li>\n                <li>Liens symboliques résiduels : <code>*.vortex_lnk</code></li>\n                <li>Métadonnées Nexus : <code>collection.json</code>, <code>collection.meta</code>, <code>manifest.json</code></li>\n                <li>Dossiers temporaires : <code>__vortex_*</code>, <code>.vortex_staging/</code></li>\n            </ul>\n            <h3>5. Sauvegardes, temporaires et doublons</h3>\n            <ul>\n                <li>Sauvegardes : <code>*.bak</code>, <code>*.tmp</code>, <code>*.crdownload</code></li>\n                <li>Copies de fichiers : <code> - copy.*</code>, <code> - copie.*</code>, <code> - copia.*</code></li>\n                <li>Dossiers doublons : <code> - copy</code>, <code> - copie</code>, <code> - copia</code></li>\n            </ul>\n            <h3>6. Documents bureautiques</h3>\n            <ul>\n                <li>Traitements de texte : <code>*.doc</code>, <code>*.docx</code>, <code>*.rtf</code>, <code>*.odt</code></li>\n            </ul>\n            <h3>7. Sources graphiques et fichiers factices</h3>\n            <ul>\n                <li>Projets graphiques : <code>*.pdn</code>, <code>*.xcf</code>, <code>*.psd</code></li>\n                <li>Textures de test : <code>dummy texture.dds</code>, <code>faketexture.dds</code></li>\n            </ul>\n            <h3>8. Documentation et licences uniquement</h3>\n            <ul>\n                <li>Notices : <code>readme</code>, <code>read_me</code>, <code>lisezmoi</code>, <code>instructions</code>, <code>changelog</code> (.txt/.md)</li>\n                <li>Licences : <code>license</code>, <code>licence</code>, <code>eula</code>, <code>copying</code> (.txt/.md)</li>\n            </ul>\n            <p class=\"note\"><b>Protégé :</b> tous les autres fichiers <code>.txt</code> de configuration des mods sont conservés.</p>\n        ")}`;
  wrap.append(head, box);
  const dlgPromise = dialog(host, {
    title: L("Règles de filtrage"),
    body: wrap,
    maxWidth: "600px",
    buttons: [{ label: L("Fermer"), value: true }],
    buttonClass: "cl-btn",
  });
  const dlg = wrap.parentElement;
  dlg.style.height = "min(520px, 100%)";
  dlg.style.padding = "var(--space-6)";
  return dlgPromise;
}

// ------------------------------------------------------------------ CleanerWorker
function formatSize(bytes) {
  if (bytes < 1024) return `${bytes} ${L("octets")}`;
  if (bytes < 1024 ** 2) return `${(bytes / 1024).toFixed(1)} ${L("Ko")}`;
  if (bytes < 1024 ** 3) return `${(bytes / 1024 ** 2).toFixed(2)} ${L("Mo")}`;
  return `${(bytes / 1024 ** 3).toFixed(2)} ${L("Go")}`;
}

function treeSize(dir) {
  let total = 0;
  for (const [root, , files] of fs.walk(dir, true)) for (const f of files) total += fs.file(`${root}/${f}`)?.size ?? 0;
  return total;
}

/** Parcours descendant : un dossier parasite est retenu en bloc et n'est pas exploré. */
function scan(targetDir) {
  const filesFound = [];
  const dirsFound = [];
  for (const [root, dirs, files] of fs.walk(targetDir, true)) {
    const kept = [];
    for (const d of dirs) {
      if (DIR_RE.test(d)) dirsFound.push([`${root}/${d}`, treeSize(`${root}/${d}`)]);
      else kept.push(d);
    }
    dirs.splice(0, dirs.length, ...kept); // comme dirs[:] = kept
    for (const f of files) if (FILE_RE.test(f)) filesFound.push([`${root}/${f}`, fs.file(`${root}/${f}`)?.size ?? 0]);
  }
  return [filesFound, dirsFound];
}

async function runWorker(targetDir, cleanMode) {
  const log = async (html) => { appendLog(html); await sleep(18); };
  const modeText = cleanMode ? L("PURGE") : L("SIMULATION, aucune modification");
  setStatus(fmt(L("Traitement en cours ({mode})…"), { mode: modeText }));
  await log(`${span("is-head", L("Dossier :"))} ${esc(targetDir)}`);
  await log(`${span("is-head", L("Mode :"))} ${modeText}`);
  await sleep(350); // parcours du disque

  const [filesFound, dirsFound] = scan(targetDir);
  if (!filesFound.length && !dirsFound.length) {
    await log(`<br>${span("is-ok", L("✓ Aucun résidu détecté. Le dossier est propre."))}`);
    return [cleanMode, 0, 0, 0, L("Analyse terminée : aucun résidu.")];
  }

  const total = [...filesFound, ...dirsFound].reduce((s, [, size]) => s + size, 0);
  await log(`<br><b>${fmt(L("Détectés : {files} fichier(s), {dirs} dossier(s), {size}"), { files: filesFound.length, dirs: dirsFound.length, size: formatSize(total) })}</b><br>`);

  const rel = (p) => esc(relpath(p, targetDir));
  let deletedFiles = 0, deletedDirs = 0, errors = 0;
  for (const [path, size] of filesFound) {
    if (!cleanMode) { await log(`${NBSP}${span("is-warn", L("[DÉTECTÉ]"))} ${rel(path)} (${formatSize(size)})`); continue; }
    try {
      fs.remove(path);
      deletedFiles++;
      await log(`${NBSP}${span("is-err", L("[SUPPRIMÉ]"))} ${rel(path)} (${formatSize(size)})`);
    } catch (err) {
      errors++;
      await log(`${NBSP}<b>${span("is-err", L("[ERREUR]"))}</b> ${rel(path)} : ${esc(err.message)}`);
    }
  }
  for (const [dpath, size] of dirsFound) {
    if (!cleanMode) { await log(`${NBSP}${span("is-warn", L("[DOSSIER DÉTECTÉ]"))} ${rel(dpath)}/ (${formatSize(size)})`); continue; }
    try {
      fs.rmtree(dpath);
      deletedDirs++;
      await log(`${NBSP}${span("is-err", L("[DOSSIER SUPPRIMÉ]"))} ${rel(dpath)}/`);
    } catch (err) {
      errors++;
      await log(`${NBSP}<b>${span("is-err", L("[ERREUR DOSSIER]"))}</b> ${rel(dpath)} : ${esc(err.message)}`);
    }
  }

  await log("");
  if (cleanMode) {
    const summary = fmt(L("Purge terminée : {files} fichier(s) et {dirs} dossier(s) supprimés."), { files: deletedFiles, dirs: deletedDirs });
    await log(span("is-ok", `✓ ${summary}`));
    if (errors) await log(span("is-err", fmt(L("Erreur : {count} élément(s) n'ont pas pu être supprimés. Vérifiez qu'ils ne sont pas ouverts ou protégés."), { count: errors })));
    return [true, deletedFiles, deletedDirs, errors, summary];
  }
  const summary = fmt(L("Analyse terminée : {files} fichier(s) et {dirs} dossier(s) à purger."), { files: filesFound.length, dirs: dirsFound.length });
  await log(span("is-info", `✓ ${summary}`));
  await log(fmt(L("Rien n'a été supprimé. Cliquez sur « {btn} » pour les supprimer."), { btn: esc(L("Purger les résidus")) }));
  return [false, filesFound.length, dirsFound.length, 0, summary];
}

async function confirmClean() {
  const [, files, dirs] = scanned;
  const reply = await messageBox(host, { kind: "warning", title: L("Purger les résidus"), text: fmt(L("Supprimer définitivement {files} fichier(s) et {dirs} dossier(s) détectés ?\n\nLes autres fichiers .TXT des mods ne sont pas touchés. Cette opération est irréversible."), { files, dirs }),
    buttons: [{ label: L("Supprimer"), value: true }, { label: L("Annuler"), value: false, default: true }], buttonClass: "cl-btn" });
  return reply === true;
}

async function startOperation(cleanMode) {
  const target = folder();
  if (!target) {
    await messageBox(host, { kind: "warning", title: L("Dossier introuvable"), text: fmt(L("Ce dossier n'existe pas ou n'est plus accessible. Choisissez-en un autre avec « {btn} »."), { btn: L("Choisir un dossier") }),
      buttons: [{ label: std().ok, value: true, default: true }], buttonClass: "cl-btn" });
    return;
  }
  if (cleanMode && !(await confirmClean())) return;

  ui.log.innerHTML = "";
  busy = true;
  updateButtons();
  const [wasClean, files, dirs, errors, summary] = await runWorker(target, cleanMode);
  scanned = !wasClean && (files || dirs) ? [ui.path.value.trim(), files, dirs] : null;
  busy = false;
  updateButtons();
  if (wasClean) {
    setStatus(summary, errors ? "danger" : "success");
    const text = errors ? `${summary}\n\n${fmt(L("Erreur : {count} élément(s) n'ont pas pu être supprimés. Vérifiez qu'ils ne sont pas ouverts ou protégés."), { count: errors })}` : summary;
    await messageBox(host, { kind: "information", title: L("Purge terminée"), text,
      buttons: [{ label: std().ok, value: true, default: true }], buttonClass: "cl-btn" });
  } else {
    setStatus(summary, files || dirs ? "none" : "success");
  }
}

ui.path.addEventListener("input", onPathChanged);
ui.browse.addEventListener("click", browseFolder);
ui.rules.addEventListener("click", showRulesDialog);
ui.scan.addEventListener("click", () => startOperation(false));
ui.clean.addEventListener("click", () => startOperation(true));
$("pv-reset").addEventListener("click", () => {
  fs.reset();
  ui.path.value = "";
  scanned = null;
  ui.log.innerHTML = "";
  updateButtons();
  retranslateUi();
});

updateButtons();
retranslateUi();
