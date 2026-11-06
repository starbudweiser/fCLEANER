// Motifs, parcours, purge et journal du cœur de fCLEANER, sur des arbres fabriqués dans un dossier temporaire.

import Foundation
import XCTest
@testable import CleanCore

final class CleanCoreTests: XCTestCase {
    var dir: URL!
    let fm = FileManager.default

    override func setUpWithError() throws {
        I18n.setLang("fr")
        dir = fm.temporaryDirectory.appendingPathComponent("fcleaner-tests-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        // Remet les droits avant de supprimer (tests d'erreurs)
        if let en = fm.enumerator(atPath: dir.path) {
            for case let p as String in en { try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.appendingPathComponent(p).path) }
        }
        try? fm.removeItem(at: dir)
    }

    @discardableResult
    func file(_ rel: String, _ bytes: Int = 1) throws -> String {
        let url = dir.appendingPathComponent(rel)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 0x41, count: bytes).write(to: url)
        return url.path
    }

    func folder(_ rel: String) throws {
        try fm.createDirectory(at: dir.appendingPathComponent(rel), withIntermediateDirectories: true)
    }

    func rels(_ items: [Item]) -> [String] {
        items.map { relativePath($0.path, to: dir.path) }.sorted()
    }

    // MARK: Motifs

    func testFilePatternsTaken() {
        let taken = ["Thumbs.db", "THUMBS.DB", "desktop.ini", ".DS_Store", ".ds_store", "a.mohidden", "x.modgroups", "modgroups.json",
                     "vortex.deployment.json", "_folder_managed_by_vortex", "__folder_managed_by_vortex", "ActiveMods.json.vortex_backup",
                     "x.vortex_backup2", "a.vortex_lnk", "collection.json", "collection.meta", "manifest.json",
                     "a.bak", "a.TMP", "a.crdownload", "tex - Copy.dds", "tex - copie.dds", "tex - copia.png", "tex - ©.dds",
                     "tex - ▒▒.dds", "tex - ¥?.dds", "a.pdn", "a.xcf", "a.PSD", "a.doc", "a.docx", "a.rtf", "a.odt",
                     "dummy texture.dds", "faketexture.dds", "readme.txt", "README.md", "read_me.txt", "read me.txt", "lisezmoi.txt",
                     "lisez_moi.md", "lisez moi.txt", "instruction.txt", "instructions.md", "changelog.txt", "license.txt",
                     "licence.md", "EULA.txt", "copying.md"]
        for n in taken { XCTAssertTrue(Patterns.matchesFile(n), n) }
    }

    func testFilePatternsKept() {
        let kept = ["config.txt", "notes.txt", "readme_fr.txt", "myreadme.txt", "readme.pdf", "readme.txt.old", "thumbs.db.x", "athumbs.db",
                    "desktop.ini.bak.keep", "collection.jsonx", "xmanifest.json", "a.docm", "a.doc.x", "tex - Copy", "tex - copy.dds.x",
                    "tex - cop.dds", "tex - copyright.dds", "tex.dds", "dummy texture.png", "a.psdx", "a.xcfx", "modgroups.jsonx", "licenses.txt",
                    "a.mohiddenx", "vortex.deployment.jsonx", "tex-copy.dds", "tex - ab.dds", "folder_managed_by_vortex", "a.bakx", "plugin.esp", "mesh.nif"]
        for n in kept { if n.hasSuffix(".bak") || n.hasSuffix(".tmp") { continue }; XCTAssertFalse(Patterns.matchesFile(n), n) }
    }

    func testFilePatternsExactCases() {
        XCTAssertTrue(Patterns.matchesFile("readme.txt"))
        XCTAssertFalse(Patterns.matchesFile("config.txt"))
        XCTAssertTrue(Patterns.matchesFile("x.vortex_backup"))        // pas d'ancre de fin
        XCTAssertTrue(Patterns.matchesFile("ActiveMods.json.vortex_backup.1"))
        XCTAssertFalse(Patterns.matchesFile("mod.tmpx"))
    }

    func testDirPatterns() {
        for n in ["Textures - Copy", "x - copie", "y - COPIA", "a.mohidden", "__vortex_staging", "__VORTEX_x", ".vortex_staging",
                  "_folder_managed_by_vortex", "__folder_managed_by_vortex", "modgroups", "MODGROUPS"] {
            XCTAssertTrue(Patterns.matchesDir(n), n)
        }
        for n in ["Textures", "Copy", "modgroups2", "my_modgroups", "vortex_staging", "x - copy.bak", "_vortex_x", ".vortex_staging2", "Meshes - Copy2", "folder_managed_by_vortex"] {  // comme en Python : au moins un tiret bas devant
            XCTAssertFalse(Patterns.matchesDir(n), n)
        }
    }

    func testPatternCounts() {
        XCTAssertEqual(Patterns.file.count, 18)
        XCTAssertEqual(Patterns.dir.count, 6)
    }

    // MARK: Taille

    func testFormatSize() {
        XCTAssertEqual(formatSize(0), "0 octets")
        XCTAssertEqual(formatSize(1023), "1023 octets")
        XCTAssertEqual(formatSize(1024), "1.0 Ko")
        XCTAssertEqual(formatSize(1536), "1.5 Ko")
        XCTAssertEqual(formatSize(1024 * 1024), "1.00 Mo")
        XCTAssertEqual(formatSize(5 * 1024 * 1024 + 524288), "5.50 Mo")
        XCTAssertEqual(formatSize(3 * 1024 * 1024 * 1024), "3.00 Go")
        I18n.setLang("en")
        XCTAssertEqual(formatSize(2048), "2.0 KB")
        XCTAssertEqual(formatSize(10), "10 bytes")
    }

    // MARK: Parcours

    func testScanFindsFilesAndDirsWithSizes() throws {
        try file("Mod A/readme.txt", 10)
        try file("Mod A/config.txt", 5)
        try file("Mod A/Textures/a.dds", 7)
        try file("Mod A/Textures/Thumbs.db", 3)
        try file("Mod B/x.bak", 4)
        try file("Mod B/sub/y.PSD", 6)
        try file("Mod B/Meshes - Copy/m.nif", 100)
        try file("Mod B/Meshes - Copy/readme.txt", 11)
        let r = scan(dir.path)
        XCTAssertEqual(rels(r.files), ["Mod A/Textures/Thumbs.db", "Mod A/readme.txt", "Mod B/sub/y.PSD", "Mod B/x.bak"])
        XCTAssertEqual(rels(r.dirs), ["Mod B/Meshes - Copy"])
        XCTAssertEqual(r.dirs.first?.size, 111)
        XCTAssertEqual(r.files.first { $0.path.hasSuffix("readme.txt") }?.size, 10)
        XCTAssertEqual(r.walkErrors, 0)
    }

    func testParasiticFolderIsNotExplored() throws {
        // Les fichiers parasites d'un dossier parasite ne sont ni comptés à part ni supprimés deux fois
        try file("m/Textures - Copy/readme.txt", 10)
        try file("m/Textures - Copy/sub/a.bak", 20)
        try file("m/Textures - Copy/inner - Copy/z.dds", 30)
        let r = scan(dir.path)
        XCTAssertEqual(rels(r.files), [])
        XCTAssertEqual(rels(r.dirs), ["m/Textures - Copy"])
        XCTAssertEqual(r.dirs[0].size, 60)
    }

    func testCleanFolderHasNoResidue() throws {
        try file("m/a.esp"); try file("m/config.txt"); try file("m/Textures/a.dds")
        let r = scan(dir.path)
        XCTAssertTrue(r.files.isEmpty && r.dirs.isEmpty)
    }

    func testSymlinksAreNotFollowed() throws {
        let outside = fm.temporaryDirectory.appendingPathComponent("fcleaner-out-\(UUID().uuidString)")
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: outside) }
        try Data("x".utf8).write(to: outside.appendingPathComponent("readme.txt"))
        try folder("m")
        // lien vers un dossier non parasite : pas exploré (son readme.txt n'est pas vu)
        try fm.createSymbolicLink(atPath: dir.appendingPathComponent("m/link").path, withDestinationPath: outside.path)
        let r = scan(dir.path)
        XCTAssertTrue(r.files.isEmpty && r.dirs.isEmpty)
        // lien symbolique vers un fichier : traité comme un fichier (taille du lien)
        try fm.createSymbolicLink(atPath: dir.appendingPathComponent("m/a.bak").path, withDestinationPath: outside.appendingPathComponent("readme.txt").path)
        let r2 = scan(dir.path)
        XCTAssertEqual(rels(r2.files), ["m/a.bak"])
    }

    func testSymlinkToDirNamedParasiticIsRetainedWithSizeZero() throws {
        let outside = fm.temporaryDirectory.appendingPathComponent("fcleaner-out-\(UUID().uuidString)")
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: outside) }
        try Data(repeating: 1, count: 500).write(to: outside.appendingPathComponent("keep.dds"))
        try fm.createSymbolicLink(atPath: dir.appendingPathComponent("Pack - Copy").path, withDestinationPath: outside.path)
        let r = scan(dir.path)
        XCTAssertEqual(rels(r.dirs), ["Pack - Copy"])
        XCTAssertEqual(r.dirs[0].size, 0)
    }

    func testUnreadableFolderCountsAsWalkError() throws {
        try file("ok/readme.txt")
        try file("locked/readme.txt")
        try fm.setAttributes([.posixPermissions: 0o000], ofItemAtPath: dir.appendingPathComponent("locked").path)
        let r = scan(dir.path)
        XCTAssertEqual(r.walkErrors, 1)
        XCTAssertEqual(rels(r.files), ["ok/readme.txt"])
    }

    func testMissingRootCountsAsWalkError() {
        let r = scan(dir.appendingPathComponent("absent").path)
        XCTAssertEqual(r.walkErrors, 1)
        XCTAssertTrue(r.files.isEmpty)
    }

    func testCancellationStopsScan() throws {
        for i in 0..<5 { try file("d\(i)/readme.txt") }
        var calls = 0
        let r = scan(dir.path, isCancelled: { calls += 1; return calls > 2 })
        XCTAssertLessThan(r.files.count, 5)
    }

    // MARK: Purge

    func testPurgeRemovesFilesThenDirs() throws {
        try file("m/readme.txt"); try file("m/config.txt"); try file("m/Old - Copy/a.bak"); try file("m/Old - Copy/deep/b.nif")
        var lines: [LogLine] = []
        let res = runJob(target: dir.path, clean: true, log: { lines.append($0) }, status: { _ in })
        XCTAssertEqual(res.files, 1); XCTAssertEqual(res.dirs, 1); XCTAssertEqual(res.errors, 0)
        XCTAssertFalse(fm.fileExists(atPath: dir.appendingPathComponent("m/readme.txt").path))
        XCTAssertFalse(fm.fileExists(atPath: dir.appendingPathComponent("m/Old - Copy").path))
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("m/config.txt").path))
        XCTAssertEqual(res.summary, "Purge terminée : 1 fichier(s) et 1 dossier(s) supprimés.")
        XCTAssertTrue(lines.contains { $0.contains { $0.text == "[SUPPRIMÉ]" && $0.tone == .danger } })
        XCTAssertTrue(lines.contains { $0.contains { $0.text == "[DOSSIER SUPPRIMÉ]" } })
    }

    func testSimulationChangesNothing() throws {
        try file("m/readme.txt", 2048); try file("m/Old - Copy/a.bak")
        var lines: [LogLine] = []
        var statuses: [String] = []
        let res = runJob(target: dir.path, clean: false, log: { lines.append($0) }, status: { statuses.append($0) })
        XCTAssertEqual(res, JobResult(clean: false, files: 1, dirs: 1, errors: 0, summary: "Analyse terminée : 1 fichier(s) et 1 dossier(s) à purger."))
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("m/readme.txt").path))
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("m/Old - Copy/a.bak").path))
        XCTAssertEqual(statuses, ["Traitement en cours (SIMULATION, aucune modification)…"])
        let texts = lines.map { $0.map(\.text).joined() }
        XCTAssertTrue(texts.contains("\u{00a0}\u{00a0}[DÉTECTÉ] m/readme.txt (2.0 Ko)"), texts.joined(separator: "\n"))
        XCTAssertTrue(texts.contains("\u{00a0}\u{00a0}[DOSSIER DÉTECTÉ] m/Old - Copy/ (1 octets)"))
        XCTAssertTrue(texts.contains("Détectés : 1 fichier(s), 1 dossier(s), 2.0 Ko"))
        XCTAssertTrue(texts.last!.hasPrefix("Rien n'a été supprimé. Cliquez sur « Purger les résidus »"))
    }

    func testNoResidueMessage() throws {
        try file("m/a.esp")
        var lines: [LogLine] = []
        let res = runJob(target: dir.path, clean: false, log: { lines.append($0) }, status: { _ in })
        XCTAssertEqual(res.summary, "Analyse terminée : aucun résidu.")
        XCTAssertEqual(res.files + res.dirs, 0)
        XCTAssertTrue(lines.contains { $0.first?.text == "✓ Aucun résidu détecté. Le dossier est propre." && $0.first?.tone == .success })
    }

    func testSymlinkDirPurgedAloneTargetIntact() throws {
        let outside = fm.temporaryDirectory.appendingPathComponent("fcleaner-out-\(UUID().uuidString)")
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: outside) }
        try Data("data".utf8).write(to: outside.appendingPathComponent("keep.dds"))
        try fm.createSymbolicLink(atPath: dir.appendingPathComponent("Pack - Copy").path, withDestinationPath: outside.path)
        let res = runJob(target: dir.path, clean: true, log: { _ in }, status: { _ in })
        XCTAssertEqual(res.dirs, 1); XCTAssertEqual(res.errors, 0)
        XCTAssertNil(try? fm.destinationOfSymbolicLink(atPath: dir.appendingPathComponent("Pack - Copy").path))
        XCTAssertFalse(fm.fileExists(atPath: dir.appendingPathComponent("Pack - Copy").path))
        XCTAssertTrue(fm.fileExists(atPath: outside.appendingPathComponent("keep.dds").path))
    }

    func testSymlinkInsideParasiticFolderNeverFollowed() throws {
        let outside = fm.temporaryDirectory.appendingPathComponent("fcleaner-out-\(UUID().uuidString)")
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: outside) }
        try Data("data".utf8).write(to: outside.appendingPathComponent("keep.dds"))
        try file("Old - Copy/a.txt")
        try fm.createSymbolicLink(atPath: dir.appendingPathComponent("Old - Copy/lnk").path, withDestinationPath: outside.path)
        let res = runJob(target: dir.path, clean: true, log: { _ in }, status: { _ in })
        XCTAssertEqual(res.dirs, 1)
        XCTAssertTrue(fm.fileExists(atPath: outside.appendingPathComponent("keep.dds").path))
    }

    func testReadOnlyFileIsStillRemovedButLockedFolderIsAnError() throws {
        try file("a/readme.txt")
        try file("b/readme.txt")
        try fm.setAttributes([.posixPermissions: 0o444], ofItemAtPath: dir.appendingPathComponent("a/readme.txt").path)
        try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: dir.appendingPathComponent("b").path)  // suppression interdite dans b
        var lines: [LogLine] = []
        let res = runJob(target: dir.path, clean: true, log: { lines.append($0) }, status: { _ in })
        XCTAssertEqual(res.files, 1)
        XCTAssertEqual(res.errors, 1)
        XCTAssertTrue(fm.fileExists(atPath: dir.appendingPathComponent("b/readme.txt").path))
        let err = lines.first { $0.contains { $0.text == "[ERREUR]" } }
        let text = err?.map(\.text).joined() ?? ""
        XCTAssertTrue(text.contains("b/readme.txt : [Errno 13] Permission denied: '"), text)
        XCTAssertEqual(lines.last?.first?.tone, .danger)
        XCTAssertTrue(lines.last!.first!.text.hasPrefix("Erreur : 1 élément(s)"))
    }

    func testFolderErrorIsCountedAndRestContinues() throws {
        try file("Old - Copy/sub/x.dds")
        try file("Zed - Copy/y.dds")
        try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: dir.appendingPathComponent("Old - Copy/sub").path)
        let res = runJob(target: dir.path, clean: true, log: { _ in }, status: { _ in })
        XCTAssertEqual(res.errors, 1)
        XCTAssertEqual(res.dirs, 1)
        XCTAssertFalse(fm.fileExists(atPath: dir.appendingPathComponent("Zed - Copy").path))
    }

    func testCancellationDuringPurgeStopsGracefully() throws {
        for i in 0..<6 { try file("d\(i)/readme.txt") }
        var deleted = 0
        let res = runJob(target: dir.path, clean: true, isCancelled: { deleted >= 2 }, log: { line in
            if line.contains(where: { $0.text == "[SUPPRIMÉ]" }) { deleted += 1 }
        }, status: { _ in })
        XCTAssertEqual(res.files, 2)
        XCTAssertEqual(res.errors, 0)
    }

    func testRelativePath() {
        XCTAssertEqual(relativePath("/a/b/c.txt", to: "/a/b"), "c.txt")
        XCTAssertEqual(relativePath("/a/b/c.txt", to: "/a/b/"), "c.txt")
        XCTAssertEqual(relativePath("/a/x.txt", to: "/"), "a/x.txt")
    }

    // MARK: Langues

    func testTranslationsComplete() {
        let re = try! NSRegularExpression(pattern: #"\{(\w+)\}"#)
        func params(_ t: String) -> Set<String> {
            Set(re.matches(in: t, range: NSRange(t.startIndex..., in: t)).map { String(t[Range($0.range(at: 1), in: t)!]) })
        }
        for (k, v) in translations {
            XCTAssertEqual(v.count, 3, k)
            XCTAssertFalse(v.contains(""), k)
            for t in v { XCTAssertEqual(params(t), params(k), "\(k) → \(t)") }
        }
    }

    func testEnglishJob() throws {
        I18n.setLang("en")
        try file("m/readme.txt")
        var lines: [LogLine] = []
        let res = runJob(target: dir.path, clean: false, log: { lines.append($0) }, status: { _ in })
        XCTAssertEqual(res.summary, "Scan complete: 1 file(s) and 0 folder(s) to purge.")
        XCTAssertTrue(lines.contains { $0.contains { $0.text == "[DETECTED]" } })
    }

    func testSystemLangAndConfig() {
        XCTAssertEqual(I18n.systemLang(["it-IT"]), "it")
        XCTAssertEqual(I18n.systemLang(["de-DE", "es-ES"]), "es")
        XCTAssertEqual(I18n.systemLang(["de-DE"]), "en")
        XCTAssertEqual(Config.resolve("auto", preferred: ["fr-FR"]), "fr")
        XCTAssertEqual(Config.resolve("it", preferred: ["fr-FR"]), "it")
        XCTAssertEqual(Config.normalize("xx"), "auto")
    }
}

/// Comparaison avec la version Python (essai manuel) : purge réelle d'une COPIE, jamais d'un vrai dossier.
/// Actif seulement si FCLEANER_PURGE_COPY désigne un dossier du scratchpad de session.
final class PurgeCopyComparison: XCTestCase {
    func testPurgeOfACopy() throws {
        guard let target = ProcessInfo.processInfo.environment["FCLEANER_PURGE_COPY"] else { throw XCTSkip("FCLEANER_PURGE_COPY absent") }
        let real = URL(fileURLWithPath: target).resolvingSymlinksInPath().path
        XCTAssertTrue((real.hasPrefix("/private/tmp/claude-501/") || real.hasPrefix("/tmp/claude-501/")), "purge refusée hors scratchpad : \(real)")
        guard real.hasPrefix("/private/tmp/claude-501/") || real.hasPrefix("/tmp/claude-501/") else { return }
        I18n.setLang("fr")
        let r = runJob(target: target, clean: true, log: { _ in }, status: { _ in })
        print("RESULT", r.files, r.dirs, r.errors)
    }
}
