#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# convert_audio.sh – Batch‑Konvertierung beliebiger Audiodateien per ffmpeg
# ---------------------------------------------------------------------------
# Usage:
#   ./convert_audio.sh <directory> <source_ext> <target_ext>
#
#   <directory>   Wurzelordner, der rekursiv nach Audiodateien durchsucht wird
#   <source_ext>  Ausgangsformat (z. B. mp3, wav) – ohne Punkt oder mit
#   <target_ext>  Zielformat (z. B. flac, ogg) – ohne Punkt oder mit
#
# Voraussetzungen:
#   • ffmpeg (https://ffmpeg.org/) muss im PATH verfügbar sein.
#   • Bash ≥ 4 (wegen set -euo pipefail)
#
# Die Skript‑Logik:
#   • Ruft `find` rekursiv auf, um alle Dateien mit der Endung aus
#     <source_ext> zu ermitteln.
#   • Bildet für jede Datei den Zielnamen, indem die Endung ersetzt wird.
#   • Führt ffmpeg‑Konvertierung aus; vorhandene Zieldateien werden
#     übersprungen, um Doppelarbeit zu vermeiden.
#   • Behält Verzeichnisstruktur bei.
# ---------------------------------------------------------------------------
set -euo pipefail
IFS=$'\n\t'

usage() {
  printf "Usage: %s <directory> <source_ext> <target_ext>\n" "${0##*/}" >&2
  exit 1
}

[[ $# -eq 3 ]] || usage

ROOT_DIR=$(realpath "$1")
SRC_EXT=${2#.}
DST_EXT=${3#.}

[[ -d $ROOT_DIR ]] || { echo "Error: '$ROOT_DIR' is not a directory" >&2; exit 2; }
[[ $SRC_EXT != "$DST_EXT" ]] || { echo "Source and target extensions are identical" >&2; exit 3; }
command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg not found – please install" >&2; exit 4; }

count_total=0
count_converted=0

while IFS= read -r -d '' src; do
  ((count_total++))
  rel_path=${src#"$ROOT_DIR/"}
  base_no_ext=${rel_path%.*}
  dst="$ROOT_DIR/${base_no_ext}.${DST_EXT}"

  # Skip if destination already exists
  if [[ -e $dst ]]; then
    echo "[skip] $rel_path → ${base_no_ext}.${DST_EXT} (already exists)"
    continue
  fi

  # Ensure destination directory exists
  mkdir -p "$(dirname "$dst")"

  echo "[conv] $rel_path → ${base_no_ext}.${DST_EXT}"
  # Simple ffmpeg copy; adjust codecs/options as needed
  ffmpeg -loglevel error -y -i "$src" "$dst"
  ((count_converted++))
done < <(find "$ROOT_DIR" -type f -iname "*.${SRC_EXT}" -print0)

echo "\nDone. $count_converted/$count_total files converted to .$DST_EXT."

