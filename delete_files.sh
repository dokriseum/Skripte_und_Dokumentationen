#!/bin/bash

# Überprüfen, ob eine Dateierweiterung als Argument übergeben wurde
if [ -z "$1" ]; then
  echo "Bitte geben Sie die zu löschende Dateierweiterung an (z. B. .meta)."
  exit 1
fi

# Speichern der angegebenen Dateierweiterung
EXTENSION="$1"

# Festlegen des Zielverzeichnisses (Standardmäßig aktuelles Verzeichnis)
TARGET_DIR="${2:-.}"

# Bestätigung vom Benutzer einholen
read -p "Möchten Sie wirklich alle Dateien mit der Erweiterung '$EXTENSION' im Verzeichnis '$TARGET_DIR' und dessen Unterverzeichnissen löschen? (j/n): " CONFIRMATION

if [[ "$CONFIRMATION" != [jJ] ]]; then
  echo "Abgebrochen."
  exit 0
fi

# Finden und Löschen der Dateien
find "$TARGET_DIR" -type f -name "*$EXTENSION" -exec rm -v {} \;

echo "Löschvorgang abgeschlossen."

