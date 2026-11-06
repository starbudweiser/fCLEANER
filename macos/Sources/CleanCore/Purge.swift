// Suppression définitive (pas la Corbeille) : un fichier, ou un dossier avec tout son contenu. Les liens symboliques
// sont supprimés eux-mêmes, jamais leur cible. Erreurs au format de la version Python : « [Errno 13] … : 'chemin' ».

import Foundation

public struct PurgeError: Error, CustomStringConvertible, Equatable {
    public let code: Int32
    public let path: String
    public var description: String { "[Errno \(code)] \(String(cString: strerror(code))): '\(path)'" }
}

/// Supprime un fichier (ou un lien symbolique, lien seul).
public func removeFile(_ path: String) throws {
    if unlink(path) != 0 { throw PurgeError(code: errno, path: path) }
}

/// Supprime un dossier et son contenu ; un lien symbolique est supprimé seul. S'arrête à la première erreur (comme shutil.rmtree).
public func removeTree(_ path: String) throws {
    var st = stat()
    guard lstat(path, &st) == 0 else { throw PurgeError(code: errno, path: path) }
    if (st.st_mode & S_IFMT) != S_IFDIR {
        try removeFile(path)  // lien symbolique (ou autre) : jamais suivi
        return
    }
    guard let d = opendir(path) else { throw PurgeError(code: errno, path: path) }
    var names: [String] = []
    while let e = readdir(d) {
        let name = withUnsafePointer(to: &e.pointee.d_name) {
            $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) { String(cString: $0) }
        }
        if name != "." && name != ".." { names.append(name) }
    }
    closedir(d)
    for n in names { try removeTree(joinPath(path, n)) }
    if rmdir(path) != 0 { throw PurgeError(code: errno, path: path) }
}
