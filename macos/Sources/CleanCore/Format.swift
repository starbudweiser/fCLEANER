// Tailles lisibles, identiques à la version Python (unités de 1024, point décimal dans toutes les langues).

import Foundation

public func formatSize(_ bytes: Int64) -> String {
    let b = Double(bytes)
    if bytes < 1024 { return "\(bytes) \(L("octets"))" }
    if bytes < 1024 * 1024 { return String(format: "%.1f", b / 1024) + " " + L("Ko") }
    if bytes < 1024 * 1024 * 1024 { return String(format: "%.2f", b / (1024 * 1024)) + " " + L("Mo") }
    return String(format: "%.2f", b / (1024 * 1024 * 1024)) + " " + L("Go")
}
