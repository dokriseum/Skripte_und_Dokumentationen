#!/usr/bin/env python3
"""
merge_sources_to_md.py – Rekursiv alle Quell-/Textdateien in eine Markdown-Datei zusammenführen.

Neu in Version 1.1 (2025‑08‑01)
—————————————————————————
• **.gitignore‑Unterstützung**: Erkennt eine .git‑Dateistruktur und ignoriert automatisch alle per .gitignore ausgeschlossenen Pfade (setzt `git` im PATH voraus). Falls keine .gitignore vorhanden ist oder git fehlt, arbeitet das Skript wie zuvor.

Funktionen
──────────
* Rekursive Suche ab *root_dir* nach Dateien mit konfigurierten oder via `--ext` übergebenen Erweiterungen.
* Jeder relative Pfad erscheint als Markdown‑Überschrift (`##`).
* Dateiinhalt folgt in einem sprachgetaggten Code‑Fence (```python, ```html…). Für unbekannte Endungen wird `text` verwendet.
* Zeilenenden werden in LF konvertiert; abschließende Leerzeile entfernt.
* Default‑Output: *merged_output.md* im Root‑Verzeichnis.
"""

from __future__ import annotations

import argparse
import subprocess
import shutil
from pathlib import Path
from typing import Dict, List

DEFAULT_EXTS = [
    ".txt", ".md", ".html", ".htm", ".css", ".js", ".ts", ".json",
    ".yaml", ".yml", ".py", ".java", ".c", ".cpp", ".h", ".hpp",
    ".sh", ".bat", ".xml", ".ini", ".cfg", ".csv", ".lua", ".toml"
]

LANG_MAP: Dict[str, str] = {
    ".js": "js",
    ".css": "css",
    ".html": "html",
    ".htm": "html",
    ".md": "md",
    ".yaml": "yaml",
    ".yml": "yaml",
    ".json": "json",
    ".py": "python",
    ".java": "java",
    ".c": "c",
    ".cpp": "cpp",
    ".h": "c",
    ".hpp": "cpp",
    ".sh": "bash",
    ".bat": "bat",
    ".xml": "xml",
    ".ini": "ini",
    ".cfg": "ini",
    ".csv": "csv",
    ".ts": "ts",
    ".lua": "lua",
    ".toml": "toml"
}


def parse_ext_list(ext_string: str) -> List[str]:
    """Wandelt eine Kommaliste in eine normalisierte Erweiterungs‑Liste um."""
    exts = [e.strip().lower() for e in ext_string.split(",") if e.strip()]
    return [e if e.startswith(".") else f".{e}" for e in exts]


class GitIgnoreFilter:
    """Filtert Pfade mit Hilfe von `git check-ignore` anhand der .gitignore."""

    def __init__(self, root: Path):
        self.root: Path = root
        self.enabled: bool = (
            (root / ".gitignore").exists()
            and (root / ".git").exists()
            and shutil.which("git") is not None
        )
        if self.enabled:
            # Test einmalig, um ggf. frühzeitig zu scheitern
            try:
                subprocess.run(
                    ["git", "-C", str(root), "check-ignore", "--help"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    check=False,
                )
            except Exception:
                self.enabled = False

    def is_ignored(self, rel_path: Path) -> bool:
        if not self.enabled:
            return False
        result = subprocess.run(
            [
                "git",
                "-C",
                str(self.root),
                "check-ignore",
                "-q",
                "--",
                str(rel_path),
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return result.returncode == 0


def gather_files(root: Path, exts: List[str], gi_filter: GitIgnoreFilter) -> List[Path]:
    """Liefert alle passenden Dateien, minus .gitignore‑Treffer."""
    out: List[Path] = []
    for p in root.rglob("*"):
        if p.is_file() and p.suffix.lower() in exts:
            rel = p.relative_to(root)
            if gi_filter.is_ignored(rel):
                continue
            out.append(p)
    return sorted(out)


def write_markdown(paths: List[Path], root: Path, output: Path) -> None:
    """Schreibt die Dateien in eine Markdown‑Datei."""
    with output.open("w", encoding="utf-8", newline="\n") as md:
        for p in paths:
            rel = p.relative_to(root)
            md.write(f"## {rel}\n\n")
            lang = LANG_MAP.get(p.suffix.lower(), "text")
            md.write(f"```{lang}\n")
            content = (
                p.read_text(encoding="utf-8", errors="replace")
                .rstrip("\n")
                .replace("\r\n", "\n")
            )
            md.write(content)
            md.write("\n```\n\n")
    print(f"{len(paths)} Dateien wurden in '{output}' zusammengeführt.")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Fasst Quell-/Textdateien zu einer Markdown‑Datei zusammen und respektiert .gitignore.")
    parser.add_argument("root_dir", help="Wurzelordner, der rekursiv durchsucht wird")
    parser.add_argument(
        "output_md",
        nargs="?",
        default=None,
        help="Pfad/Name der Ausgabedatei (Default: merged_output.md im Root‑Ordner)",
    )
    parser.add_argument(
        "--ext",
        default=",".join(DEFAULT_EXTS),
        help="Kommagetrennte Liste von Dateiendungen, die zusätzlich berücksichtigt werden",
    )
    args = parser.parse_args()

    root = Path(args.root_dir).resolve()
    if not root.is_dir():
        raise SystemExit(f"Fehler: {root} ist kein Verzeichnis.")

    gi_filter = GitIgnoreFilter(root)
    if gi_filter.enabled:
        print(".gitignore erkannt – ignorierte Pfade werden übersprungen.")

    exts = parse_ext_list(args.ext)
    files = gather_files(root, exts, gi_filter)
    if not files:
        raise SystemExit("Keine passenden Dateien gefunden.")

    out = Path(args.output_md) if args.output_md else root / "merged_output.md"
    write_markdown(files, root, out)


if __name__ == "__main__":
    main()