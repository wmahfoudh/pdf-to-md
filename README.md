# PDF to Markdown Batch Processor

This script automates the pipeline of converting PDF documents and images into clean Markdown text **fully offline**. It is designed specifically for data preparation workflows where the end goal is feeding high-quality text into Large Language Models (LLMs) or indexing systems (RAG).

It handles the entire extraction process: correcting image defects, performing OCR (Optical Character Recognition) using Tesseract, and converting the layout into structured Markdown. It includes specific robust handling for corrupt text layers and digital signatures that often break standard extractors.

## Features

*   **Batch Processing:** Run without arguments to process every PDF and image in the current directory.
*   **Intelligent OCR:** Uses `ocrmypdf` to add text layers to scanned documents.
*   **Image Support:** Automatically converts JPG, PNG, and TIFF files to PDF, fixing common issues like missing DPI metadata or alpha channels (transparency) using ImageMagick.
*   **Multi-Language Support:** Easy syntax to specify multiple languages for OCR (e.g., English + Simplified Chinese).
*   **"Nuclear" Force Mode:** A specific flag (`-f`) to handle files with corrupt text encoding (CID errors) or digital signatures by rasterizing the document before processing.

## Prerequisites

The script requires a shell and several underlying tools to function: `ocrmypdf`, `tesseract`, `imagemagick`, and `markitdown`.

### Arch Linux
Since `markitdown` is available in the AUR, this is the most straightforward installation.

```bash
# Install system tools
yay -S ocrmypdf tesseract tesseract-data-eng imagemagick

# Install MarkItDown (AUR)
yay -S python-markitdown

# Optional: Install additional language packs as needed
yay -S tesseract-data-chi_sim tesseract-data-fra tesseract-data-spa
```

### Ubuntu / Debian
On Debian-based systems, you will install the system tools via `apt` and MarkItDown via `pip`.

```bash
# Install system tools
sudo apt update
sudo apt install ocrmypdf tesseract-ocr imagemagick

# Install language packs (example: Chinese Simplified)
sudo apt install tesseract-ocr-chi-sim

# Install MarkItDown
# Note: It is recommended to use a virtual environment or pipx
pip install markitdown
```

### Fedora
```bash
# Install system tools
sudo dnf install ocrmypdf tesseract tesseract-langpack-chi_sim ImageMagick

# Install MarkItDown
pip install markitdown
```

## Installation

1.  Download the script `pdf-to-md.sh`.
2.  Make it executable:
    ```bash
    chmod +x pdf-to-md.sh
    ```
3.  Move it to a directory in your system PATH (e.g., `~/.local/bin`):
    ```bash
    mv pdf-to-md.sh ~/.local/bin/pdf-to-md
    ```

## Usage

### Basic Usage
Process a single file using the default language (English). This will output the result in a `md/` folder created in your current directory.

```bash
pdf-to-md input.pdf
```

### Batch Processing
Run the script without any filename argument to process **all** supported files (PDF, JPG, PNG, TIFF) in the current directory.

```bash
pdf-to-md
```

### Specifying Languages
You can specify one or more languages using Tesseract language codes. This is essential for non-English documents to ensure accurate character recognition.

```bash
# For a document containing both Simplified Chinese and English
pdf-to-md -l chi_sim+eng contract.pdf

# For Indonesian and English
pdf-to-md -l ind+eng agreement.pdf
```

To see a list of installed languages on your system:
```bash
pdf-to-md --list-langs
```

### Force Mode ("Nuclear Option")
Some PDFs, particularly contracts or digitally signed documents, may contain a corrupt text layer. If you extract text from these files, you might see garbage output like `(cid:52)(cid:80)`.

Use the `-f` (or `--force`) flag to fix this. This forces the script to rasterize the PDF (convert it to a flat image) before running OCR, effectively ignoring the corrupt internal text data.

```bash
pdf-to-md -f -l eng corrupt_file.pdf
```

## Output Structure

The script keeps your working directory clean by organizing outputs into subfolders:

*   **`./ocr/`**: Contains the intermediate OCR-processed PDFs.
*   **`./md/`**: Contains the final Markdown text files ready for LLM processing.

## License

[MIT License](LICENSE)
