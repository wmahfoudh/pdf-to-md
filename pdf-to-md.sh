#!/bin/zsh

# ==============================================================================
# Script Name: pdf-to-md.sh
# Description: Automates OCR and Markdown extraction.
#              Updates:
#              - Auto-flattens images (removes alpha channel) using ImageMagick.
#              - Auto-sets DPI to 300 for images.
#              - Forces processing of digital signatures.
#              - Added -f / --force flag: "Nuclear Mode" to rasterize corrupt
#                PDFs (fixes CID/garbage text errors) before OCR.
# Dependencies: ocrmypdf, markitdown, tesseract, imagemagick
# Examples of Usage:
#   pdf-to-md.sh -l chi_sim+eng input.pdf
#   pdf-to-md.sh -f -l ind+eng corrupt_contract.pdf
#   pdf-to-md.sh --list-langs
#   pdf-to-md.sh -l eng
# ==============================================================================

# --- Configuration ---
DEFAULT_LANG="eng"
OCR_DIR="ocr"
MD_DIR="md"

# --- Colors for Output ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Helper Functions ---

show_help() {
    echo "Usage: pdf-to-md.sh [OPTIONS] [FILENAME]"
    echo ""
    echo "Options:"
    echo "  -l, --lang <LANG>     Set OCR language (default: eng)."
    echo "                        Example: -l chi_sim+eng"
    echo "  -f, --force           Nuclear Mode. Completely converts PDF to images"
    echo "                        before OCR. Fixes garbage text / (cid:52) errors."
    echo "  --list-langs          Show available languages."
    echo ""
    echo "Filename:"
    echo "  PDF or image file to process."
    echo "  If no file name is given, all files in the current folder are processed."
    echo ""
}

list_languages() {
    echo "${BLUE}Available Tesseract Languages:${NC}"
    if command -v tesseract &> /dev/null; then
        tesseract --list-langs
    else
        echo "${RED}Error: tesseract is not installed.${NC}"
    fi
}

process_file() {
    local input_file="$1"
    local lang="$2"
    local force_mode="$3"

    if [[ ! -f "$input_file" ]]; then
        echo "${RED}Error: File '$input_file' not found.${NC}"
        return
    fi

    local base_name="${input_file:t:r}"
    local extension="${input_file:e:l}" # Get extension in lowercase
    local ocr_output="${OCR_DIR}/${base_name}-ocr.pdf"
    local md_output="${MD_DIR}/${base_name}.md"
    local temp_prep_pdf=""
    local file_to_ocr="$input_file"

    echo "${BLUE}Processing: ${input_file} (Lang: $lang)${NC}"
    if [[ "$force_mode" == "true" ]]; then
        echo "${RED}  [FORCE MODE ACTIVE]${NC}"
    fi

    # --- Step 0: Pre-process (Sanitization) ---
    # We create a temporary flattened PDF if:
    # 1. The input is an IMAGE (to fix Alpha Channel/DPI errors).
    # 2. The input is a PDF AND Force Mode is ON (to fix CID/Corrupt Text).

    local needs_flattening="false"

    if [[ "$extension" =~ ^(jpg|jpeg|png|tif|tiff)$ ]]; then
        needs_flattening="true"
        echo "  [0/2] Flattening image (ImageMagick)..."
    elif [[ "$extension" == "pdf" && "$force_mode" == "true" ]]; then
        needs_flattening="true"
        echo "  [0/2] Rasterizing PDF to clean images (ImageMagick)..."
    fi

    if [[ "$needs_flattening" == "true" ]]; then
        # Check for ImageMagick
        if ! command -v magick &> /dev/null; then
            echo "${RED}Error: 'imagemagick' is required. Install with: yay -S imagemagick${NC}"
            return
        fi

        temp_prep_pdf="${OCR_DIR}/${base_name}_temp_prep.pdf"

        # Convert Input -> PDF (300 DPI, White Background, No Alpha)
        # This works for both Images and PDFs.
        if magick "$input_file" -density 300 -background white -alpha remove -alpha off "$temp_prep_pdf"; then
            # Update variable to point to the temp PDF instead of original
            file_to_ocr="$temp_prep_pdf"
        else
            echo "${RED}  [FAILED] Pre-processing failed.${NC}"
            return
        fi
    fi

    # --- Step 1: OCR (ocrmypdf) ---
    echo "  [1/2] OCR to PDF..."

    # If we are in force mode (or processed an image), 'file_to_ocr' is now a
    # fresh image-only PDF, so we can run standard OCR on it.

    if ocrmypdf -l "$lang" --deskew --skip-text --invalidate-digital-signatures "$file_to_ocr" "$ocr_output" 2>/dev/null; then
        : # Success
    else
        echo "        (Retrying with force-ocr...)"
        # Fallback
        if ! ocrmypdf -l "$lang" --force-ocr --invalidate-digital-signatures "$file_to_ocr" "$ocr_output" 2>/dev/null; then
            echo "${RED}  [FAILED] OCR step failed for $input_file${NC}"
            [[ -n "$temp_prep_pdf" && -f "$temp_prep_pdf" ]] && rm "$temp_prep_pdf"
            return
        fi
    fi

    # Cleanup temp file
    [[ -n "$temp_prep_pdf" && -f "$temp_prep_pdf" ]] && rm "$temp_prep_pdf"

    # --- Step 2: MarkItDown ---
    echo "  [2/2] Converting to Markdown..."
    if markitdown "$ocr_output" > "$md_output"; then
        echo "${GREEN}  [DONE] Saved to $md_output${NC}"
    else
        echo "${RED}  [FAILED] MarkItDown failed for $ocr_output${NC}"
    fi
}

# --- Argument Parsing ---

TARGET_FILE=""
CHOSEN_LANG="$DEFAULT_LANG"
FORCE_MODE="false"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) show_help; exit 0 ;;
        --list-langs) list_languages; exit 0 ;;
        -f|--force) FORCE_MODE="true"; shift ;;
        -l|--lang)
            if [[ -n "$2" && "$2" != -* ]]; then
                CHOSEN_LANG="$2"; shift 2
            else
                echo "${RED}Error: --lang requires an argument.${NC}"; exit 1
            fi ;;
        *) TARGET_FILE="$1"; shift ;;
    esac
done

# --- Main Execution ---

mkdir -p "$OCR_DIR"
mkdir -p "$MD_DIR"

if [[ -n "$TARGET_FILE" ]]; then
    process_file "$TARGET_FILE" "$CHOSEN_LANG" "$FORCE_MODE"
else
    setopt nullglob
    files=( *.{pdf,PDF,jpg,JPG,jpeg,JPEG,png,PNG,tif,TIF,tiff,TIFF} )

    if [[ ${#files[@]} -eq 0 ]]; then
        echo "${RED}No PDF or Image files found in this directory.${NC}"
        exit 0
    fi

    echo "Found ${#files[@]} files. Starting batch process..."
    for f in $files; do
        process_file "$f" "$CHOSEN_LANG" "$FORCE_MODE"
    done
fi
