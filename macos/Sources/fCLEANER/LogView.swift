// Journal : texte coloré, rempli par paquets (milliers de lignes sans figer l'interface).

import AppKit
import CleanCore
import SwiftUI

struct LogView: NSViewRepresentable {
    var model: AppModel

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = true
        scroll.backgroundColor = NSColor(Socle.C.bgSunken)
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let tv = scroll.documentView as! NSTextView
        tv.isEditable = false
        tv.isSelectable = true
        tv.drawsBackground = true
        tv.backgroundColor = NSColor(Socle.C.bgSunken)
        tv.textContainerInset = NSSize(width: 8, height: 8)
        tv.isAutomaticQuoteSubstitutionEnabled = false
        context.coordinator.textView = tv
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        _ = model.logTick
        context.coordinator.drain(model.log)
    }

    @MainActor final class Coordinator {
        var textView: NSTextView?

        private func color(_ tone: Tone) -> NSColor {
            switch tone {
            case .plain, .muted: NSColor(Socle.C.textMuted)
            case .accent: NSColor(Socle.C.accentText)
            case .warning: NSColor(Socle.C.warning)
            case .danger: NSColor(Socle.C.danger)
            case .success: NSColor(Socle.C.success)
            }
        }

        func drain(_ store: LogStore) {
            guard let tv = textView else { return }
            let (clear, lines) = store.take()
            if clear { tv.textStorage?.setAttributedString(NSAttributedString()) }
            guard !lines.isEmpty else { return }
            let regular = Socle.T.monoSm.nsFont
            let bold = NSFont.monospacedSystemFont(ofSize: regular.pointSize, weight: .bold)
            let out = NSMutableAttributedString()
            for line in lines {
                for s in line {
                    out.append(NSAttributedString(string: s.text, attributes: [.font: s.bold ? bold : regular, .foregroundColor: color(s.tone)]))
                }
                out.append(NSAttributedString(string: "\n", attributes: [.font: regular]))
            }
            tv.textStorage?.append(out)
            tv.scrollToEndOfDocument(nil)
        }
    }
}
