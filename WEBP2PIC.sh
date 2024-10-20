#!/bin/bash

# Überprüfen, ob alle Parameter übergeben wurden
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <source_directory> <target_directory> <output_format>"
    exit 1
fi

# Eingabeparameter speichern
SOURCE_DIR=$1
TARGET_DIR=$2
OUTPUT_FORMAT=$3

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

# Alle .webp Dateien im Quellverzeichnis durchlaufen und konvertieren
for file in "$SOURCE_DIR"/*.webp; do
    if [ -f "$file" ]; then
        # Dateiname ohne Erweiterung extrahieren
        filename=$(basename "$file" .webp)
        # Datei konvertieren und im Zielverzeichnis speichern
        magick "$file" "$TARGET_DIR/$filename.$OUTPUT_FORMAT"
        if [ $? -eq 0 ]; then
            echo "Converted: $file -> $TARGET_DIR/$filename.$OUTPUT_FORMAT"
        else
            echo "Error converting: $file"
        fi
    fi
done

echo "Conversion completed!"