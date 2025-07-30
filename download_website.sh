#!/bin/bash

# Überprüfen, ob eine URL angegeben wurde
if [ -z "$1" ]; then
    echo "Usage: $0 <URL>"
    exit 1
fi

URL="$1"
OUTPUT_DIR="${2:-$(basename "$URL")}"  # Optionaler zweiter Parameter für das Zielverzeichnis

echo "Starte den Download der Website: $URL"
echo "Speichere in Verzeichnis: $OUTPUT_DIR"

wget --mirror \           # Rekursiver Download der gesamten Website
     --convert-links \    # Wandelt Links so um, dass sie lokal funktionieren
     --adjust-extension \ # Fügt passende Dateiendungen hinzu
     --page-requisites \  # Lädt alle benötigten Dateien (Bilder, CSS, JS)
     --no-parent \        # Verhindert, dass wget außerhalb der Hauptdomain navigiert
     --wait=1 \           # Wartet 1 Sekunde zwischen den Anfragen (Vermeidung von Überlastung)
     --limit-rate=500k \  # Begrenzung der Downloadgeschwindigkeit
     --random-wait \      # Variiert die Wartezeit zwischen Anfragen
     --user-agent="Mozilla/5.0 (compatible; wget)" \ # Vermeidet Blockierung durch Server
     --directory-prefix="$OUTPUT_DIR" \ # Speicherort
     "$URL"

echo "Download abgeschlossen. Die Website wurde in '$OUTPUT_DIR' gespeichert."

