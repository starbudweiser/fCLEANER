// Analyse (simulation) ou purge d'un dossier, avec le journal : mêmes étapes et mêmes textes que CleanerWorker.run (Python).

import Foundation

public enum Tone: Sendable { case plain, accent, warning, danger, success, muted }

public struct Seg: Equatable, Sendable {
    public var text: String
    public var tone: Tone
    public var bold: Bool
    public init(_ text: String, _ tone: Tone = .plain, bold: Bool = false) { self.text = text; self.tone = tone; self.bold = bold }
}

/// Une ligne du journal : suite de morceaux colorés.
public typealias LogLine = [Seg]

public struct JobResult: Equatable, Sendable {
    public var clean: Bool
    public var files: Int
    public var dirs: Int
    public var errors: Int
    public var summary: String
}

/// Chemin relatif au dossier cible (comme os.path.relpath pour les chemins issus du parcours).
func relativePath(_ path: String, to target: String) -> String {
    var base = target
    while base.count > 1 && base.hasSuffix("/") { base.removeLast() }
    let prefix = base == "/" ? "/" : base + "/"
    return path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path
}

/// Exécute le travail. `isCancelled` est consulté entre deux éléments ; `log` reçoit les lignes, `status` les messages d'état.
public func runJob(target: String, clean: Bool, isCancelled: () -> Bool = { false },
                   log: (LogLine) -> Void, status: (String) -> Void) -> JobResult {
    let modeText = clean ? L("PURGE") : L("SIMULATION, aucune modification")
    status(L("Traitement en cours ({mode})…", ["mode": modeText]))
    log([Seg(L("Dossier :"), .accent, bold: true), Seg(" " + target)])
    log([Seg(L("Mode :"), .accent, bold: true), Seg(" " + modeText)])

    let found = scan(target, isCancelled: isCancelled)
    if found.walkErrors > 0 { log([Seg(L("⚠ {count} dossier(s) illisible(s) ignoré(s).", ["count": found.walkErrors]), .warning)]) }

    if found.files.isEmpty && found.dirs.isEmpty {
        log([])
        log([Seg(L("✓ Aucun résidu détecté. Le dossier est propre."), .success)])
        return JobResult(clean: clean, files: 0, dirs: 0, errors: 0, summary: L("Analyse terminée : aucun résidu."))
    }

    let total = found.files.reduce(0) { $0 + $1.size } + found.dirs.reduce(0) { $0 + $1.size }
    log([])
    log([Seg(L("Détectés : {files} fichier(s), {dirs} dossier(s), {size}",
               ["files": found.files.count, "dirs": found.dirs.count, "size": formatSize(total)]), bold: true)])
    log([])

    let nbsp = "\u{00a0}\u{00a0}"
    var deletedFiles = 0, deletedDirs = 0, errors = 0

    for item in found.files {
        if isCancelled() { break }
        let rel = relativePath(item.path, to: target)
        if !clean {
            log([Seg(nbsp), Seg(L("[DÉTECTÉ]"), .warning), Seg(" \(rel) (\(formatSize(item.size)))")])
            continue
        }
        do {
            try removeFile(item.path)
            deletedFiles += 1
            log([Seg(nbsp), Seg(L("[SUPPRIMÉ]"), .danger), Seg(" \(rel) (\(formatSize(item.size)))")])
        } catch {
            errors += 1
            log([Seg(nbsp), Seg(L("[ERREUR]"), .danger, bold: true), Seg(" \(rel) : \(error)")])
        }
    }

    for item in found.dirs {
        if isCancelled() { break }
        let rel = relativePath(item.path, to: target)
        if !clean {
            log([Seg(nbsp), Seg(L("[DOSSIER DÉTECTÉ]"), .warning), Seg(" \(rel)/ (\(formatSize(item.size)))")])
            continue
        }
        do {
            try removeTree(item.path)  // un lien symbolique est supprimé seul, jamais sa cible
            deletedDirs += 1
            log([Seg(nbsp), Seg(L("[DOSSIER SUPPRIMÉ]"), .danger), Seg(" \(rel)/")])
        } catch {
            errors += 1
            log([Seg(nbsp), Seg(L("[ERREUR DOSSIER]"), .danger, bold: true), Seg(" \(rel) : \(error)")])
        }
    }

    log([])
    if clean {
        let summary = L("Purge terminée : {files} fichier(s) et {dirs} dossier(s) supprimés.", ["files": deletedFiles, "dirs": deletedDirs])
        log([Seg("✓ \(summary)", .success)])
        if errors > 0 {
            log([Seg(L("Erreur : {count} élément(s) n'ont pas pu être supprimés. Vérifiez qu'ils ne sont pas ouverts ou protégés.", ["count": errors]), .danger)])
        }
        return JobResult(clean: true, files: deletedFiles, dirs: deletedDirs, errors: errors, summary: summary)
    }
    let summary = L("Analyse terminée : {files} fichier(s) et {dirs} dossier(s) à purger.", ["files": found.files.count, "dirs": found.dirs.count])
    log([Seg("✓ \(summary)", .accent)])
    log([Seg(L("Rien n'a été supprimé. Cliquez sur « {btn} » pour les supprimer.", ["btn": L("Purger les résidus")]), .muted)])
    return JobResult(clean: false, files: found.files.count, dirs: found.dirs.count, errors: 0, summary: summary)
}
