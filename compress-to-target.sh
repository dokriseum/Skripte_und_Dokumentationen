#!/usr/bin/env bash
# Usage: compress-to-target.sh input.pdf 4M   # auf ≤ 4 MiB

set -euo pipefail

in="$1"
target_bytes=$(numfmt --from=iec "$2")   # 4M → 4194304
base="${in%.*}"
tmp=$(mktemp "${base}.XXXXXX.pdf")

# Presets in absteigender Qualität
declare -a PRESETS=(
  "/prepress"   # höchste
  "/printer"
  "/ebook"
  "/screen"     # stärkste Kompression
)

for preset in "${PRESETS[@]}"; do
  gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.6 \
     -dPDFSETTINGS=$preset -dNOPAUSE -dQUIET -dBATCH \
     -sOutputFile="$tmp" "$in"
  size=$(stat -f%z "$tmp")
  if (( size <= target_bytes )); then
      mv "$tmp" "${base}-compressed.pdf"
      echo "✅ ${base}-compressed.pdf → $(numfmt --to=iec "$size")"
      exit 0
  fi
done

echo "⚠️ Selbst stärkste Voreinstellung überschreitet Zielgröße." >&2
exit 1

