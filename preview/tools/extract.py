#!/usr/bin/env python3
"""Extrait des sources Python (sans les exécuter) les données affichées par la preview :
traductions, langues, règles de filtrage. Sortie JSON sur stdout."""
import ast
import json
import sys
from pathlib import Path

SRC = Path(sys.argv[1])


def module(name: str) -> ast.Module:
    return ast.parse((SRC / name).read_text(encoding="utf-8"))


def top_level(tree: ast.Module) -> dict:
    """Constantes de niveau module (dict, list, set de littéraux)."""
    out = {}
    for node in tree.body:
        target = None
        if isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Name):
            target, value = node.targets[0].id, node.value
        elif isinstance(node, ast.AnnAssign) and isinstance(node.target, ast.Name) and node.value:
            target, value = node.target.id, node.value
        if target and target.isupper():
            try:
                v = ast.literal_eval(value)
            except ValueError:
                continue
            out[target] = sorted(v) if isinstance(v, set) else v
    return out


def patterns(values: list) -> list:
    """Motifs de niveau module (chaînes), tous insensibles à la casse."""
    return [{"source": v, "flags": "i"} for v in values]


cleaner = module("flattener_cleaner.py")
c = top_level(cleaner)

print(json.dumps({
    "cleaner": {
        "translations": c["TRANSLATIONS"],
        "languages": c["LANGUAGES"],
        "filePatterns": patterns(c["FILE_PATTERNS"]),
        "dirPatterns": patterns(c["DIR_PATTERNS"]),
    },
}, ensure_ascii=False))
