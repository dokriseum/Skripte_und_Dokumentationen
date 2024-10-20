#!/bin/bash

# Überprüfen, ob mindestens 1 oder optional 2 Parameter übergeben wurden
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 <source_directory> [quality (optional)]"
    exit 1
fi

# Eingabeparameter speichern
SOURCE_DIR=$1
QUALITY=$2  # Optionaler Parameter für die Kompressionsqualität

# Überprüfen, ob das magick-Kommando verfügbar ist
if ! command -v magick &> /dev/null; then
    echo "Error: 'magick' is not installed or not in the PATH."
    exit 1
fi

# Überprüfen, ob das Quellverzeichnis existiert
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory does not exist."
    exit 1
fi

# Unterstützte Bildformate
formats=("jpg" "jpeg" "png" "gif" "webp")

# Alle Dateien in den angegebenen Formaten durchlaufen
for format in "${formats[@]}"; do
    for file in "$SOURCE_DIR"/*.$format; do
        if [ -f "$file" ]; then
            # Dateiname ohne Erweiterung extrahieren
            filename=$(basename "$file")
            extension="${filename##*.}"
            base="${filename%.*}"

            # Kompressionsvorgang basierend auf den Dateiformaten
            echo "Processing: $file"

            if [ -n "$QUALITY" ]; then
                # Konvertieren mit Qualitätsstufe, falls angegeben
                magick "$file" -quality "$QUALITY" "$SOURCE_DIR/compressed_$base.$extension"
            else
                # Konvertieren ohne explizite Qualitätsstufe
                magick "$file" "$SOURCE_DIR/compressed_$base.$extension"
            fi

            # Überprüfung auf Fehler
            if [ $? -eq 0 ]; then
                echo "Compressed: $file -> $SOURCE_DIR/compressed_$base.$extension"
            else
                echo "Error compressing: $file"
            fi
        fi
    done
done

echo "Compression completed!"

# ./compress_images.sh /pfad/zum/quellordner
# ./compress_images.sh /pfad/zum/quellordner 75