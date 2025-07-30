#!/bin/bash

# Pfad zum Zielverzeichnis (Standardmäßig aktuelles Verzeichnis)
TARGET_DIR="${1:-.}"

# Überprüfen, ob .gitignore im Zielverzeichnis existiert
if [[ ! -f "$TARGET_DIR/.gitignore" ]]; then
  echo "Keine .gitignore-Datei im Verzeichnis $TARGET_DIR gefunden."
  exit 1
fi

# Liest die .gitignore-Datei Zeile für Zeile
while IFS= read -r pattern; do
  # Überspringt leere Zeilen und Kommentare
  if [[ -z "$pattern" || "$pattern" == \#* ]]; then
    continue
  fi

  # Entfernt führende und nachfolgende Leerzeichen
  pattern=$(echo "$pattern" | xargs)

  # Entfernt ein führendes '/' für die Verwendung mit find
  if [[ "$pattern" == /* ]]; then
    pattern="${pattern:1}"
  fi

  # Findet und löscht Dateien und Verzeichnisse, die dem Muster entsprechen
  find "$TARGET_DIR" -path "$TARGET_DIR/$pattern" -exec rm -rf {} +

done < "$TARGET_DIR/.gitignore"

