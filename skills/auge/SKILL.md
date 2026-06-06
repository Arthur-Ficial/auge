# auge agent skills

Use `auge` when the task is **local image/PDF analysis on macOS** and the user wants structured results from Apple's on-device Vision framework.

## When to use auge

Choose auge for:

- OCR from screenshots, scans, photos, or PDFs
- Image classification
- Barcode / QR scanning
- Face, human, text-region, or rectangle detection
- Pose detection (hand, body, animal)
- Saliency, contours, feature prints, or image comparison
- Structured document extraction
- Running **all** Vision analyses on one image

Do **not** use auge for:

- Any cloud vision API
- General web/image search
- Image editing or generation
- A long-running network server

auge is **100% local**. No API keys. No network. No HTTP server mode.

## Preferred surfaces

1. **MCP:** use `auge-mcp` tools when tool calling is available.
2. **CLI:** use `auge` directly when shelling out is simpler or when MCP is not available.

For machine use, prefer:

- MCP `structuredContent`
- CLI `--json` or `--ndjson`

## Core rules

- Empty detections are usually **success**, not failure.
- OCR/barcode/classify may return no result with exit code `0`.
- Use `--quiet` only when you want to suppress notices, not results.
- For PDFs, use `--dpi` and `--prefer-embedded` / `--no-prefer-embedded` intentionally.
- For OCR on tiny text, try `--enhance`.
- For OCR cleanup on macOS 26+, try `--clean`.
- For OCR IDs/codes/plates, prefer `--no-correct`.
- For richer OCR JSON, use `--with-boxes`.

## CLI patterns

```bash
auge --ocr image.png --json
auge --classify photo.jpg --top 5 --json
auge --barcode code.png --json
auge --faces group.jpg --json
auge --face-landmarks portrait.jpg --json
auge --humans scene.jpg --upper-body-only --json
auge --hand-pose hand.jpg --max-hands 2 --json
auge --compare a.jpg b.jpg --json
auge --document scan.png --json
auge --all screenshot.png --json
```

## MCP tool mapping

| CLI flag | MCP tool |
|---|---|
| `--ocr` | `auge_ocr` |
| `--classify` | `auge_classify` |
| `--barcode` | `auge_barcode` |
| `--faces` | `auge_faces` |
| `--face-landmarks` | `auge_face_landmarks` |
| `--face-quality` | `auge_face_quality` |
| `--humans` | `auge_humans` |
| `--text-rectangles` | `auge_text_rectangles` |
| `--rectangles` | `auge_rectangles` |
| `--horizon` | `auge_horizon` |
| `--animals` | `auge_animals` |
| `--animal-pose` | `auge_animal_pose` |
| `--body-pose` | `auge_body_pose` |
| `--hand-pose` | `auge_hand_pose` |
| `--saliency-attention` | `auge_saliency_attention` |
| `--saliency-objectness` | `auge_saliency_objectness` |
| `--contours` | `auge_contours` |
| `--feature-print` | `auge_feature_print` |
| `--compare` | `auge_compare` |
| `--aesthetics` | `auge_aesthetics` |
| `--smudge` | `auge_smudge` |
| `--document` | `auge_document` |
| `--all` | `auge_all` |
| `--release` | `auge_release` |

## MCP argument shape

Most single-image tools accept:

- `path` or `paths`
- `clipboard`
- `output`: `plain`, `json`, `md`, `ndjson`
- `compact`
- `quiet`

Additional mode-specific arguments:

- OCR / all: `dpi`, `preferEmbedded`, `langs`, `enhance`, `clean`
- OCR: `autoLang`, `fast`, `noCorrect`, `withBoxes`, `vocabPath`, `vocabWords`
- classify / all: `top`, `minConfidence`
- humans / all: `upperBodyOnly`
- hand-pose / all: `maxHands`
- compare: `pathA`, `pathB`

## Output expectations

CLI JSON shape:

```json
{
  "mode": "ocr",
  "file": "image.png",
  "results": { "...": "..." },
  "metadata": {
    "on_device": true,
    "version": "x.y.z",
    "schema": "1"
  }
}
```

MCP tool results return:

- `structuredContent.mode`
- `structuredContent.responses` (same semantic payloads as CLI JSON)
- `structuredContent.notices`
- `structuredContent.errors`
- `structuredContent.rendered`

If you need the most reliable downstream parsing, read `structuredContent.responses` or CLI `--json`.
