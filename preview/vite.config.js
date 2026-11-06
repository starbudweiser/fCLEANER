import { defineConfig } from "vite";
import { execFileSync } from "node:child_process";
import { resolve } from "node:path";

const ROOT = __dirname;
const PROJECT = resolve(ROOT, "..");
const WATCHED = [resolve(PROJECT, "macos/Sources"), resolve(PROJECT, "i18n")];
const SOCLE = "/Volumes/SKYRIM/TOOLS/DESIGN/Socle";
const VIRTUAL_ID = "virtual:app-data";
const RESOLVED_ID = "\0" + VIRTUAL_ID;

// Expose les traductions (i18n/strings.json), les motifs et les règles de l'appli Swift (lus dans les sources, sans
// exécution) et recharge la preview à chaque modification.
function appSources() {
  return {
    name: "app-sources",
    resolveId(id) {
      if (id === VIRTUAL_ID) return RESOLVED_ID;
    },
    load(id) {
      if (id !== RESOLVED_ID) return;
      const json = execFileSync("python3", ["-I", resolve(ROOT, "tools/extract.py"), PROJECT], { encoding: "utf-8" });
      return `export default ${json};`;
    },
    configureServer(server) {
      for (const d of WATCHED) server.watcher.add(d); // chokidar 4 (Vite 6) n'accepte plus les globs
      server.watcher.on("change", (file) => {
        if (!WATCHED.some((d) => file.startsWith(d)) || !/\.(swift|json)$/.test(file)) return;
        const mod = server.moduleGraph.getModuleById(RESOLVED_ID);
        if (mod) server.moduleGraph.invalidateModule(mod);
        server.ws.send({ type: "full-reload" });
      });
    },
  };
}

export default defineConfig({
  plugins: [appSources()],
  resolve: { alias: { "@socle": SOCLE } },
  server: { port: Number(process.env.PORT) || 5175, fs: { allow: [ROOT, SOCLE] } },
});
