#!/bin/bash

# Hilfefunktion anzeigen
function show_help {
    echo "Usage: $0 -source <source_folder> -target <target_folder> -from <source_format> -to <target_format>"
    echo "Supported formats: webm, mp4, mkv, avi"
    exit 1
}

# Parameter einlesen
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -source)
            SOURCE_DIR="$2"
            shift 2
            ;;
        -target)
            TARGET_DIR="$2"
            shift 2
            ;;
        -from)
            SOURCE_FORMAT="$2"
            shift 2
            ;;
        -to)
            TARGET_FORMAT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
done

# Überprüfen, ob alle Parameter gesetzt sind
if [[ -z "$SOURCE_DIR" || -z "$TARGET_DIR" || -z "$SOURCE_FORMAT" || -z "$TARGET_FORMAT" ]]; then
    echo "Error: Missing required arguments."
    show_help
fi

# Überprüfen, ob die Formate unterstützt werden
SUPPORTED_FORMATS=("webm" "mp4" "mkv" "avi")
if [[ ! " ${SUPPORTED_FORMATS[@]} " =~ " ${SOURCE_FORMAT} " ]]; then
    echo "Error: Unsupported source format '$SOURCE_FORMAT'."
    show_help
fi
if [[ ! " ${SUPPORTED_FORMATS[@]} " =~ " ${TARGET_FORMAT} " ]]; then
    echo "Error: Unsupported target format '$TARGET_FORMAT'."
    show_help
fi

# Überprüfen, ob der Quellordner existiert
if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Error: Source folder '$SOURCE_DIR' does not exist."
    exit 1
fi

# Zielordner erstellen, falls nicht vorhanden
mkdir -p "$TARGET_DIR"

# Konvertierung starten
for file in "$SOURCE_DIR"/*.$SOURCE_FORMAT; do
    if [[ -f "$file" ]]; then
        filename=$(basename -- "$file")
        filename_no_ext="${filename%.*}"
        output_file="$TARGET_DIR/$filename_no_ext.$TARGET_FORMAT"

        echo "Converting '$file' to '$output_file'..."
        ffmpeg -i "$file" "$output_file"
        if [[ $? -ne 0 ]]; then
            echo "Error converting '$file'. Skipping..."
        else
            echo "Successfully converted: '$file' to '$output_file'"
        fi
    fi
done

echo "Conversion process completed! Files are available in '$TARGET_DIR'."

# ./convert_video_formats.sh -source <source_folder> -target <target_folder> -from <source_format> -to <target_format>
# ./convert_video_formats.sh -source ./videos -target ./converted -from webm -to mp4

