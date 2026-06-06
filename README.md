# auge

[![Version 1.8.0](https://img.shields.io/badge/version-1.8.0-blue)](https://github.com/Arthur-Ficial/auge)
[![Swift 6.3+](https://img.shields.io/badge/Swift-6.3%2B-F05138?logo=swift&logoColor=white)](https://swift.org)
[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/macos/)
[![No Xcode Required](https://img.shields.io/badge/Xcode-not%20required-orange)](https://developer.apple.com/xcode/resources/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![100% On-Device](https://img.shields.io/badge/privacy-100%25%20on--device-green)](https://developer.apple.com/documentation/vision)

Apple's **on-device Vision framework** from the command line — OCR, classification, detection, structured document analysis, and local agent/MCP integrations.

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

- macOS 26+
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
    "schema" : "2",
    "version" : "1.8.0"
  },
  "mode" : "ocr",
  "results" : {
    "lines" : ["Hello", "World"],
    "text" : "Hello\nWorld"
  }
}
```

> JSON keys are uniformly `snake_case` (schema `2`). Compound keys are snaked too —
> e.g. `feature_print`, `line_details`, `angle_radians`, `persons_mask`.

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

## Agent Integrations

auge now ships with two agent-facing surfaces:

- **[`skills/auge/SKILL.md`](./skills/auge/SKILL.md)** — task-oriented guidance for agents deciding when and how to use auge.
- **`auge-mcp`** — a **local stdio MCP server** that exposes auge capabilities as tools.

This does **not** add a network server mode. `auge-mcp` is a subprocess adapter over stdio only, so auge remains fully local and on-device.

### MCP quick start

```bash
swift build
.build/debug/auge-mcp
```

Typical MCP client configuration:

```json
{
  "command": "/absolute/path/to/auge/.build/debug/auge-mcp",
  "args": []
}
```

Available MCP tools currently expose a subset of CLI modes:

- `auge_ocr`
- `auge_classify`
- `auge_barcode`
- `auge_faces`
- `auge_face_landmarks`
- `auge_face_quality`
- `auge_humans`
- `auge_text_rectangles`
- `auge_rectangles`
- `auge_horizon`
- `auge_animals`
- `auge_animal_pose`
- `auge_body_pose`
- `auge_hand_pose`
- `auge_saliency_attention`
- `auge_saliency_objectness`
- `auge_contours`
- `auge_feature_print`
- `auge_compare`
- `auge_aesthetics`
- `auge_smudge`
- `auge_document`
- `auge_all`
- `auge_release`

## CLI Reference

```
auge --all <image>                 Run every analysis on the image
auge --ocr <image>                 Extract text from image (OCR)
auge --classify <image>            Classify image content
auge --barcode <image>             Detect barcodes and QR codes
auge --faces <image>               Detect faces (bounding boxes)
auge --face-landmarks <image>      Detect 76-point face landmarks + roll/yaw/pitch
auge --face-quality <image>        Per-face capture quality score
auge --humans <image>              Detect humans (bounding boxes)
auge --text-rectangles <image>     Detect text regions (no recognition)
auge --rectangles <image>          Detect quadrilaterals (paper, screens, signs)
auge --horizon <image>             Detect horizon angle
auge --animals <image>             Detect cats and dogs
auge --animal-pose <image>         Detect animal body pose joints
auge --body-pose <image>           Detect human body pose joints
auge --hand-pose <image>           Detect hand pose keypoints
auge --saliency-attention <image>  Salient regions (attention-based, boxes only)
auge --saliency-objectness <image> Salient regions (object-based, boxes only)
auge --contours <image>            Detect vector contours
auge --feature-print <image>       Image embedding (descriptor vector)
auge --compare <a> <b>             Cosine distance between two images
auge --aesthetics <image>          Score image aesthetics (utility flag included)
auge --smudge <image>              Detect lens smudge confidence
auge --document <image>            Parse structured document (paragraphs, lists, tables)
auge --release                     Show detailed release and build info
```

### Options

| Flag | Description |
|------|-------------|
| `-o, --output <fmt>` | Output format: `plain`, `json`, `md`, or `ndjson` |
| `--plain` / `--json` / `--md` / `--ndjson` | Shorthand for `-o <fmt>` |
| `--compact` | Single-line compact JSON (when output is JSON) |
| `-q, --quiet` | Suppress non-essential output |
| `--no-color` | Disable ANSI colors |
| `--clipboard` | Read image from the macOS clipboard (NSPasteboard) |
| `--dpi <n>` | PDF rasterization DPI 72-600 (default: 200) |
| `--prefer-embedded` | Use PDF text layer when present (default) |
| `--no-prefer-embedded` | Force OCR even on searchable PDFs |
| `--langs <a,b,c>` | BCP-47 OCR language hints (e.g. `en-US,de-DE`) |
| `--enhance` | Upscale tiny images before OCR (helps small text) |
| `--clean` | FoundationModels post-pass: dehyphenate, reflow, fix OCR errors (macOS 26+) |
| `--top <n>` | Max classification results (default: 10) |
| `--min-confidence <n>` | Min confidence threshold 0-1 (default: 0.01) |
| `--upper-body-only` | For `--humans`: detect upper body only |
| `--max-hands <n>` | For `--hand-pose`: max hands (default: 2) |
| `--auto-lang` | OCR: auto-detect language (single pass, ignores `--langs`) |
| `--fast` | OCR: use fast recognition level |
| `--no-correct` | OCR: disable language correction |
| `--with-boxes` | OCR: include per-line bounding boxes + confidence in JSON |
| `--vocab <path>` | OCR: custom words file (one word per line) |
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

> **Note:** auge requires macOS 26+. The "Vision API since" column below shows the historical
> macOS version when each Vision framework API was first introduced, not the auge minimum requirement.

| Mode | Framework Request | Vision API since | Output |
|------|-------------------|------------------|--------|
| `--ocr` | `VNRecognizeTextRequest` | 10.15 | Text lines |
| `--classify` | `VNClassifyImageRequest` | 12 | Labels with confidence |
| `--barcode` | `VNDetectBarcodesRequest` | 10.13 | Payload + symbology |
| `--faces` | `VNDetectFaceRectanglesRequest` | 10.13 | Count + bounding boxes |
| `--face-landmarks` | `VNDetectFaceLandmarksRequest` | 10.13 | 76-point landmarks + roll/yaw/pitch |
| `--face-quality` | `VNDetectFaceCaptureQualityRequest` | 10.13 | Per-face quality scores |
| `--humans` | `VNDetectHumanRectanglesRequest` | 10.15 | Human bounding boxes |
| `--text-rectangles` | `VNDetectTextRectanglesRequest` | 10.13 | Text region boxes |
| `--rectangles` | `VNDetectRectanglesRequest` | 10.13 | Quadrilaterals + confidence |
| `--horizon` | `VNDetectHorizonRequest` | 10.13 | Horizon angle |
| `--animals` | `VNRecognizeAnimalsRequest` | 11 | Cat/dog labels + boxes |
| `--animal-pose` | `VNDetectAnimalBodyPoseRequest` | 14 | Animal pose joints |
| `--body-pose` | `VNDetectHumanBodyPoseRequest` | 14 | Human pose joints |
| `--hand-pose` | `VNDetectHumanHandPoseRequest` | 14 | Hand pose keypoints |
| `--saliency-attention` | `VNGenerateAttentionBasedSaliencyImageRequest` | 13 | Salient boxes |
| `--saliency-objectness` | `VNGenerateObjectnessBasedSaliencyImageRequest` | 13 | Salient boxes |
| `--contours` | `VNDetectContoursRequest` | 14 | Vector contours |
| `--feature-print` | `VNGenerateImageFeaturePrintRequest` | 13 | Embedding vector |
| `--compare` | Feature-print distance | 13 | Cosine distance |
| `--aesthetics` | `CalculateImageAestheticsScoresRequest` | 15 | Overall score + utility flag |
| `--smudge` | `DetectLensSmudgeRequest` | 26 | Smudge confidence |
| `--document` | `RecognizeDocumentsRequest` | 26 | Paragraphs, lists, tables |
| `--all` | Combined | mixed | One response containing all supported analyses |

### Supported Image Formats

PNG, JPEG, TIFF, BMP, GIF, HEIC, PDF

## Architecture

```
CLI / MCP stdio
  │
  ├─→ AugeCommandLine / AugeMCPServer
  ├─→ shared execution layer
  ├─→ ImageSource.validatePath()     — file validation (AugeCore)
  ├─→ Analyzer.swift                 — classic Vision requests
  ├─→ TahoeAnalyzer.swift            — newer Swift Vision requests
  └─→ Vision framework (100% on-device, zero network)
```

Built with Swift 6.3 strict concurrency. Single `Package.swift`, four targets:
- `AugeCore` — pure logic library (no Vision dependency, unit-testable)
- `AugeApp` — shared app logic (CLI runtime, MCP runtime, Vision integration)
- `auge` — executable CLI entrypoint
- `auge-mcp` — executable local stdio MCP server
- `auge-tests` — pure Swift runner (no XCTest)

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
swift run auge-tests            # pure Swift unit tests (no XCTest needed)
bash Tests/integration/run.sh   # 17 integration tests (end-to-end CLI)
swift run auge-mcp              # start local stdio MCP server
bash Tests/integration/run-mcp.sh .build/debug/auge-mcp   # MCP integration tests
```

Every `make build`/`make install` automatically:
- Bumps the patch version (`.version` file is the single source of truth)
- Updates the README version badge
- Generates build metadata (commit, date, Swift version) viewable via `auge --release`

### Test Coverage

- Pure Swift unit tests cover formatters, parsing helpers, error classification, image validation, PDF detection, capability metadata, and the shared execution/MCP mapping layer.
- Integration tests cover both the CLI and the stdio MCP server.

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
