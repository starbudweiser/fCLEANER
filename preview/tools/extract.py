#!/usr/bin/env python3
"""Lit pour la preview, sans rien exécuter : la table de traductions (i18n/strings.json), les motifs de filtrage
(macos/Sources/CleanCore/Patterns.swift) et les règles affichées (macos/Sources/fCLEANER/RulesView.swift).
usage : extract.py <dossier du projet> ; sortie JSON sur stdout."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(sys.argv[1])
swift = lambda p: (ROOT / "macos" / "Sources" / p).read_text(encoding="utf-8")


def block(src: str, name: str) -> list:
    """Motifs `#"…"#` d'un tableau Swift (static let <name>: [String] = [ … ])."""
    m = re.search(rf"static let {name}: \[String\] = \[(.*?)\n    \]", src, re.S)
    return [{"source": p, "flags": "i"} for p in re.findall(r'#"(.*?)"#', m.group(1))]


def lit(s: str) -> str:
    return json.loads('"' + s + '"')


patterns = swift("CleanCore/Patterns.swift")
rules_src = swift("fCLEANER/RulesView.swift")
sections = []
for m in re.finditer(r'RuleSection\(title: N_\("((?:[^"\\]|\\.)*)"\), items: \[(.*?)\]\)', rules_src, re.S):
    sections.append({"title": lit(m.group(1)),
                     "items": [lit(i) for i in re.findall(r'N_\("((?:[^"\\]|\\.)*)"\)', m.group(2))]})
note = lit(re.search(r'let rulesNote = N_\("((?:[^"\\]|\\.)*)"\)', rules_src).group(1))

print(json.dumps({
    "cleaner": {
        "strings": json.loads((ROOT / "i18n" / "strings.json").read_text(encoding="utf-8")),
        "filePatterns": block(patterns, "file"),
        "dirPatterns": block(patterns, "dir"),
        "rules": sections,
        "note": note,
    },
}, ensure_ascii=False))
