#!/bin/zsh

# ==============================================================================
# Script Name: one-pdf-to-md
# Description: Pipe-ready "Nuclear Mode" converter.
#              - Output: Prints Markdown to STDOUT.
#              - Logs: Prints messages to STDERR (only if -v).
# Usage: 
#   one-pdf-to-md file.pdf > output.md
#   one-pdf-to-md file.pdf | grep "Total"
# ==============================================================================

# --- Defaults ---
LANG="eng"
DPI="600"
INPUT_FILE=""
VERBOSE="false"

# --- Helper Functions ---

show_help() {
    # Help goes to stderr so it doesn't break pipes if accidentally triggered
    cat >&2 <<EOF
Usage: one-pdf-to-md <filename> [OPTIONS]

Description:
  Converts PDF/Image to Markdown (Nuclear Mode) and prints to STDOUT.

Options:
  <filename>        Input file.
  -v, --verbose     Show logs (printed to STDERR).
  -l, --lang <CODE> OCR language (default: 'eng').
  --dpi <NUMBER>    Rasterization DPI (default: 600).
  -h, --help        Show this help.

Examples:
  one-pdf-to-md doc.pdf > doc.md
  one-pdf-to-md scan.jpg | grep "Invoice Date"
EOF
}

log() {
    [[ "$VERBOSE" == "true" ]] && echo "\033[0;34m[INFO] $1\033[0m" >&2
}

error() {
    # Errors always go to stderr
    echo "\033[0;31m[ERROR] $1\033[0m" >&2
}

run_cmd() {
    if [[ "$VERBOSE" == "true" ]]; then
        # CRITICAL: Progress messages must go to >&2 (stderr)
        echo "       > Executing: $*" >&2
        "$@"
    else
        "$@" > /dev/null 2>&1
    fi
}

# --- Argument Parsing ---

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

if [[ -z "$INPUT_FILE" || ! -f "$INPUT_FILE" ]]; then
    error "Input file '$INPUT_FILE' not found."
    exit 1
fi

# Create secure temporary files
TEMP_RASTER=$(mktemp)
TEMP_OCR=$(mktemp)
# Append extensions for tools that rely on them
mv "$TEMP_RASTER" "${TEMP_RASTER}.pdf"
mv "$TEMP_OCR" "${TEMP_OCR}.pdf"
TEMP_RASTER="${TEMP_RASTER}.pdf"
TEMP_OCR="${TEMP_OCR}.pdf"

# Cleanup trap
trap 'rm -f "$TEMP_RASTER" "$TEMP_OCR"' EXIT

# --- Execution ---

log "Processing: $INPUT_FILE (DPI=$DPI, Lang=$LANG)"

# 1. Rasterize
log "Step 1/3: Rasterizing..."
run_cmd magick -density "$DPI" "$INPUT_FILE" -background white -alpha remove -alpha off "$TEMP_RASTER"
if [[ $? -ne 0 ]]; then error "Rasterization failed."; exit 1; fi

# 2. OCR
log "Step 2/3: Force OCR..."
run_cmd ocrmypdf -l "$LANG" --force-ocr --invalidate-digital-signatures "$TEMP_RASTER" "$TEMP_OCR"
if [[ $? -ne 0 ]]; then error "OCR failed."; exit 1; fi

# 3. MarkItDown (Output to STDOUT)
log "Step 3/3: Streaming Markdown..."

# We do NOT use run_cmd here because we want the output!
# However, we still want to hide markitdown's stderr (logs) unless verbose.

if [[ "$VERBOSE" == "true" ]]; then
    # In verbose, allow stderr to show up on screen (stderr), payload to stdout
    markitdown "$TEMP_OCR"
else
    # In silent, hide stderr, payload to stdout
    markitdown "$TEMP_OCR" 2> /dev/null
fi

if [[ $? -ne 0 ]]; then
    error "MarkItDown failed."
    exit 1
fi
