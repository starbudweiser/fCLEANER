// État de l'appli : dossier choisi, journal, état, travail en arrière-plan (analyse ou purge) et arrêt propre.

import AppKit
import CleanCore
import Observation
import SwiftUI

enum StatusTone { case none, success, danger }

/// Drapeau d'arrêt partagé avec le fil de travail.
final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    var isSet: Bool { lock.lock(); defer { lock.unlock() }; return flag }
    func set() { lock.lock(); flag = true; lock.unlock() }
}

/// Lignes du journal en attente d'affichage : le fil de travail les dépose, l'interface les prend par paquets.
final class LogStore: @unchecked Sendable {
    private let lock = NSLock()
    private var pending: [LogLine] = []
    private var clearRequested = false

    func add(_ line: LogLine) { lock.lock(); pending.append(line); lock.unlock() }
    func clear() { lock.lock(); pending.removeAll(); clearRequested = true; lock.unlock() }
    func take() -> (clear: Bool, lines: [LogLine]) {
        lock.lock(); defer { lock.unlock() }
        let out = (clearRequested, pending)
        pending.removeAll(); clearRequested = false
        return out
    }
}

@MainActor @Observable
final class AppModel {
    var folder = "" { didSet { folderChanged() } }
    var status = ""
    var statusTone: StatusTone = .none
    var busy = false
    var tick = 0  // change à chaque retraduction (changement de langue)
    var logTick = 0  // change quand le journal a du nouveau

    /// Dossier, fichiers et dossiers de la dernière analyse non vide : la purge n'est proposée qu'après elle.
    var scanned: (folder: String, files: Int, dirs: Int)?

    // Dialogues
    var confirming = false
    var missingFolder = false
    var resultText: String?

    let log = LogStore()
    private var cancel = CancelFlag()
    private let done = DispatchSemaphore(value: 0)
    private var running = false

    init() { status = L("Choisissez un dossier pour commencer.") }

    var trimmed: String { folder.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// Dossier saisi s'il existe, sinon chaîne vide.
    var validFolder: String {
        var isDir: ObjCBool = false
        return !trimmed.isEmpty && FileManager.default.fileExists(atPath: trimmed, isDirectory: &isDir) && isDir.boolValue ? trimmed : ""
    }

    var canPurge: Bool { !busy && scanned != nil && scanned!.folder == trimmed }

    private func folderChanged() {
        if let s = scanned, s.folder != trimmed { scanned = nil }
        if !busy { status = validFolder.isEmpty ? L("Choisissez un dossier pour commencer.") : L("Dossier prêt. Lancez l'analyse.") ; statusTone = .none }
    }

    func chosen(_ url: URL) {
        folder = url.path
        log.clear(); logTick += 1
        log.add([Seg(L("📁 Dossier sélectionné : ")), Seg(url.path, .accent)])
        logTick += 1
        status = L("Dossier prêt. Lancez l'analyse.")
        statusTone = .none
    }

    // MARK: Actions

    func start(clean: Bool) {
        guard !busy else { return }
        let target = validFolder
        if target.isEmpty { missingFolder = true; return }
        log.clear(); logTick += 1
        busy = true
        statusTone = .none
        let flag = CancelFlag()
        cancel = flag
        running = true
        let store = log
        let sem = done
        Thread.detachNewThread { [weak self] in
            let result = runJob(target: target, clean: clean, isCancelled: { flag.isSet },
                                log: { store.add($0) },
                                status: { s in DispatchQueue.main.async { MainActor.assumeIsolated { self?.status = s } } })
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.finished(result) } }
            sem.signal()
        }
        pump()
    }

    /// Affiche le journal par paquets (toutes les 0,1 s) tant que le travail tourne, sans figer l'interface.
    private func pump() {
        logTick += 1
        guard busy else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { MainActor.assumeIsolated { self.pump() } }
    }

    private func finished(_ r: JobResult) {
        running = false
        scanned = !r.clean && (r.files > 0 || r.dirs > 0) ? (trimmed, r.files, r.dirs) : nil
        busy = false
        logTick += 1
        if r.clean {
            status = r.summary
            statusTone = r.errors > 0 ? .danger : .success
            resultText = r.summary + (r.errors > 0 ? "\n\n" + L("Erreur : {count} élément(s) n'ont pas pu être supprimés. Vérifiez qu'ils ne sont pas ouverts ou protégés.", ["count": r.errors]) : "")
        } else {
            status = r.summary
            statusTone = r.files + r.dirs == 0 ? .success : .none
        }
    }

    func askPurge() {
        guard scanned != nil else { return }
        confirming = true
    }

    var confirmText: String {
        L("Supprimer définitivement {files} fichier(s) et {dirs} dossier(s) détectés ?\n\nLes autres fichiers .TXT des mods ne sont pas touchés. Cette opération est irréversible.",
          ["files": scanned?.files ?? 0, "dirs": scanned?.dirs ?? 0])
    }

    /// Fermeture de la fenêtre : on ne coupe pas une suppression brutalement, on l'arrête proprement et on attend.
    func stopAndWait() {
        guard running else { return }
        cancel.set()
        done.wait()
    }

    // MARK: Langue

    func retranslate() {
        tick += 1
        if !busy { status = validFolder.isEmpty ? L("Choisissez un dossier pour commencer.") : L("Dossier prêt. Lancez l'analyse.") ; statusTone = .none }
    }
}
