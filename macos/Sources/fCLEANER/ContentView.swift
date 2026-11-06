// Interface : en-tête, dossier, journal, état et boutons (Règles, Purger, Analyser). Mêmes textes et disposition que la version Python
// (Socle : textes × 1,1).

import AppKit
import CleanCore
import SwiftUI

let WINDOW_SIZE = CGSize(width: 920, height: 640)

struct ContentView: View {
    @Bindable var model: AppModel
    var showRules: () -> Void

    var body: some View {
        let _ = model.tick
        VStack(spacing: Socle.M.space3) {
            header
            pathPanel
            logPanel
            actions
        }
        .padding(Socle.M.space3)
        .frame(minWidth: 760, minHeight: 520)
        .background(Socle.C.bg)
        .alert("fCLEANER", isPresented: $model.missingFolder) {
            Button(L("OK")) {}
        } message: {
            Text(L("Ce dossier n'existe pas ou n'est plus accessible. Choisissez-en un autre avec « {btn} ».", ["btn": L("Choisir un dossier")]))
        }
        .alert(L("Purger les résidus"), isPresented: $model.confirming) {
            Button(L("Annuler"), role: .cancel) {}  // bouton par défaut : Annuler
            Button(L("Supprimer"), role: .destructive) { model.start(clean: true) }
        } message: { Text(model.confirmText) }
        .alert(L("Purge terminée"), isPresented: Binding(get: { model.resultText != nil }, set: { if !$0 { model.resultText = nil } })) {
            Button(L("OK")) { model.resultText = nil }
        } message: { Text(model.resultText ?? "") }
    }

    private func panel<V: View>(_ raised: Bool = false, @ViewBuilder _ content: () -> V) -> some View {
        content()
            .padding(Socle.M.space3)
            .background(raised ? Socle.C.surfaceRaised : Socle.C.surface, in: RoundedRectangle(cornerRadius: Socle.M.radiusMd))
            .overlay(RoundedRectangle(cornerRadius: Socle.M.radiusMd).stroke(Socle.C.border, lineWidth: 1))
    }

    private var header: some View {
        panel(true) {
            VStack(alignment: .leading, spacing: Socle.M.space2) {
                HStack(spacing: 0) {
                    Text(verbatim: "🧹 ")
                    Text(branded: "fCLEANER")
                }
                .socle(Socle.T.heading).foregroundStyle(Socle.C.textStrong)
                Text(L("Purge les résidus d'assemblage d'une instance ou d'une collection (MO2, Vortex, Nexus) : métadonnées, modgroups xEdit, caches système, sauvegardes (.BAK), doublons, documents bureautiques, sources graphiques (.PSD, .XCF, .PDN), lisez-moi et licences."))
                    .socle(Socle.T.body).foregroundStyle(Socle.C.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var pathPanel: some View {
        panel {
            HStack(spacing: Socle.M.space2) {
                TextField(L("Choisissez le dossier assemblé ou la collection à nettoyer."), text: $model.folder)
                    .socleField()
                    .disabled(model.busy)
                Button(L("Choisir un dossier")) { pickFolder() }
                    .buttonStyle(SocleButtonStyle(.secondary)).fixedSize().disabled(model.busy)
            }
        }
    }

    private var logPanel: some View {
        panel {
            VStack(alignment: .leading, spacing: Socle.M.space2) {
                Text(L("Journal")).socle(Socle.T.title).foregroundStyle(Socle.C.textStrong)
                LogView(model: model)
                    .overlay(Rectangle().stroke(Socle.C.border, lineWidth: 1))
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var actions: some View {
        panel {
            HStack(spacing: Socle.M.space2) {
                Text(model.status)
                    .socle(Socle.T.body).foregroundStyle(statusColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Button(L("Règles de filtrage")) { showRules() }
                    .buttonStyle(SocleButtonStyle(.tertiary)).fixedSize().disabled(model.busy)
                Button(L("Purger les résidus")) { model.askPurge() }
                    .buttonStyle(SocleButtonStyle(.secondary)).fixedSize().disabled(!model.canPurge)
                Button(L("ANALYSER")) { model.start(clean: false) }
                    .buttonStyle(SocleButtonStyle(.primary)).fixedSize().disabled(model.busy)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var statusColor: Color {
        switch model.statusTone {
        case .none: Socle.C.textMuted
        case .success: Socle.C.success
        case .danger: Socle.C.danger
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.title = L("Choisir le dossier à nettoyer")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if !model.trimmed.isEmpty { panel.directoryURL = URL(fileURLWithPath: model.trimmed) }
        if panel.runModal() == .OK, let url = panel.url { model.chosen(url) }
    }
}
