#!/bin/bash

# Überprüfen, ob 2 oder optional 3 Parameter übergeben wurden
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    echo "Usage: $0 <source_directory> <target_directory> [quality (optional)]"
    exit 1
fi

# Eingabeparameter speichern
SOURCE_DIR=$1
TARGET_DIR=$2
QUALITY=$3  # Optionaler Parameter für die Kompressionsqualität

# Überprüfen, ob die Komprimierungsprogramme installiert sind
if ! command -v jpegoptim &> /dev/null || ! command -v pngquant &> /dev/null || ! command -v gifsicle &> /dev/null; then
    echo "Error: Please install jpegoptim, pngquant, and gifsicle for JPEG, PNG, and GIF compression."
    exit 1
fi

# Überprüfen, ob das Quellverzeichnis existiert
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory does not exist."
    exit 1
fi

# Zielverzeichnis erstellen, falls es nicht existiert
mkdir -p "$TARGET_DIR"

# Unterstützte Bildformate
formats=("jpg" "jpeg" "png" "gif")

# Funktion zur Bildkompression
compress_image() {
    local file=$1
    local format=$2
    local output_file="$TARGET_DIR/$(basename "$file")"

    case $format in
        jpg|jpeg)
            # JPEG-Komprimierung mit jpegoptim
            if [ -n "$QUALITY" ]; then
                jpegoptim --max="$QUALITY" --dest="$TARGET_DIR" "$file"
            else
                jpegoptim --dest="$TARGET_DIR" "$file"
            fi
            ;;
        png)
            # PNG-Komprimierung mit pngquant
            if [ -n "$QUALITY" ]; then
                pngquant --quality="$QUALITY" --force --output "$output_file" "$file"
            else
                pngquant --force --output "$output_file" "$file"
            fi
            ;;
        gif)
            # GIF-Komprimierung mit gifsicle
            gifsicle -O3 "$file" -o "$output_file"
            ;;
        *)
            echo "Unsupported format: $format"
            ;;
    esac
}

# Alle Dateien in den angegebenen Formaten durchlaufen und komprimieren
for format in "${formats[@]}"; do
    for file in "$SOURCE_DIR"/*.$format; do
        if [ -f "$file" ]; then
            echo "Processing: $file"
            compress_image "$file" "$format"
            if [ $? -eq 0 ]; then
                echo "Compressed: $file -> $TARGET_DIR/$(basename "$file")"
            else
                echo "Error compressing: $file"
            fi
        fi
    done
done

echo "Compression completed!"

# ./compress_images_alt.sh /pfad/zum/quellordner /pfad/zum/zielordner
# ./compress_images_alt.sh /pfad/zum/quellordner /pfad/zum/zielordner 75