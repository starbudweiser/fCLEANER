// Parcours de dossier équivalent à os.walk (descendant, liens symboliques jamais suivis) et tailles.

import Foundation

public struct Item: Equatable, Sendable {
    public let path: String
    public let size: Int64
    public init(path: String, size: Int64) { self.path = path; self.size = size }
}

public struct ScanResult: Sendable {
    public var files: [Item] = []
    public var dirs: [Item] = []
    public var walkErrors = 0
}

func joinPath(_ root: String, _ name: String) -> String {
    root.hasSuffix("/") ? root + name : root + "/" + name
}

func isSymlink(_ path: String) -> Bool {
    var st = stat()
    return lstat(path, &st) == 0 && (st.st_mode & S_IFMT) == S_IFLNK
}

/// Contenu d'un dossier : noms des sous-dossiers (liens vers un dossier compris, comme scandir().is_dir()) et des autres entrées.
/// Renvoie nil si le dossier est illisible.
func listDir(_ path: String) -> (dirs: [String], files: [String])? {
    guard let d = opendir(path) else { return nil }
    defer { closedir(d) }
    var dirs: [String] = [], files: [String] = []
    while let e = readdir(d) {
        let name = withUnsafePointer(to: &e.pointee.d_name) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) { String(cString: $0) }
        }
        if name == "." || name == ".." { continue }
        var isDir = false
        switch Int32(e.pointee.d_type) {
        case Int32(DT_DIR): isDir = true
        case Int32(DT_LNK), Int32(DT_UNKNOWN):
            var st = stat()
            isDir = stat(joinPath(path, name), &st) == 0 && (st.st_mode & S_IFMT) == S_IFDIR
        default: break
        }
        if isDir { dirs.append(name) } else { files.append(name) }
    }
    return (dirs, files)
}

/// Parcours descendant. `visit(root, &dirs, files)` peut retirer des sous-dossiers de `dirs` pour ne pas les explorer ;
/// renvoie false pour arrêter. Les liens symboliques vers un dossier sont listés mais pas explorés.
/// Renvoie le nombre de dossiers illisibles rencontrés.
@discardableResult
func walk(_ top: String, _ visit: (_ root: String, _ dirs: inout [String], _ files: [String]) -> Bool) -> Int {
    var errors = 0
    func go(_ root: String) -> Bool {
        guard let (dirs0, files) = listDir(root) else { errors += 1; return true }
        var dirs = dirs0
        if !visit(root, &dirs, files) { return false }
        for d in dirs {
            let p = joinPath(root, d)
            if !isSymlink(p), !go(p) { return false }
        }
        return true
    }
    _ = go(top)
    return errors
}

/// Taille cumulée des fichiers d'un dossier (sans suivre les liens symboliques) ; 0 pour un lien.
public func treeSize(_ path: String) -> Int64 {
    if isSymlink(path) { return 0 }
    var total: Int64 = 0
    walk(path) { root, _, files in
        for f in files {
            var st = stat()
            if lstat(joinPath(root, f), &st) == 0 { total += Int64(st.st_size) }
        }
        return true
    }
    return total
}

/// Parcours descendant : un dossier parasite est retenu en bloc et n'est pas exploré,
/// ses fichiers ne sont donc ni comptés ni supprimés deux fois.
public func scan(_ target: String, isCancelled: () -> Bool = { false }) -> ScanResult {
    var result = ScanResult()
    result.walkErrors = walk(target) { root, dirs, files in
        if isCancelled() { return false }
        var kept: [String] = []
        for d in dirs {
            if Patterns.matchesDir(d) {
                let path = joinPath(root, d)
                result.dirs.append(Item(path: path, size: treeSize(path)))
            } else {
                kept.append(d)
            }
        }
        dirs = kept
        for f in files where Patterns.matchesFile(f) {
            let path = joinPath(root, f)
            var st = stat()
            let size = lstat(path, &st) == 0 ? Int64(st.st_size) : 0
            result.files.append(Item(path: path, size: size))
        }
        return true
    }
    return result
}
