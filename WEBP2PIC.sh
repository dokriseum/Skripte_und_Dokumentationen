#!/bin/bash

# Überprüfen, ob mindestens 4 oder optional 5 Parameter übergeben wurden
if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
    echo "Usage: $0 <source_directory> <source_format> <target_directory> <output_format> [quality (optional)]"
    exit 1
fi

# Eingabeparameter speichern
SOURCE_DIR=$1
SOURCE_FORMAT=$2
TARGET_DIR=$3
OUTPUT_FORMAT=$4
QUALITY=$5  # Optionaler Parameter für die Kompressionsqualität

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

# Zielverzeichnis erstellen, falls es nicht existiert
mkdir -p "$TARGET_DIR"

# Alle Dateien des angegebenen Quellformats im Quellverzeichnis durchlaufen und konvertieren
for file in "$SOURCE_DIR"/*.$SOURCE_FORMAT; do
    if [ -f "$file" ]; then
        # Dateiname ohne Erweiterung extrahieren
        filename=$(basename "$file" .$SOURCE_FORMAT)
        
        # Wenn die Qualitätsgröße angegeben ist, konvertiere mit der Option -quality
        if [ -n "$QUALITY" ]; then
            magick "$file" -quality "$QUALITY" "$TARGET_DIR/$filename.$OUTPUT_FORMAT"
        else
            # Ohne Qualitätsoption konvertieren
            magick "$file" "$TARGET_DIR/$filename.$OUTPUT_FORMAT"
        fi

        # Überprüfung auf Fehler
        if [ $? -eq 0 ]; then
            echo "Converted: $file -> $TARGET_DIR/$filename.$OUTPUT_FORMAT"
        else
            echo "Error converting: $file"
        fi
    fi
done

echo "Conversion completed!"

# ./convert_images.sh /pfad/zum/quellordner webp /pfad/zum/zielordner jpg
# ./convert_images.sh /pfad/zum/quellordner webp /pfad/zum/zielordner jpg 75