# auge

[![Version 0.0.6](https://img.shields.io/badge/version-0.0.6-blue)](https://github.com/Arthur-Ficial/auge)
[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 10.15+](https://img.shields.io/badge/macOS-10.15%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![100% On-Device](https://img.shields.io/badge/privacy-100%25%20on--device-green)](https://developer.apple.com/documentation/vision)

Apple's **on-device Vision framework** from the command line — OCR, image classification, barcode detection, and face detection.

No API keys. No cloud. No network. The Vision framework is already on your Mac — auge lets you use it from the terminal.

## What is this

Every Mac ships with Apple's [Vision framework](https://developer.apple.com/documentation/vision) — a powerful on-device computer vision engine for text recognition, image classification, barcode scanning, and face detection. But it's only accessible through Swift/ObjC code. **auge wraps it** in a UNIX CLI — so you can use it from the terminal, shell scripts, and pipelines.

- **OCR** — extract text from screenshots, scans, PDFs
- **Classification** — identify what's in an image (1000+ categories)
- **Barcodes** — scan QR codes, EAN, Code128, and more
- **Face detection** — count faces and get bounding boxes
- **Pipe-friendly** — works with `jq`, `xargs`, `apfel`, and shell scripts
- **Zero cost** — no API keys, no cloud, no subscriptions, no dependencies

## Requirements & Install

- macOS 10.15+ (classification requires macOS 12+)
- Building from source requires Command Line Tools with Swift 6.3. No Xcode required.

**Homebrew** (recommended):

```bash
brew tap Arthur-Ficial/tap
brew install Arthur-Ficial/tap/auge
```

**Build from source:**

```bash
git clone https://github.com/Arthur-Ficial/auge.git
cd auge
make install
```

## Quick Start

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
```

### JSON output

```bash
auge --ocr screenshot.png -o json | jq .results.lines
auge --classify photo.jpg -o json | jq '.results.classifications[:3]'
auge --faces group.jpg -o json | jq .results.count
```

```json
{
  "file" : "screenshot.png",
  "metadata" : {
    "on_device" : true,
    "version" : "0.0.5"
  },
  "mode" : "ocr",
  "results" : {
    "lines" : ["Hello", "World"],
    "text" : "Hello\nWorld"
  }
}
```

### Piping

```bash
# OCR a screenshot, summarize with apfel
auge --ocr screenshot.png | apfel "summarize this"

# OCR all PNGs in a directory
ls *.png | auge --ocr

# Pipe file paths via stdin
find . -name "*.jpg" | auge --classify --top 3

# Chain with jq for structured extraction
auge --ocr receipt.png -o json | jq -r .results.text
```

## Demos

See [`demo/`](./demo/) for real-world shell scripts powered by auge.

**[screenshot](./demo/screenshot)** — capture screen and extract text instantly:

```bash
demo/screenshot                    # full screen OCR
demo/screenshot -r                 # drag to select a region
demo/screenshot -c                 # copy text to clipboard
demo/screenshot | grep "error"     # find errors on screen
```

**[clipboard-ocr](./demo/clipboard-ocr)** — OCR an image from the clipboard:

```bash
# Press Cmd+Ctrl+Shift+4 to screenshot a region to clipboard, then:
demo/clipboard-ocr                 # print extracted text
demo/clipboard-ocr -c              # replace clipboard image with text
demo/clipboard-ocr | apfel "summarize this"
```

**[describe](./demo/describe)** — describe an image in natural language (auge + apfel):

```bash
demo/describe photo.jpg            # "A cat sleeping on a blue couch..."
demo/describe screenshot.png -c    # describe and copy
```

**[translate](./demo/translate)** — OCR text from image and translate (auge + apfel):

```bash
demo/translate menu.jpg            # translate to English
demo/translate -l German sign.png  # translate to German
demo/translate -l Japanese doc.pdf
```

**[receipt](./demo/receipt)** — extract structured data from receipt photos (auge + apfel):

```bash
demo/receipt grocery.jpg           # vendor, date, total, items
demo/receipt -j scan.png | jq .total
```

**[explain-image](./demo/explain-image)** — full image analysis (auge + apfel):

```bash
demo/explain-image screenshot.png  # classify + OCR + faces + barcodes → explanation
demo/explain-image error.png -c    # explain an error dialog
```

Also in `demo/`:
- **[qr](./demo/qr)** — read QR codes and barcodes, optionally open URLs
- **[sort-images](./demo/sort-images)** — classify all images in a directory, group by category
- **[diff-text](./demo/diff-text)** — OCR two images and diff the extracted text
- **[faces](./demo/faces)** — count faces across photos with per-file summary
- **[monitor](./demo/monitor)** — watch mode: periodic screen OCR, alert on text changes or pattern match

## CLI Reference

```
auge --ocr <image>              Extract text from image (OCR)
auge --classify <image>         Classify image content
auge --barcode <image>          Detect barcodes and QR codes
auge --faces <image>            Detect faces
auge --release                  Show detailed release and build info
```

### Options

| Flag | Description |
|------|-------------|
| `-o, --output <fmt>` | Output format: `plain` or `json` |
| `-q, --quiet` | Suppress non-essential output |
| `--no-color` | Disable ANSI colors |
| `--top <n>` | Max classification results (default: 10) |
| `--min-confidence <n>` | Min confidence threshold 0-1 (default: 0.01) |
| `-v, --version` | Print version |
| `--release` | Show detailed version, build, and capability info |
| `-h, --help` | Show help |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success (also: no text/results found — not an error) |
| 1 | Runtime error (bad file, invalid image, analysis failure) |
| 2 | Usage error (bad flags, missing arguments) |
| 5 | Vision framework unavailable |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `NO_COLOR` | Disable colors ([no-color.org](https://no-color.org)) |

## Vision Capabilities

| Mode | Framework Request | macOS | Output |
|------|-------------------|-------|--------|
| `--ocr` | `VNRecognizeTextRequest` | 10.15+ | Text lines |
| `--classify` | `VNClassifyImageRequest` | 12+ | Labels with confidence |
| `--barcode` | `VNDetectBarcodesRequest` | 10.13+ | Payload + symbology |
| `--faces` | `VNDetectFaceRectanglesRequest` | 10.13+ | Count + bounding boxes |

### Supported Image Formats

PNG, JPEG, TIFF, BMP, GIF, HEIC, PDF

## Architecture

```
CLI (--ocr/--classify/--barcode/--faces)
  │
  ├─→ ImageSource.validatePath()     — file validation (AugeCore)
  ├─→ Analyzer.recognizeText()       — VNRecognizeTextRequest
  ├─→ Analyzer.classifyImage()       — VNClassifyImageRequest
  ├─→ Analyzer.detectBarcodes()      — VNDetectBarcodesRequest
  └─→ Analyzer.detectFaces()         — VNDetectFaceRectanglesRequest
       │
       └─→ Vision framework (100% on-device, zero network)
```

Built with Swift 6.3 strict concurrency. Single `Package.swift`, three targets:
- `AugeCore` — pure logic library (no Vision dependency, unit-testable)
- `auge` — executable (CLI + Vision framework)
- `auge-tests` — 115 unit tests, pure Swift runner (no XCTest)

**No Xcode required.** Builds and tests with Command Line Tools only.

## Build & Test

```bash
# Build + install (auto-bumps patch version each time)
make install                    # build release + install to /usr/local/bin
make build                      # build release only (no install)

# Version management (zero manual editing)
make version                    # print current version
make release-minor              # bump minor: 0.0.x -> 0.1.0
make release-major              # bump major: 0.x.y -> 1.0.0

# Debug build (no version bump)
swift build                     # quick debug build

# Tests
swift run auge-tests            # 115 pure Swift unit tests (no XCTest needed)
bash Tests/integration/run.sh   # 17 integration tests (end-to-end CLI)
```

Every `make build`/`make install` automatically:
- Bumps the patch version (`.version` file is the single source of truth)
- Updates the README version badge
- Generates build metadata (commit, date, Swift version) viewable via `auge --release`

### Test Coverage

| Suite | Tests | Covers |
|-------|-------|--------|
| AugeErrorTests | 10 | Error classification, CLI labels, exit codes, messages |
| AugeErrorDeepTests | 18 | Every keyword variant, case insensitivity, passthrough, cross-type |
| ImageSourceTests | 16 | Extension validation, path validation |
| ImageSourceDeepTests | 11 | Unicode paths, URL correctness, error propagation, exhaustive formats |
| ResultFormatterTests | 15 | OCR, classification, barcode, face formatting + JSON encoding |
| ResultFormatterDeepTests | 23 | Exact formats, boundary values, round-trip JSON, key names, unicode |
| CLIParsingTests | 22 | Edge cases, dotfiles, special chars, stress tests |
| Integration | 17 | CLI basics, exit codes, OCR, classify, faces, barcodes, piping, quiet |
| **Total** | **132** | |

## Part of the apfel ecosystem

| Tool | What | Apple Framework | Repo |
|------|------|-----------------|------|
| [apfel](https://github.com/Arthur-Ficial/apfel) | LLM (text generation) | FoundationModels | [Arthur-Ficial/apfel](https://github.com/Arthur-Ficial/apfel) |
| [ohr](https://github.com/Arthur-Ficial/ohr) | Speech-to-text | SpeechAnalyzer | [Arthur-Ficial/ohr](https://github.com/Arthur-Ficial/ohr) |
| [kern](https://github.com/Arthur-Ficial/kern) | Text embeddings | NLContextualEmbedding | [Arthur-Ficial/kern](https://github.com/Arthur-Ficial/kern) |
| **auge** | Vision / OCR | Vision | [Arthur-Ficial/auge](https://github.com/Arthur-Ficial/auge) |

Meta-repo: [apfel-ecosystem](https://github.com/Arthur-Ficial/apfel-ecosystem)

## License

[MIT](LICENSE)
