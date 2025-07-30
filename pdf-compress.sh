#!/bin/bash

# PDF Komprimierungs-Skript für macOS
# Benötigt: Ghostscript (brew install ghostscript)


# Einfache Komprimierung
# ./pdf-compress.sh dokument.pdf

# Mit Qualitätsstufe
# ./pdf-compress.sh -q screen dokument.pdf

# Auf maximale Größe komprimieren
# ./pdf-compress.sh -s 2M dokument.pdf

# Benutzerdefinierte DPI
# ./pdf-compress.sh -q custom:100 dokument.pdf



# Farben für Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Standard-Einstellungen
QUALITY="ebook"
MAX_SIZE=""
OUTPUT_FILE=""

# Hilfe-Funktion
show_help() {
    cat << EOF
PDF Komprimierungs-Skript für macOS

Verwendung: $0 [OPTIONEN] input.pdf [output.pdf]

OPTIONEN:
    -q, --quality LEVEL    Komprimierungsstufe (Standard: ebook)
                          Verfügbare Stufen:
                          - screen     (72 dpi, kleinste Größe, niedrigste Qualität)
                          - ebook      (150 dpi, gute Balance)
                          - printer    (300 dpi, hohe Qualität)
                          - prepress   (300 dpi, höchste Qualität)
                          - custom:DPI (z.B. custom:200 für 200 dpi)
    
    -s, --size SIZE       Maximale Dateigröße (z.B. 5M, 500K)
                         Das Skript versucht die beste Qualität unter dieser Größe
    
    -o, --output FILE    Ausgabedatei (Standard: input_compressed.pdf)
    
    -h, --help          Diese Hilfe anzeigen

BEISPIELE:
    $0 dokument.pdf
    $0 -q screen dokument.pdf klein.pdf
    $0 -s 2M dokument.pdf
    $0 -q custom:100 -s 1M dokument.pdf output.pdf

EOF
    exit 0
}

# Ghostscript prüfen
check_ghostscript() {
    if ! command -v gs &> /dev/null; then
        echo -e "${RED}Fehler: Ghostscript ist nicht installiert!${NC}"
        echo "Installation mit: brew install ghostscript"
        exit 1
    fi
}

# Dateigröße in Bytes konvertieren
size_to_bytes() {
    local size=$1
    local num=${size%[KMG]}
    local unit=${size##*[0-9]}
    
    case $unit in
        K) echo $((num * 1024)) ;;
        M) echo $((num * 1024 * 1024)) ;;
        G) echo $((num * 1024 * 1024 * 1024)) ;;
        *) echo $num ;;
    esac
}

# Dateigröße formatiert ausgeben
format_size() {
    local bytes=$1
    if [ $bytes -gt 1073741824 ]; then
        echo "$(bc -l <<< "scale=2; $bytes/1073741824")G"
    elif [ $bytes -gt 1048576 ]; then
        echo "$(bc -l <<< "scale=2; $bytes/1048576")M"
    elif [ $bytes -gt 1024 ]; then
        echo "$(bc -l <<< "scale=2; $bytes/1024")K"
    else
        echo "${bytes}B"
    fi
}

# PDF komprimieren
compress_pdf() {
    local input_file=$1
    local output_file=$2
    local quality=$3
    local dpi=""
    
    # DPI basierend auf Qualität setzen
    case $quality in
        screen)    dpi=72 ;;
        ebook)     dpi=150 ;;
        printer)   dpi=300 ;;
        prepress)  dpi=300 ;;
        custom:*)  dpi=${quality#custom:} ;;
        *)         
            echo -e "${RED}Fehler: Unbekannte Qualitätsstufe '$quality'${NC}"
            exit 1
            ;;
    esac
    
    # Ghostscript-Befehl ausführen
    echo -e "${YELLOW}Komprimiere PDF mit $quality Qualität (${dpi} DPI)...${NC}"
    
    if [[ $quality == "prepress" ]]; then
        gs -sDEVICE=pdfwrite \
           -dCompatibilityLevel=1.4 \
           -dPDFSETTINGS=/$quality \
           -dNOPAUSE \
           -dQUIET \
           -dBATCH \
           -sOutputFile="$output_file" \
           "$input_file" 2>/dev/null
    else
        gs -sDEVICE=pdfwrite \
           -dCompatibilityLevel=1.4 \
           -dPDFSETTINGS=/${quality%%:*} \
           -dDownsampleColorImages=true \
           -dDownsampleGrayImages=true \
           -dDownsampleMonoImages=true \
           -dColorImageResolution=$dpi \
           -dGrayImageResolution=$dpi \
           -dMonoImageResolution=$dpi \
           -dColorImageDownsampleThreshold=1.0 \
           -dGrayImageDownsampleThreshold=1.0 \
           -dMonoImageDownsampleThreshold=1.0 \
           -dNOPAUSE \
           -dQUIET \
           -dBATCH \
           -sOutputFile="$output_file" \
           "$input_file" 2>/dev/null
    fi
    
    return $?
}

# Hauptprogramm
main() {
    local input_file=""
    
    # Argumente parsen
    while [[ $# -gt 0 ]]; do
        case $1 in
            -q|--quality)
                QUALITY="$2"
                shift 2
                ;;
            -s|--size)
                MAX_SIZE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                ;;
            -*)
                echo -e "${RED}Fehler: Unbekannte Option $1${NC}"
                show_help
                ;;
            *)
                if [[ -z "$input_file" ]]; then
                    input_file="$1"
                elif [[ -z "$OUTPUT_FILE" ]]; then
                    OUTPUT_FILE="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Eingabedatei prüfen
    if [[ -z "$input_file" ]]; then
        echo -e "${RED}Fehler: Keine Eingabedatei angegeben!${NC}"
        show_help
    fi
    
    if [[ ! -f "$input_file" ]]; then
        echo -e "${RED}Fehler: Datei '$input_file' nicht gefunden!${NC}"
        exit 1
    fi
    
    # Ausgabedatei setzen
    if [[ -z "$OUTPUT_FILE" ]]; then
        OUTPUT_FILE="${input_file%.*}_compressed.pdf"
    fi
    
    # Ghostscript prüfen
    check_ghostscript
    
    # Originalgröße ermitteln
    original_size=$(stat -f%z "$input_file" 2>/dev/null || stat -c%s "$input_file" 2>/dev/null)
    echo -e "Originalgröße: ${GREEN}$(format_size $original_size)${NC}"
    
    # Wenn maximale Größe angegeben, verschiedene Qualitätsstufen probieren
    if [[ -n "$MAX_SIZE" ]]; then
        max_bytes=$(size_to_bytes "$MAX_SIZE")
        echo -e "Zielgröße: ${YELLOW}≤ $MAX_SIZE${NC}"
        
        # Qualitätsstufen in absteigender Reihenfolge
        qualities=("prepress" "printer" "ebook" "screen" "custom:100" "custom:72" "custom:50")
        temp_file="/tmp/pdf_compress_temp_$$.pdf"
        best_file=""
        best_quality=""
        
        for q in "${qualities[@]}"; do
            compress_pdf "$input_file" "$temp_file" "$q"
            
            if [[ -f "$temp_file" ]]; then
                size=$(stat -f%z "$temp_file" 2>/dev/null || stat -c%s "$temp_file" 2>/dev/null)
                
                if [[ $size -le $max_bytes ]]; then
                    cp "$temp_file" "$OUTPUT_FILE"
                    best_quality=$q
                    echo -e "${GREEN}✓ Erfolgreich mit $q Qualität${NC}"
                    break
                else
                    echo -e "${YELLOW}✗ $q: $(format_size $size) (zu groß)${NC}"
                fi
            fi
        done
        
        rm -f "$temp_file"
        
        if [[ -z "$best_quality" ]]; then
            echo -e "${RED}Warnung: Konnte Zielgröße nicht erreichen!${NC}"
            echo -e "${YELLOW}Verwende niedrigste Qualität (custom:50)...${NC}"
            compress_pdf "$input_file" "$OUTPUT_FILE" "custom:50"
        fi
    else
        # Normale Komprimierung mit angegebener Qualität
        compress_pdf "$input_file" "$OUTPUT_FILE" "$QUALITY"
    fi
    
    # Ergebnis prüfen
    if [[ ! -f "$OUTPUT_FILE" ]]; then
        echo -e "${RED}Fehler: Komprimierung fehlgeschlagen!${NC}"
        exit 1
    fi
    
    # Neue Größe und Einsparung berechnen
    new_size=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE" 2>/dev/null)
    savings=$((original_size - new_size))
    percentage=$((savings * 100 / original_size))
    
    echo -e "\n${GREEN}✓ Komprimierung erfolgreich!${NC}"
    echo -e "Neue Größe: ${GREEN}$(format_size $new_size)${NC}"
    echo -e "Eingespart: ${GREEN}$(format_size $savings) ($percentage%)${NC}"
    echo -e "Ausgabe: ${GREEN}$OUTPUT_FILE${NC}"
}

# Skript ausführen
main "$@"
