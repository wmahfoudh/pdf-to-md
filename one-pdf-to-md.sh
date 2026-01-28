#!/bin/zsh

# ==============================================================================
# Script Name: one-pdf-to-md
# Description: Single-file "Nuclear Mode" converter.
#              Default: Silent processing.
#              Verbose: Prints details via -v.
# ==============================================================================

# --- Defaults ---
LANG="eng"
DPI="600"
INPUT_FILE=""
VERBOSE="false"

# --- Helper Functions ---

show_help() {
    echo "Usage: one-pdf-to-md <filename> [OPTIONS]"
    echo ""
    echo "Description:"
    echo "  Converts a PDF or Image to Markdown using 'Nuclear Mode'"
    echo "  (Rasterize @ 600dpi -> Force OCR -> Markdown)."
    echo ""
    echo "Options:"
    echo "  <filename>        Input file (PDF, JPG, PNG, etc)."
    echo "  -v, --verbose     Enable output (shows progress and errors)."
    echo "  -l, --lang <CODE> OCR language (default: 'eng')."
    echo "  --dpi <NUMBER>    Rasterization DPI (default: 600)."
    echo "  -h, --help        Show this help message."
    echo ""
    echo "Examples:"
    echo "  one-pdf-to-md doc.pdf"
    echo "  one-pdf-to-md scan.jpg -l fra -v"
}

log() {
    [[ "$VERBOSE" == "true" ]] && echo "\033[0;34m[INFO] $1\033[0m" >&2
}

error() {
    [[ "$VERBOSE" == "true" ]] && echo "\033[0;31m[ERROR] $1\033[0m" >&2
}

run_cmd() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "       > Executing: $@"
        "$@"
    else
        "$@" > /dev/null 2>&1
    fi
}

# --- Argument Parsing ---

# If no arguments provided at all, show help and exit
if [[ $# -eq 0 ]]; then
    show_help
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        -l|--lang)
            LANG="$2"
            shift 2
            ;;
        --dpi)
            DPI="$2"
            shift 2
            ;;
        *)
            if [[ -z "$INPUT_FILE" ]]; then
                INPUT_FILE="$1"
            fi
            shift
            ;;
    esac
done

# --- Validation ---

if [[ -z "$INPUT_FILE" ]]; then
    echo "Error: No input file specified."
    show_help
    exit 1
fi

if [[ ! -f "$INPUT_FILE" ]]; then
    # If verbose is off, we still print this specific error because it's a usage error
    # but we keep it simple.
    echo "Error: File '$INPUT_FILE' not found." >&2
    exit 1
fi

# Define Output and Temp Files
BASENAME="${INPUT_FILE:t:r}"
OUTPUT_MD="${BASENAME}.md"

# Create secure temporary files
TEMP_RASTER=$(mktemp)
TEMP_OCR=$(mktemp)
mv "$TEMP_RASTER" "${TEMP_RASTER}.pdf"
mv "$TEMP_OCR" "${TEMP_OCR}.pdf"
TEMP_RASTER="${TEMP_RASTER}.pdf"
TEMP_OCR="${TEMP_OCR}.pdf"

# Cleanup trap
trap 'rm -f "$TEMP_RASTER" "$TEMP_OCR"' EXIT

# --- Execution ---

log "Starting Nuclear Mode on: $INPUT_FILE"
log "Settings: DPI=$DPI, Lang=$LANG"

# 1. Rasterize
log "Step 1/3: Flattening/Rasterizing (ImageMagick)..."
run_cmd magick -density "$DPI" "$INPUT_FILE" -background white -alpha remove -alpha off "$TEMP_RASTER"
if [[ $? -ne 0 ]]; then 
    error "Rasterization failed."
    exit 1
fi

# 2. OCR
log "Step 2/3: Force OCR (ocrmypdf)..."
run_cmd ocrmypdf -l "$LANG" --force-ocr --invalidate-digital-signatures "$TEMP_RASTER" "$TEMP_OCR"
if [[ $? -ne 0 ]]; then 
    error "OCR failed."
    exit 1
fi

# 3. MarkItDown
log "Step 3/3: Converting to Markdown..."
if [[ "$VERBOSE" == "true" ]]; then
    echo "       > Executing: markitdown $TEMP_OCR > $OUTPUT_MD"
    markitdown "$TEMP_OCR" > "$OUTPUT_MD"
else
    markitdown "$TEMP_OCR" > "$OUTPUT_MD" 2> /dev/null
fi

if [[ $? -eq 0 ]]; then
    log "Success! Output saved to: $OUTPUT_MD"
    exit 0
else
    error "MarkItDown failed."
    rm -f "$OUTPUT_MD"
    exit 1
fi
