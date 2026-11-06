// Fenêtre « Règles de filtrage » : titres et listes (textes dans i18n/strings.json), bouton Fermer.

import AppKit
import CleanCore
import SwiftUI

/// Une section : titre et lignes (le texte entre accents graves est du code, entre ** est en gras).
struct RuleSection { let title: String; let items: [String] }

let ruleSections: [RuleSection] = [
    RuleSection(title: N_("1. Caches et fichiers système"), items: [
        N_("`thumbs.db` (miniatures Windows)"),
        N_("`desktop.ini` (réglages de dossier Windows)"),
        N_("`.DS_Store` (métadonnées macOS)")]),
    RuleSection(title: N_("2. Mod Organizer 2"), items: [
        N_("Fichiers et dossiers masqués : `*.mohidden`")]),
    RuleSection(title: N_("3. xEdit (SSEEdit / FO4Edit)"), items: [
        N_("Groupes de mods : `*.modgroups`, `modgroups.json`"),
        N_("Dossiers : `modgroups/`")]),
    RuleSection(title: N_("4. Vortex et collections Nexus Mods"), items: [
        N_("Déploiement : `vortex.deployment.json`"),
        N_("Marqueurs : `folder_managed_by_vortex`, `__folder_managed_by_vortex`"),
        N_("Sauvegardes : `ActiveMods.json.vortex_backup`, `Engine.log.vortex_backup`, `*.vortex_backup*`"),
        N_("Liens symboliques résiduels : `*.vortex_lnk`"),
        N_("Métadonnées Nexus : `collection.json`, `collection.meta`, `manifest.json`"),
        N_("Dossiers temporaires : `__vortex_*`, `.vortex_staging/`")]),
    RuleSection(title: N_("5. Sauvegardes, temporaires et doublons"), items: [
        N_("Sauvegardes : `*.bak`, `*.tmp`, `*.crdownload`"),
        N_("Copies de fichiers : ` - copy.*`, ` - copie.*`, ` - copia.*`"),
        N_("Dossiers doublons : ` - copy`, ` - copie`, ` - copia`")]),
    RuleSection(title: N_("6. Documents bureautiques"), items: [
        N_("Traitements de texte : `*.doc`, `*.docx`, `*.rtf`, `*.odt`")]),
    RuleSection(title: N_("7. Sources graphiques et fichiers factices"), items: [
        N_("Projets graphiques : `*.pdn`, `*.xcf`, `*.psd`"),
        N_("Textures de test : `dummy texture.dds`, `faketexture.dds`")]),
    RuleSection(title: N_("8. Documentation et licences uniquement"), items: [
        N_("Notices : `readme`, `read_me`, `lisezmoi`, `instructions`, `changelog` (.txt/.md)"),
        N_("Licences : `license`, `licence`, `eula`, `copying` (.txt/.md)")]),
]

let rulesNote = N_("**Protégé :** tous les autres fichiers `.txt` de configuration des mods sont conservés.")

/// Texte avec `code` (accent) et **gras**.
func inlineMarkup(_ text: String, code: Color, base: Color) -> AttributedString {
    var out = AttributedString()
    var bold = false
    for (i, chunk) in text.components(separatedBy: "`").enumerated() {
        if i % 2 == 1 {
            var a = AttributedString(chunk)
            a.foregroundColor = code
            out += a
            continue
        }
        for (j, part) in chunk.components(separatedBy: "**").enumerated() {
            if j > 0 { bold.toggle() }
            var a = AttributedString(part)
            a.foregroundColor = base
            if bold { a.inlinePresentationIntent = .stronglyEmphasized }
            out += a
        }
    }
    return out
}

struct RulesView: View {
    var close: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: Socle.M.space3) {
            Text(L("📋 Éléments ciblés par la purge")).socle(Socle.T.heading).foregroundStyle(Socle.C.textStrong)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(ruleSections, id: \.title) { section in
                        Text(L(section.title)).socle(Socle.T.title).foregroundStyle(Socle.C.textStrong).padding(.top, 12)
                        ForEach(section.items, id: \.self) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("•").foregroundStyle(Socle.C.text)
                                Text(inlineMarkup(L(item), code: Socle.C.accentText, base: Socle.C.text))
                            }
                            .socle(Socle.T.body)
                            .padding(.leading, 10)
                        }
                    }
                    Text(inlineMarkup(L(rulesNote), code: Socle.C.success, base: Socle.C.success))
                        .socle(Socle.T.body).padding(.top, 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Socle.M.space3)
                .textSelection(.enabled)
            }
            .background(Socle.C.bgSunken)
            .overlay(Rectangle().stroke(Socle.C.border, lineWidth: 1))
            HStack {
                Spacer()
                Button(L("Fermer"), action: close)
                    .buttonStyle(SocleButtonStyle(.primary))
                    .keyboardShortcut(.defaultAction)
                    .fixedSize()
            }
        }
        .padding(Socle.M.space6)
        .background(Socle.C.bg)
    }
}

@MainActor
enum RulesWindow {
    private final class Delegate: NSObject, NSWindowDelegate {
        func windowWillClose(_ notification: Notification) { NSApp.stopModal() }
    }
    private static let delegate = Delegate()

    /// Fenêtre modale (600 × 520, minimum 480 × 400).
    static func run(over parent: NSWindow?) {
        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 520),
                           styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        win.title = L("Règles de filtrage")
        win.isReleasedWhenClosed = false
        win.delegate = delegate
        win.contentMinSize = NSSize(width: 480, height: 400)
        win.backgroundColor = NSColor(Socle.C.bg)
        win.contentView = NSHostingView(rootView: RulesView { win.close() })
        win.setContentSize(NSSize(width: 600, height: 520))
        if let parent {
            win.setFrameOrigin(NSPoint(x: parent.frame.midX - 300, y: parent.frame.midY - 260))
        } else { win.socleCenter() }
        NSApp.runModal(for: win)
        win.orderOut(nil)
    }
}
