#!/bin/bash

# Überprüfen, ob eine URL angegeben wurde
if [ -z "$1" ]; then
    echo "Bitte eine YouTube-Wiedergabelisten-URL als Argument angeben!"
    exit 1
fi

# Zielverzeichnis für die Downloads
DOWNLOAD_DIR="${HOME}/Downloads/YT-Playlist"

# Erstelle das Zielverzeichnis, falls es nicht existiert
mkdir -p "$DOWNLOAD_DIR"

# Herunterladen der Wiedergabeliste
yt-dlp --yes-playlist --format "bestvideo+bestaudio/best" \
       --output "${DOWNLOAD_DIR}/%(playlist_title)s/%(playlist_index)s - %(title)s.%(ext)s" \
       "$1"

echo "Download abgeschlossen! Videos sind unter $DOWNLOAD_DIR verfügbar."

