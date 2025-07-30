#!/bin/bash


# Aufruf
# ./download_playlist.sh "https://www.youtube.com/playlist?list=PL1234567890"
# ./download_playlist.sh "https://www.youtube.com/playlist?list=PL1234567890" "/Pfad/zum/Ordner"


# Setze die Wiedergabelisten-URL und das Speicherverzeichnis
PLAYLIST_URL="$1"
OUTPUT_DIR="${2:-$HOME/Movies/Youtube}"

# Erstelle das Verzeichnis, falls es nicht existiert
mkdir -p "$OUTPUT_DIR"

# Lade die Videos mit deutschen und englischen Untertiteln herunter
yt-dlp \
    --format "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]" \
    --write-auto-sub \
    --sub-langs "de,en" \
    --embed-subs \
    --merge-output-format mp4 \
    --output "$OUTPUT_DIR/%(playlist_index)s - %(title)s.%(ext)s" \
    "$PLAYLIST_URL"

echo "Download abgeschlossen. Videos gespeichert in: $OUTPUT_DIR"
