#!/bin/bash

# Ordner angeben, in dem die .vtt- und .srt-Dateien durchsucht werden sollen
TARGET_DIR="$1"

# Überprüfen, ob ein Ordner angegeben wurde
if [ -z "$TARGET_DIR" ]; then
    echo "Bitte einen Ordnerpfad als Argument angeben."
    exit 1
fi

# Überprüfen, ob der angegebene Ordner existiert
if [ ! -d "$TARGET_DIR" ]; then
    echo "Der angegebene Ordner existiert nicht."
    exit 1
fi

# Funktion zum Entfernen unerwünschter Texte aus Dateinamen
rename_files() {
    local extension="$1"
    for file in "$TARGET_DIR"/*.$extension; do
        # Überprüfen, ob Dateien existieren
        if [ -e "$file" ]; then
            # Neuer Dateiname ohne [DownloadYoutubeSubtitles.com] und [translated] [DownloadYoutubeSubtitles.com]
            new_file="$(echo "$file" | sed 's/\[translated\] \[DownloadYoutubeSubtitles.com\]//g' | sed 's/\[DownloadYoutubeSubtitles.com\]//g')"

            # Datei umbenennen, falls der neue Name anders ist
            if [ "$file" != "$new_file" ]; then
                mv "$file" "$new_file"
                echo "Umbenannt: $file -> $new_file"
            fi
        fi
    done
}

# Dateien umbenennen für VTT und SRT
rename_files "vtt"
rename_files "srt"

echo "Fertig!"
