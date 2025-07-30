#!/bin/bash

# Überprüfen, ob ein Zielverzeichnis als Argument übergeben wurde
if [ -z "$1" ]; then
    BACKUP_DIR="$HOME/Desktop/FontBackup_$(date +%Y-%m-%d_%H-%M-%S)"
else
    BACKUP_DIR="$1"
fi

# Erstelle das Zielverzeichnis, falls es nicht existiert
mkdir -p "$BACKUP_DIR"

# Schriftarten-Verzeichnisse
FONT_DIRS=(
    "/System/Library/Fonts/Supplemental"
    "/System/Library/Fonts"
    "/Library/Fonts"
    "$HOME/Library/Fonts"
)

echo "🔍 Sammle Schriftarten aus den folgenden Verzeichnissen:"
for DIR in "${FONT_DIRS[@]}"; do
    echo "   - $DIR"
    if [ -d "$DIR" ]; then
        cp -R "$DIR"/* "$BACKUP_DIR" 2>/dev/null
    fi
done

# Entferne doppelte Dateien
echo "🗑️ Entferne doppelte Schriftarten..."
cd "$BACKUP_DIR" || exit
find . -type f -name "*.ttf" -o -name "*.otf" | awk -F/ '{print $NF}' | sort | uniq -d | while read -r file; do
    find . -type f -name "$file" -delete
done

# Archivieren als ZIP oder TAR.GZ
ARCHIVE_NAME="${BACKUP_DIR}_$(date +%Y-%m-%d_%H-%M-%S)"
echo "📦 Erstelle Archiv..."

# Archiv-Format auswählen
echo "Wähle das Archiv-Format:"
echo "1) ZIP"
echo "2) TAR.GZ"
read -p "Deine Wahl (1/2): " format

if [ "$format" == "1" ]; then
    zip -r "$ARCHIVE_NAME.zip" ./*
    echo "✅ Archiv erstellt: $ARCHIVE_NAME.zip"
elif [ "$format" == "2" ]; then
    tar -czf "$ARCHIVE_NAME.tar.gz" ./*
    echo "✅ Archiv erstellt: $ARCHIVE_NAME.tar.gz"
else
    echo "❌ Ungültige Eingabe. Es wurde kein Archiv erstellt."
fi

# Optional: Entferne den temporären Backup-Ordner
rm -rf "$BACKUP_DIR"
echo "🧹 Temporäre Dateien gelöscht."

echo "✅ Schriftarten-Backup abgeschlossen!"

