// Motifs ciblés par la purge, recopiés tels quels de la version Python (insensibles à la casse, testés sur le nom seul).
// Lus aussi par la preview web (preview/tools/extract.py) : un motif par ligne, entre #"…"#.

import Foundation

public enum Patterns {
    public static let file: [String] = [
        // Système / OS
        #"^thumbs\.db$"#,
        #"^desktop\.ini$"#,
        #"^\.DS_Store$"#,
        // Mod Organizer 2
        #"\.mohidden$"#,
        // xEdit (SSEEdit / FO4Edit)
        #"\.modgroups$"#,
        #"^modgroups\.json$"#,
        // Vortex & Collections Nexus Mods (.vortex_backup couvre ActiveMods.json / Engine.log)
        #"^vortex\.deployment\.json$"#,
        #"^_{0,2}folder_managed_by_vortex$"#,
        #"\.vortex_backup"#,
        #"\.vortex_lnk$"#,
        #"^(collection\.json|collection\.meta|manifest\.json)$"#,
        // Sauvegardes & temporaires
        #"\.(bak|tmp|crdownload)$"#,
        // Copies & doublons de fichiers (dont noms mal décodés)
        #" - cop(y|ie|ia)\.[^.]+$"#,
        #" - [©▒¥\?]+\.[^.]+$"#,
        // Sources graphiques de travail non compilées
        #"\.(pdn|xcf|psd)$"#,
        // Documents bureautiques inutiles en jeu
        #"\.(docx?|rtf|odt)$"#,
        // Fichiers de test / factices
        #"^(dummy texture|faketexture)\.dds$"#,
        // Documentation & licences UNIQUEMENT (les .txt fonctionnels sont préservés)
        #"^(readme|read_me|read me|lisezmoi|lisez_moi|lisez moi|instructions?|changelog|licen[sc]e|eula|copying)\.(txt|md)$"#,
    ]

    public static let dir: [String] = [
        #"\.mohidden$"#,
        #" - cop(y|ie|ia)$"#,
        #"^__vortex_"#,
        #"^\.vortex_staging$"#,
        #"^_{0,2}folder_managed_by_vortex$"#,
        #"^modgroups$"#,
    ]

    // Une seule expression par catégorie : un test par nom au lieu d'une boucle sur chaque motif.
    static let fileRegex = compile(file)
    static let dirRegex = compile(dir)

    private static func compile(_ patterns: [String]) -> NSRegularExpression {
        let joined = patterns.map { "(?:\($0))" }.joined(separator: "|")
        return try! NSRegularExpression(pattern: joined, options: [.caseInsensitive])
    }

    private static func search(_ re: NSRegularExpression, _ name: String) -> Bool {
        re.firstMatch(in: name, options: [], range: NSRange(name.startIndex..., in: name)) != nil
    }

    public static func matchesFile(_ name: String) -> Bool { search(fileRegex, name) }
    public static func matchesDir(_ name: String) -> Bool { search(dirRegex, name) }
}
