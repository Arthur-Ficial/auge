// ============================================================================
// CLI.swift — Command-line interface commands
// Part of auge — Apple Vision from the command line
// ============================================================================

import Foundation
import AugeCore

// MARK: - Output Result

/// Output an analysis result in the configured format.
func outputResult(mode: String, file: String, payload: ResultPayload) {
    switch outputFormat {
    case .plain:
        switch payload {
        case .ocr(let p):
            print(p.text)
        case .classification(let p):
            print(ResultFormatter.formatClassification(p.classifications))
        case .barcodes(let p):
            print(ResultFormatter.formatBarcodes(p.barcodes))
        case .faces(let p):
            print(ResultFormatter.formatFaces(p.faces))
        }

    case .md:
        switch payload {
        case .ocr(let p):
            print(ResultFormatter.markdownOCR(p.lines))
        case .classification(let p):
            print(ResultFormatter.markdownClassification(p.classifications))
        case .barcodes(let p):
            print(ResultFormatter.markdownBarcodes(p.barcodes))
        case .faces(let p):
            print(ResultFormatter.markdownFaces(p.faces))
        }

    case .json:
        let response = AugeResponse(
            mode: mode,
            file: file,
            results: payload,
            metadata: .init(onDevice: true, version: version)
        )
        print(jsonString(response, pretty: !compactMode))

    case .ndjson:
        let response = AugeResponse(
            mode: mode,
            file: file,
            results: payload,
            metadata: .init(onDevice: true, version: version)
        )
        // NDJSON: always one line per record, no pretty-print.
        print(jsonString(response, pretty: false))
    }
}

// MARK: - Release Info

func printRelease() {
    print("""
    \(styled(appName, .cyan, .bold)) v\(version) — release info

    \(styled("VERSION:", .yellow, .bold))
    \(styled("\u{251C}", .dim)) version:    \(version)
    \(styled("\u{251C}", .dim)) commit:     \(buildCommit)
    \(styled("\u{251C}", .dim)) branch:     \(buildBranch)
    \(styled("\u{251C}", .dim)) built:      \(buildDate)
    \(styled("\u{251C}", .dim)) swift:      \(buildSwiftVersion)
    \(styled("\u{2514}", .dim)) os:         \(buildOS)

    \(styled("CAPABILITIES:", .yellow, .bold))
    \(styled("\u{251C}", .dim)) on-device:  100% local vision analysis (no cloud, no API keys)
    \(styled("\u{251C}", .dim)) framework:  Vision (macOS 10.15+)
    \(styled("\u{251C}", .dim)) ocr:        text recognition (accurate + fast modes)
    \(styled("\u{251C}", .dim)) classify:   image classification (1000+ categories)
    \(styled("\u{251C}", .dim)) barcode:    QR codes, EAN, Code128, and more
    \(styled("\u{251C}", .dim)) faces:      face detection with bounding boxes
    \(styled("\u{251C}", .dim)) formats:    PNG, JPEG, TIFF, BMP, GIF, HEIC, PDF
    \(styled("\u{2514}", .dim)) output:     plain text or JSON

    \(styled("LINKS:", .yellow, .bold))
    \(styled("\u{251C}", .dim)) repo:       https://github.com/Arthur-Ficial/auge
    \(styled("\u{2514}", .dim)) requires:   macOS 10.15+ (classification requires macOS 12+)
    """)
}

// MARK: - Usage

/// Print the help text. Styled with ANSI colors when on a TTY.
func printUsage() {
    print("""
    \(styled(appName, .cyan, .bold)) v\(version) — Apple Vision from the command line

    \(styled("USAGE:", .yellow, .bold))
      \(appName) --ocr <image>              Extract text from image (OCR)
      \(appName) --classify <image>         Classify image content
      \(appName) --barcode <image>          Detect barcodes and QR codes
      \(appName) --faces <image>            Detect faces

    \(styled("OPTIONS:", .yellow, .bold))
      -o, --output <format>     Output format: plain, json, md, ndjson [default: plain]
          --plain               Plain text output (same as -o plain)
          --json                JSON output (same as -o json)
          --md                  Markdown output (same as -o md)
          --ndjson              NDJSON: one compact JSON per line, ideal for multi-file
          --compact             Compact single-line JSON (when -o json or --json)
      -q, --quiet               Suppress non-essential output
          --no-color            Disable colored output
          --clipboard           Read image from the macOS clipboard (NSPasteboard)
          --dpi <n>             PDF rasterization DPI 72-600 [default: 200]
          --prefer-embedded     Use PDF text layer when present [default]
          --no-prefer-embedded  Force OCR even on searchable PDFs
          --langs <a,b,c>       BCP-47 OCR language hints (e.g. en-US,de-DE)
          --enhance             Upscale tiny images before OCR (helps small text)
          --clean               Post-process OCR text with FoundationModels (macOS 26+)
          --top <n>             Max classification results [default: 10]
          --min-confidence <n>  Min confidence threshold 0-1 [default: 0.01]
      -h, --help                Show this help
      -v, --version             Print version
          --release             Show detailed release and build info

    \(styled("ENVIRONMENT:", .yellow, .bold))
      NO_COLOR                  Disable colored output (https://no-color.org)

    \(styled("EXIT CODES:", .yellow, .bold))
      0  Success (also: no text/results found — not an error)
      1  Runtime error (bad file, invalid image, analysis failure)
      2  Usage error (bad flags, missing arguments)
      5  Vision framework unavailable

    \(styled("EXAMPLES:", .yellow, .bold))
      \(appName) --ocr screenshot.png
      \(appName) --ocr scan.pdf
      \(appName) --classify photo.jpg
      \(appName) --classify photo.jpg --top 5
      \(appName) --barcode product.jpg
      \(appName) --faces group.jpg
      \(appName) --ocr screenshot.png -o json | jq .results.lines
      \(appName) --ocr image1.png image2.png
      cat image.png | \(appName) --ocr /dev/stdin
      \(appName) --ocr screenshot.png | apfel "summarize this"
      ls *.png | \(appName) --ocr
    """)
}
