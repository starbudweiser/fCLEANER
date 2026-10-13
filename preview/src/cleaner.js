// fCLEANER — preview web de src/flattener_cleaner.py (InstanceCleanerApp + CleanerWorker).
import "./chrome.css";
import "./cleaner.css";
import data from "virtual:app-data";
import { esc, sleep, settings, messageBox, dialog, filePicker, STD } from "./qt.js";
import { MockFS, relpath } from "./mockfs.js";

const { translations: TRANSLATIONS, languages: LANGUAGES, filePatterns, dirPatterns } = data.cleaner;
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
const store = settings("fCLEANER");
const $ = (id) => document.getElementById(id);
const host = $("host");
const ui = {
  title: $("title"), subtitle: $("subtitle"), path: $("path"), browse: $("browse"), logTitle: $("logTitle"),
  log: $("log"), status: $("status"), rules: $("rules"), scan: $("scan"), clean: $("clean"), langs: $("langs"),
};

let currentLang = store.value("language", "fr");
if (!(currentLang in TRANSLATIONS)) currentLang = "fr";
let busy = false;
let scanned = null; // [dossier, fichiers, dossiers] de la dernière analyse non vide
const tr = () => TRANSLATIONS[currentLang] ?? TRANSLATIONS.fr;
const std = () => STD[currentLang] ?? STD.fr;
const fmt = (s, vars) => s.replace(/\{(\w+)\}/g, (m, k) => (k in vars ? vars[k] : m));
const span = (cls, text) => `<span class="${cls}">${text}</span>`;
const NBSP = "&nbsp;&nbsp;";

// ------------------------------------------------------------------ UI
const langButtons = {};
for (const [code, label] of LANGUAGES) {
  const b = document.createElement("button");
  b.className = "cl-seg";
  b.textContent = label;
  b.addEventListener("click", () => setLanguage(code));
  langButtons[code] = b;
  ui.langs.append(b);
}

const folder = () => {
  const f = ui.path.value.trim();
  return f && fs.isDir(f) ? f : "";
};

function setStatus(text, state = "none") {
  ui.status.textContent = text;
  ui.status.dataset.status = state;
}

function updateButtons() {
  for (const el of [ui.path, ui.browse, ui.rules, ui.scan, ...Object.values(langButtons)]) el.disabled = busy;
  ui.clean.disabled = busy || !(scanned && scanned[0] === ui.path.value.trim());
}

function retranslateUi() {
  const t = tr();
  document.documentElement.lang = currentLang;
  $("wtitle").textContent = t.app_title;
  ui.title.textContent = t.header_title;
  ui.subtitle.textContent = t.header_subtitle;
  ui.path.placeholder = t.path_placeholder;
  ui.browse.textContent = t.btn_browse;
  ui.logTitle.textContent = t.log_title;
  ui.rules.textContent = t.btn_rules;
  ui.scan.textContent = t.btn_scan;
  ui.clean.textContent = t.btn_clean;
  for (const [code, b] of Object.entries(langButtons)) b.setAttribute("aria-pressed", String(code === currentLang));
  if (!busy) setStatus(folder() ? t.status_loaded : t.status_ready);
}

function setLanguage(code) {
  if (code && code !== currentLang) {
    currentLang = code;
    store.setValue("language", code);
    retranslateUi();
  }
}

function appendLog(html) {
  const p = document.createElement("p");
  p.innerHTML = html;
  ui.log.append(p);
  ui.log.scrollTop = ui.log.scrollHeight;
}

async function browseFolder() {
  const t = tr();
  const names = DEMO_NAMES[currentLang] ?? DEMO_NAMES.fr;
  const chosen = await filePicker(host, {
    title: t.dialog_choose_dir,
    choices: Object.keys(DEMO).map((path, i) => ({ name: names[i], path })),
    labels: std(),
    buttonClass: "cl-btn",
  });
  if (chosen) {
    ui.path.value = chosen;
    onPathChanged();
    ui.log.innerHTML = "";
    appendLog(`${t.log_selected_dir}${span("is-path", esc(chosen))}`);
    setStatus(t.status_loaded);
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

function showRulesDialog() {
  const t = tr();
  const wrap = document.createElement("div");
  wrap.style.cssText = "display:flex;flex-direction:column;gap:12px;min-height:0;flex:1";
  const head = document.createElement("h2");
  head.className = "cl-rules-head";
  head.textContent = t.dialog_rules_header;
  const box = document.createElement("div");
  box.className = "cl-rules";
  box.attachShadow({ mode: "open" }).innerHTML = `<style>${RULES_CSS}</style>${t.rules_html}`;
  wrap.append(head, box);
  const dlgPromise = dialog(host, {
    title: t.dialog_rules_title,
    body: wrap,
    maxWidth: "600px",
    buttons: [{ label: t.dialog_rules_btn_close, value: true }],
    buttonClass: "cl-btn",
  });
  const dlg = wrap.parentElement;
  dlg.style.height = "min(520px, 100%)";
  dlg.style.padding = "var(--space-6)";
  return dlgPromise;
}

// ------------------------------------------------------------------ CleanerWorker
function formatSize(bytes, t) {
  if (bytes < 1024) return `${bytes} ${t.unit_bytes}`;
  if (bytes < 1024 ** 2) return `${(bytes / 1024).toFixed(1)} ${t.unit_kb}`;
  if (bytes < 1024 ** 3) return `${(bytes / 1024 ** 2).toFixed(2)} ${t.unit_mb}`;
  return `${(bytes / 1024 ** 3).toFixed(2)} ${t.unit_gb}`;
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
  const t = tr();
  const log = async (html) => { appendLog(html); await sleep(18); };
  const modeText = cleanMode ? t.worker_mode_clean : t.worker_mode_sim;
  setStatus(fmt(t.worker_processing, { mode: modeText }));
  await log(`${span("is-head", t.worker_target)} ${esc(targetDir)}`);
  await log(`${span("is-head", t.worker_mode_label)} ${modeText}`);
  await sleep(350); // parcours du disque

  const [filesFound, dirsFound] = scan(targetDir);
  if (!filesFound.length && !dirsFound.length) {
    await log(`<br>${span("is-ok", t.worker_no_residues)}`);
    return [cleanMode, 0, 0, 0, t.worker_status_clean];
  }

  const total = [...filesFound, ...dirsFound].reduce((s, [, size]) => s + size, 0);
  await log(`<br><b>${fmt(t.worker_detected_summary, { files: filesFound.length, dirs: dirsFound.length, size: formatSize(total, t) })}</b><br>`);

  const rel = (p) => esc(relpath(p, targetDir));
  let deletedFiles = 0, deletedDirs = 0, errors = 0;
  for (const [path, size] of filesFound) {
    if (!cleanMode) { await log(`${NBSP}${span("is-warn", t.worker_tag_detected)} ${rel(path)} (${formatSize(size, t)})`); continue; }
    try {
      fs.remove(path);
      deletedFiles++;
      await log(`${NBSP}${span("is-err", t.worker_tag_deleted)} ${rel(path)} (${formatSize(size, t)})`);
    } catch (err) {
      errors++;
      await log(`${NBSP}<b>${span("is-err", t.worker_tag_error)}</b> ${rel(path)} : ${esc(err.message)}`);
    }
  }
  for (const [dpath, size] of dirsFound) {
    if (!cleanMode) { await log(`${NBSP}${span("is-warn", t.worker_tag_dir_detected)} ${rel(dpath)}/ (${formatSize(size, t)})`); continue; }
    try {
      fs.rmtree(dpath);
      deletedDirs++;
      await log(`${NBSP}${span("is-err", t.worker_tag_dir_deleted)} ${rel(dpath)}/`);
    } catch (err) {
      errors++;
      await log(`${NBSP}<b>${span("is-err", t.worker_tag_dir_error)}</b> ${rel(dpath)} : ${esc(err.message)}`);
    }
  }

  await log("");
  if (cleanMode) {
    const summary = fmt(t.worker_clean_done, { files: deletedFiles, dirs: deletedDirs });
    await log(span("is-ok", `✓ ${summary}`));
    if (errors) await log(span("is-err", fmt(t.worker_clean_errors, { count: errors })));
    return [true, deletedFiles, deletedDirs, errors, summary];
  }
  const summary = fmt(t.worker_sim_done, { files: filesFound.length, dirs: dirsFound.length });
  await log(span("is-info", `✓ ${summary}`));
  await log(fmt(t.worker_sim_hint, { btn: esc(t.btn_clean) }));
  return [false, filesFound.length, dirsFound.length, 0, summary];
}

async function confirmClean() {
  const t = tr();
  const [, files, dirs] = scanned;
  const reply = await messageBox(host, { kind: "warning", title: t.confirm_clean_title, text: fmt(t.confirm_clean_msg, { files, dirs }),
    buttons: [{ label: t.btn_confirm_clean, value: true }, { label: t.btn_cancel, value: false, default: true }], buttonClass: "cl-btn" });
  return reply === true;
}

async function startOperation(cleanMode) {
  const t = tr();
  const target = folder();
  if (!target) {
    await messageBox(host, { kind: "warning", title: t.warn_missing_dir_title, text: fmt(t.warn_missing_dir_msg, { btn: t.btn_browse }),
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
    const text = errors ? `${summary}\n\n${fmt(tr().worker_clean_errors, { count: errors })}` : summary;
    await messageBox(host, { kind: "information", title: tr().clean_complete_title, text,
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
