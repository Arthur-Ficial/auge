// ============================================================================
// CLI.swift — Command-line interface commands
// Part of auge — Apple Vision from the command line
// ============================================================================

import Foundation
import AugeCore

// MARK: - JSON schema version
let augeSchemaVersion = "1"

// MARK: - Output Result

/// Output an analysis result in the configured format.
func outputResult(mode: String, file: String, payload: ResultPayload) {
    switch outputFormat {
    case .plain:
        let text = plainTextFor(payload: payload)
        print(text)

    case .md:
        let text = markdownFor(payload: payload)
        print(text)

    case .json:
        let response = AugeResponse(
            mode: mode,
            file: file,
            results: payload,
            metadata: .init(onDevice: true, version: version, schema: augeSchemaVersion)
        )
        print(jsonString(response, pretty: !compactMode))

    case .ndjson:
        let response = AugeResponse(
            mode: mode,
            file: file,
            results: payload,
            metadata: .init(onDevice: true, version: version, schema: augeSchemaVersion)
        )
        print(jsonString(response, pretty: false))
    }
}

private func plainTextFor(payload: ResultPayload) -> String {
    switch payload {
    case .ocr(let p):                return p.text
    case .classification(let p):     return ResultFormatter.formatClassification(p.classifications)
    case .barcodes(let p):           return ResultFormatter.formatBarcodes(p.barcodes)
    case .faces(let p):              return ResultFormatter.formatFaces(p.faces)
    case .faceLandmarks(let p):      return ResultFormatter.formatFaceLandmarks(p.faces)
    case .faceQuality(let p):        return ResultFormatter.formatFaceQuality(p.faces)
    case .humans(let p):             return ResultFormatter.formatHumans(p.humans)
    case .textRectangles(let p):     return ResultFormatter.formatTextRectangles(p.rectangles)
    case .rectangles(let p):         return ResultFormatter.formatRectangles(p.rectangles)
    case .horizon(let p):            return ResultFormatter.formatHorizon(p.horizon)
    case .animals(let p):            return ResultFormatter.formatAnimals(p.animals)
    case .animalPose(let p):         return ResultFormatter.formatAnimalPose(p.animals)
    case .bodyPose(let p):           return ResultFormatter.formatBodyPose(p.bodies)
    case .handPose(let p):           return ResultFormatter.formatHandPose(p.hands)
    case .saliencyAttention(let p):  return ResultFormatter.formatSaliency(p.regions)
    case .saliencyObjectness(let p): return ResultFormatter.formatSaliency(p.regions)
    case .contours(let p):           return ResultFormatter.formatContours(p.contours)
    case .featurePrint(let p):       return ResultFormatter.formatFeaturePrint(p.featurePrint)
    case .compare(let p):            return ResultFormatter.formatCompare(p.compare)
    case .aesthetics(let p):         return ResultFormatter.formatAesthetics(p.aesthetics)
    case .smudge(let p):             return ResultFormatter.formatSmudge(p.smudge)
    case .document(let p):           return ResultFormatter.formatDocument(p.document)
    case .all(let p):                return ResultFormatter.formatAll(
        ocrLines: p.ocr?.lines,
        classifications: p.classify?.classifications,
        barcodes: p.barcodes?.barcodes,
        faces: p.faces?.faces
    )
    }
}

private func markdownFor(payload: ResultPayload) -> String {
    switch payload {
    case .ocr(let p):                return ResultFormatter.markdownOCR(p.lines)
    case .classification(let p):     return ResultFormatter.markdownClassification(p.classifications)
    case .barcodes(let p):           return ResultFormatter.markdownBarcodes(p.barcodes)
    case .faces(let p):              return ResultFormatter.markdownFaces(p.faces)
    case .faceLandmarks(let p):      return ResultFormatter.markdownFaceLandmarks(p.faces)
    case .faceQuality(let p):        return ResultFormatter.markdownFaceQuality(p.faces)
    case .humans(let p):             return ResultFormatter.markdownHumans(p.humans)
    case .textRectangles(let p):     return ResultFormatter.markdownTextRectangles(p.rectangles)
    case .rectangles(let p):         return ResultFormatter.markdownRectangles(p.rectangles)
    case .horizon(let p):            return ResultFormatter.markdownHorizon(p.horizon)
    case .animals(let p):            return ResultFormatter.markdownAnimals(p.animals)
    case .animalPose(let p):         return ResultFormatter.markdownAnimalPose(p.animals)
    case .bodyPose(let p):           return ResultFormatter.markdownBodyPose(p.bodies)
    case .handPose(let p):           return ResultFormatter.markdownHandPose(p.hands)
    case .saliencyAttention(let p):  return ResultFormatter.markdownSaliency(p.regions)
    case .saliencyObjectness(let p): return ResultFormatter.markdownSaliency(p.regions)
    case .contours(let p):           return ResultFormatter.markdownContours(p.contours)
    case .featurePrint(let p):       return ResultFormatter.markdownFeaturePrint(p.featurePrint)
    case .compare(let p):            return ResultFormatter.markdownCompare(p.compare)
    case .aesthetics(let p):         return ResultFormatter.markdownAesthetics(p.aesthetics)
    case .smudge(let p):             return ResultFormatter.markdownSmudge(p.smudge)
    case .document(let p):           return ResultFormatter.markdownDocument(p.document)
    case .all(let p):                return ResultFormatter.markdownAll(
        ocrLines: p.ocr?.lines,
        classifications: p.classify?.classifications,
        barcodes: p.barcodes?.barcodes,
        faces: p.faces?.faces
    )
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
    \(styled("\u{251C}", .dim)) on-device:    100% local Apple Vision (no cloud, no API keys)
    \(styled("\u{251C}", .dim)) framework:    Vision (macOS 26 Tahoe baseline)
    \(styled("\u{251C}", .dim)) ocr:          text recognition (accurate + fast modes)
    \(styled("\u{251C}", .dim)) classify:     image classification (1000+ categories)
    \(styled("\u{251C}", .dim)) barcode:      QR codes, EAN, Code128, and more
    \(styled("\u{251C}", .dim)) faces:        detection / landmarks (76 pts) / capture quality
    \(styled("\u{251C}", .dim)) bodies:       human rectangles, body pose, hand pose
    \(styled("\u{251C}", .dim)) animals:      cats / dogs / animal pose
    \(styled("\u{251C}", .dim)) geometry:     rectangles, horizon, contours, text rectangles
    \(styled("\u{251C}", .dim)) saliency:     attention + objectness (boxes only, never heatmap)
    \(styled("\u{251C}", .dim)) embeddings:   feature-print + compare (cosine distance)
    \(styled("\u{251C}", .dim)) formats:      PNG, JPEG, TIFF, BMP, GIF, HEIC, PDF
    \(styled("\u{2514}", .dim)) output:       plain | json | md | ndjson

    \(styled("LINKS:", .yellow, .bold))
    \(styled("\u{251C}", .dim)) repo:       https://github.com/Arthur-Ficial/auge
    \(styled("\u{2514}", .dim)) requires:   macOS 26 (Tahoe)
    """)
}

// MARK: - Usage

/// Print the help text. Styled with ANSI colors when on a TTY.
func printUsage() {
    print("""
    \(styled(appName, .cyan, .bold)) v\(version) — Apple Vision from the command line

    \(styled("USAGE:", .yellow, .bold))
      \(appName) --all <image>                Run every analysis on the image
      \(appName) --ocr <image>                Extract text from image (OCR)
      \(appName) --classify <image>           Classify image content
      \(appName) --barcode <image>            Detect barcodes and QR codes
      \(appName) --faces <image>              Detect faces (bounding boxes)
      \(appName) --face-landmarks <image>     Detect 76-point face landmarks + roll/yaw/pitch
      \(appName) --face-quality <image>       Per-face capture quality score
      \(appName) --humans <image>             Detect humans (bounding boxes)
      \(appName) --text-rectangles <image>    Detect text regions (no recognition)
      \(appName) --rectangles <image>         Detect quadrilaterals (paper, screens, signs)
      \(appName) --horizon <image>            Detect horizon angle
      \(appName) --animals <image>            Detect cats and dogs
      \(appName) --animal-pose <image>        Detect animal body pose joints
      \(appName) --body-pose <image>          Detect human body pose joints
      \(appName) --hand-pose <image>          Detect hand pose keypoints
      \(appName) --saliency-attention <image> Salient regions (attention-based, boxes only)
      \(appName) --saliency-objectness <image> Salient regions (object-based, boxes only)
      \(appName) --contours <image>           Detect vector contours
      \(appName) --feature-print <image>      Image embedding (descriptor vector)
      \(appName) --compare <a> <b>            Cosine distance between two images
      \(appName) --aesthetics <image>         Score image aesthetics (utility flag included)
      \(appName) --smudge <image>             Detect lens smudge confidence
      \(appName) --document <image>           Parse structured document (paragraphs, lists, tables)

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
          --upper-body-only     For --humans: detect upper body only
          --max-hands <n>       For --hand-pose: max hands [default: 2]
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
      \(appName) --classify photo.jpg --top 5
      \(appName) --barcode product.jpg
      \(appName) --face-landmarks portrait.jpg --json
      \(appName) --rectangles whiteboard.jpg
      \(appName) --horizon landscape.jpg
      \(appName) --feature-print a.jpg --json | jq .results.featurePrint.dimension
      \(appName) --compare a.jpg b.jpg
      \(appName) --ocr screenshot.png | apfel "summarize this"
      ls *.png | \(appName) --classify --ndjson
    """)
}
