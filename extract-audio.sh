#!/usr/bin/env bash

set -euo pipefail

# Extract audio from a single video file or all videos in a directory (optionally recursive)
# Defaults: m4a (AAC) @ 192k. Supports mp3, wav, flac.
# Usage:
#   ./extract-audio.sh <input-file|input-dir> [--format m4a|mp3|wav|flac] [--bitrate 192k] [--outdir /path/to/out] [--recursive] [--overwrite]
# 
# ##########################################################################
# ##########################################################################
#  
# Einzelne Datei in m4a (AAC, 192k)
# ./extract-audio.sh "/Pfad/zu/Video.mp4"
# 
# Alle Videos in einem Ordner (nicht rekursiv) zu MP3 (256k)
# ./extract-audio.sh "/Pfad/zu/Videos" --format mp3 --bitrate 256k
# 
# Rekursiv über Unterordner, Ausgabe gesammelt in separatem Ordner
# ./extract-audio.sh "/Pfad/zu/Videos" --recursive --outdir "/Pfad/zu/Ausgabe"
# 
# Existierende Dateien überschreiben
# ./extract-audio.sh "/Pfad/zu/Videos" --format flac --overwrite
# 
# ##########################################################################
# ##########################################################################

FORMAT="m4a"
BITRATE="192k"
OUTDIR=""
RECURSIVE=false
OVERWRITE=false

die() { echo "Error: $*" >&2; exit 1; }

command -v ffmpeg >/dev/null 2>&1 || die "ffmpeg ist nicht installiert. Installiere mit: brew install ffmpeg"

# --- parse args ---
INPUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --format) FORMAT="${2:-}"; shift 2;;
    --bitrate) BITRATE="${2:-}"; shift 2;;
    --outdir) OUTDIR="${2:-}"; shift 2;;
    --recursive) RECURSIVE=true; shift;;
    --overwrite) OVERWRITE=true; shift;;
    -h|--help)
      cat <<EOF
Usage: $0 <input-file|input-dir> [options]

Options:
  --format m4a|mp3|wav|flac   Zielformat (Default: m4a)
  --bitrate <rate>            Audio-Bitrate für AAC/MP3, z.B. 192k (Default: 192k)
  --outdir <dir>              Ausgabeverzeichnis (Default: neben Eingabedatei/Ordner)
  --recursive                 Ordner rekursiv durchsuchen
  --overwrite                 Existierende Zieldateien überschreiben
EOF
      exit 0;;
    *)
      if [[ -z "$INPUT" ]]; then INPUT="$1"; else die "Unerwartetes Argument: $1"; fi
      shift;;
  esac
done

[[ -n "${INPUT:-}" ]] || die "Bitte eine Videodatei oder einen Ordner angeben. Siehe --help"

# --- codec mapping ---
CODEC_ARGS=()
fmt="$(printf '%s' "$FORMAT" | tr '[:upper:]' '[:lower:]')"
case "$fmt" in
  m4a|aac)   FORMAT="m4a"; CODEC_ARGS=(-c:a aac -b:a "$BITRATE");;
  mp3)       CODEC_ARGS=(-c:a libmp3lame -b:a "$BITRATE");;
  wav)       CODEC_ARGS=(-c:a pcm_s16le);;
  flac)      CODEC_ARGS=(-c:a flac);;
  *)         die "Unbekanntes Format: $FORMAT (erlaubt: m4a, mp3, wav, flac)";;
esac


# --- helpers ---
ff_overwrite_flag=("-n")
$OVERWRITE && ff_overwrite_flag=("-y")

ext_regex() {
  # BSD find (macOS) Tipp: Klammern escapen
  echo \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.m4v' -o -iname '*.mkv' -o -iname '*.avi' -o -iname '*.webm' \)
}

out_path_for() {
  local in="$1"
  local base="${in##*/}"
  base="${base%.*}.${FORMAT}"
  local dir out
  if [[ -n "$OUTDIR" ]]; then
    if [[ -d "$INPUT" ]]; then
      # Ordnermodus: relative Struktur beibehalten
      local rel="${in#"$INPUT"/}"
      local rel_dir="$(dirname "$rel")"
      dir="$OUTDIR/$rel_dir"
    else
      dir="$OUTDIR"
    fi
    mkdir -p "$dir"
  else
    dir="$(dirname "$in")"
  fi
  out="$dir/$base"
  echo "$out"
}

process_file() {
  local in="$1"
  [[ -f "$in" ]] || return 0
  local out; out="$(out_path_for "$in")"
  
  echo ">> Konvertiere:"
  echo "   IN : $in"
  echo "   OUT: $out"
  
  # Gemeinsame Flags
  local ff_flags=(-hide_banner -loglevel error -stats -nostdin)
  
  if [[ "${FORMAT}" == "m4a" ]]; then
    ffmpeg "${ff_flags[@]}" -i "$in" -vn "${CODEC_ARGS[@]}" -map_metadata 0 -movflags +faststart \
    "${ff_overwrite_flag[@]}" "$out" </dev/null
  else
    ffmpeg "${ff_flags[@]}" -i "$in" -vn "${CODEC_ARGS[@]}" -map_metadata 0 \
    "${ff_overwrite_flag[@]}" "$out" </dev/null
  fi
}


# --- main ---
if [[ -f "$INPUT" ]]; then
  process_file "$INPUT"
elif [[ -d "$INPUT" ]]; then
  if $RECURSIVE; then
    # rekursiv
    find "$INPUT" -type f \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.m4v' -o -iname '*.mkv' -o -iname '*.avi' -o -iname '*.webm' \) -print0 \
    | while IFS= read -r -d '' f; do
      process_file "$f"
    done
  else
    # NICHT rekursiv (BSD find hat kein -maxdepth: wir nutzen -prune)
    find "$INPUT" \
    -type d -mindepth 1 -prune -o \
    -type f \( -iname '*.mp4' -o -iname '*.mov' -o -iname '*.m4v' -o -iname '*.mkv' -o -iname '*.avi' -o -iname '*.webm' \) -print0 \
    | while IFS= read -r -d '' f; do
      process_file "$f"
    done
  fi
else
  die "Pfad nicht gefunden: $INPUT"
fi

echo "Fertig."

