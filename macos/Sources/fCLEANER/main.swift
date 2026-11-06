// Point d'entrée : fenêtre AppKit unique (920 × 640, redimensionnable) qui héberge l'interface SwiftUI.

import AppKit
import CleanCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    let model = AppModel()
    var config = Config.load()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Socle.apply()
        // « f » dans la couleur du manche du logo
        Socle.brand("fCLEANER", color: Color(red: 0xd4 / 255, green: 0xa3 / 255, blue: 0x73 / 255))
        buildMenu()

        let host = NSHostingView(rootView: ContentView(model: model, showRules: { [weak self] in RulesWindow.run(over: self?.window) }))
        window = NSWindow(contentRect: NSRect(origin: .zero, size: WINDOW_SIZE),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = L("fCLEANER – Nettoyeur d'instance")
        window.contentView = host
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.backgroundColor = NSColor(Socle.C.bg)
        window.contentMinSize = NSSize(width: 760, height: 520)
        window.setContentSize(WINDOW_SIZE)
        window.socleCenter()
        // Essais en arrière-plan : FCLEANER_QUIET=1 lance l'appli sans prendre le focus
        if ProcessInfo.processInfo.environment["FCLEANER_QUIET"] != nil {
            window.orderBack(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
        }
        UpdateEngine.shared.configure(repo: "fCLEANER", lang: { I18n.lang })
        UpdateEngine.shared.canInstall = { [weak self] in !(self?.model.busy ?? false) }
        UpdateEngine.shared.start()  // nouvelle version ? (au plus une fois par jour)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { UpdateEngine.shared.installAppMenuItem() }

        // Dossier passé en argument (essais) : FCLEANER_FOLDER=<dossier> le pré-remplit
        if let f = ProcessInfo.processInfo.environment["FCLEANER_FOLDER"] { model.folder = f }

        // Vérification visuelle (développement) : FCLEANER_SNAPSHOT=<fichier.png> enregistre la fenêtre après 2 s et quitte.
        // FCLEANER_SCAN=1 lance d'abord l'analyse (lecture seule).
        if ProcessInfo.processInfo.environment["FCLEANER_SCAN"] != nil { model.start(clean: false) }
        // FCLEANER_SNAPSHOT_RULES=<fichier.png> : capture de la fenêtre Règles (600 × 520)
        if let out = ProcessInfo.processInfo.environment["FCLEANER_SNAPSHOT_RULES"] {
            let v = NSHostingView(rootView: RulesView {})
            v.frame = NSRect(x: 0, y: 0, width: 600, height: 520)
            let w = NSWindow(contentRect: v.frame, styleMask: [.titled], backing: .buffered, defer: false)
            w.contentView = v
            w.orderBack(nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                if let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) {
                    v.cacheDisplay(in: v.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
                }
                NSApp.terminate(nil)
            }
        }
        if let out = ProcessInfo.processInfo.environment["FCLEANER_SNAPSHOT"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [self] in
                let view = window.contentView!
                if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                    view.cacheDisplay(in: view.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: out))
                }
                NSApp.terminate(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Fermer la fenêtre pendant une opération : arrêt propre du travail, puis fermeture.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        model.stopAndWait()
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        model.stopAndWait()
        return .terminateNow
    }

    // MARK: Langue

    /// Change la langue (code ou « auto »), la mémorise et retraduit l'interface.
    @objc func chooseLanguage(_ sender: NSMenuItem) {
        let choice = Config.normalize(sender.representedObject as? String)
        config["language"] = choice
        Config.save(config)
        I18n.setLang(Config.resolve(choice))
        window.title = L("fCLEANER – Nettoyeur d'instance")
        model.retranslate()
        buildMenu()
        UpdateEngine.shared.insertMenuItem()
    }

    @objc func showAbout(_ sender: Any?) { About.show() }

    private func buildMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        // Pas de couleur dans les menus : le nom de l'appli y est en texte normal
        let about = appMenu.addItem(withTitle: L("À propos de fCLEANER"), action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("Masquer fCLEANER"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = appMenu.addItem(withTitle: L("Masquer les autres"),
                                     action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: L("Tout afficher"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("Quitter fCLEANER"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        // Édition : copier / sélectionner tout dans le journal et le champ du dossier
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: L("Édition"))
        editMenu.addItem(withTitle: L("Copier"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L("Coller"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L("Tout sélectionner"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)

        // Menu « Langue » : Automatique + 4 langues, coche sur le choix courant
        let langItem = NSMenuItem()
        let langMenu = NSMenu(title: L("Langue"))
        let current = Config.choice(config)
        func add(_ title: String, _ code: String) {
            let item = langMenu.addItem(withTitle: title, action: #selector(chooseLanguage), keyEquivalent: "")
            item.target = self
            item.representedObject = code
            item.state = code == current ? .on : .off
        }
        add(L("Automatique (système)"), Config.auto)
        langMenu.addItem(.separator())
        for (code, label) in Config.menuLangs { add(label, code) }
        langItem.submenu = langMenu
        main.addItem(langItem)

        let winItem = NSMenuItem()
        let winMenu = NSMenu(title: L("Fenêtre"))
        winMenu.addItem(withTitle: L("Réduire"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        winItem.submenu = winMenu
        main.addItem(winItem)
        NSApp.mainMenu = main
        NSApp.windowsMenu = winMenu
    }
}

I18n.setLang(Config.resolve(Config.choice(Config.load())))

// Mode ligne de commande (essais, lecture seule) : « fCLEANER --scan <dossier> » écrit « D|F<TAB>taille<TAB>chemin » par élément
// détecté, puis « E<TAB>n » (dossiers illisibles), et quitte sans ouvrir de fenêtre. Ne supprime jamais rien.
let cliArgs = CommandLine.arguments
if cliArgs.count == 3, cliArgs[1] == "--scan" {
    let r = scan(cliArgs[2])
    for i in r.dirs { print("D\t\(i.size)\t\(i.path)") }
    for i in r.files { print("F\t\(i.size)\t\(i.path)") }
    print("E\t\(r.walkErrors)")
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}
