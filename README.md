# auge

![Version 0.0.3](https://img.shields.io/badge/version-0.0.3-blue)
![macOS 10.15+](https://img.shields.io/badge/macOS-10.15+-lightgrey)
![Swift 6.3](https://img.shields.io/badge/Swift-6.3-orange)
![100% on-device](https://img.shields.io/badge/privacy-100%25%20on--device-green)

Apple Vision from the command line. OCR, image classification, barcode detection, and face detection — 100% on-device, zero dependencies.

Part of the [apfel ecosystem](https://github.com/Arthur-Ficial/apfel-ecosystem).

## Install

### Homebrew

```bash
brew install Arthur-Ficial/tap/auge
```

### From source

```bash
git clone git@github.com:Arthur-Ficial/auge.git
cd auge
make install
```

Requires macOS 10.15+ and Swift 6.3 (Command Line Tools).

## Usage

```bash
# OCR — extract text from images
auge --ocr screenshot.png
auge --ocr scan.pdf
auge --ocr image1.png image2.png

# Classification — what's in this image?
auge --classify photo.jpg
auge --classify photo.jpg --top 5

# Barcodes — scan QR codes and barcodes
auge --barcode product.jpg

# Face detection — count and locate faces
auge --faces group.jpg

# JSON output for machine consumption
auge --ocr screenshot.png -o json | jq .results.lines

# Pipe-friendly
auge --ocr screenshot.png | apfel "summarize this"
ls *.png | auge --ocr

# Quiet mode (suppress non-essential output)
auge --ocr screenshot.png -q
```

## Options

```
-o, --output <format>     Output format: plain, json [default: plain]
-q, --quiet               Suppress non-essential output
    --no-color            Disable colored output
    --top <n>             Max classification results [default: 10]
    --min-confidence <n>  Min confidence threshold 0-1 [default: 0.01]
-h, --help                Show this help
-v, --version             Print version
    --release             Show detailed release and build info
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success (also: no text/results found — not an error) |
| 1 | Runtime error (bad file, invalid image, analysis failure) |
| 2 | Usage error (bad flags, missing arguments) |
| 5 | Vision framework unavailable |

## JSON Output

```bash
auge --ocr screenshot.png -o json
```

```json
{
  "file": "screenshot.png",
  "metadata": {
    "on_device": true,
    "version": "0.1.0"
  },
  "mode": "ocr",
  "results": {
    "lines": ["Hello", "World"],
    "text": "Hello\nWorld"
  }
}
```

## Environment

| Variable | Description |
|----------|-------------|
| `NO_COLOR` | Disable colored output ([no-color.org](https://no-color.org)) |

## Vision Capabilities

| Mode | Framework Request | macOS Requirement |
|------|-------------------|-------------------|
| `--ocr` | `VNRecognizeTextRequest` | macOS 10.15+ |
| `--classify` | `VNClassifyImageRequest` | macOS 12+ |
| `--barcode` | `VNDetectBarcodesRequest` | macOS 10.13+ |
| `--faces` | `VNDetectFaceRectanglesRequest` | macOS 10.13+ |

## Supported Image Formats

PNG, JPEG, TIFF, BMP, GIF, HEIC, PDF

## Part of the apfel ecosystem

| Tool | What | Apple Framework |
|------|------|-----------------|
| [apfel](https://github.com/Arthur-Ficial/apfel) | LLM (text generation) | FoundationModels |
| [ohr](https://github.com/Arthur-Ficial/ohr) | Speech-to-text | SpeechAnalyzer |
| [kern](https://github.com/Arthur-Ficial/kern) | Text embeddings | NLContextualEmbedding |
| **auge** | Vision / OCR | Vision |

## License

MIT
