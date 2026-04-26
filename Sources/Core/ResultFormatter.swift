import Foundation

public enum ResultFormatter {
    public static func formatOCR(_ lines: [String]) -> String {
        lines.joined(separator: "\n")
    }

    public static func formatClassification(_ results: [ClassificationResult]) -> String {
        guard !results.isEmpty else { return "" }
        let sorted = results.sorted { $0.confidence > $1.confidence }
        return sorted.map { result in
            let pct = Int(result.confidence * 100)
            return "\(result.label): \(pct)%"
        }.joined(separator: "\n")
    }

    public static func formatBarcodes(_ results: [BarcodeResult]) -> String {
        guard !results.isEmpty else { return "" }
        return results.map { result in
            "[\(result.symbology)] \(result.payload)"
        }.joined(separator: "\n")
    }

    public static func formatFaces(_ results: [FaceResult]) -> String {
        let count = results.count
        let noun = count == 1 ? "face" : "faces"
        return "\(count) \(noun) detected"
    }

    // MARK: - Markdown variants

    /// Markdown output for OCR. Same as plain — structured headings/lists/tables
    /// require RecognizeDocumentsRequest (macOS 26), added in a later phase.
    public static func markdownOCR(_ lines: [String]) -> String {
        lines.joined(separator: "\n")
    }

    public static func markdownClassification(_ results: [ClassificationResult]) -> String {
        guard !results.isEmpty else { return "" }
        let sorted = results.sorted { $0.confidence > $1.confidence }
        return sorted.map { r in
            let pct = Int(r.confidence * 100)
            return "- **\(r.label)** — \(pct)%"
        }.joined(separator: "\n")
    }

    public static func markdownBarcodes(_ results: [BarcodeResult]) -> String {
        guard !results.isEmpty else { return "" }
        return results.map { r in
            "- `\(r.symbology)`: \(r.payload)"
        }.joined(separator: "\n")
    }

    public static func markdownFaces(_ results: [FaceResult]) -> String {
        let count = results.count
        let noun = count == 1 ? "face" : "faces"
        if results.isEmpty {
            return "**0 faces detected**"
        }
        let header = "**\(count) \(noun) detected**"
        let bullets = results.enumerated().map { (i, f) in
            String(format: "- face %d: x=%.3f y=%.3f w=%.3f h=%.3f", i + 1, f.x, f.y, f.width, f.height)
        }
        return ([header] + bullets).joined(separator: "\n")
    }

    // MARK: - Combined --all output

    /// Plain text for --all: each non-nil section prefixed with a section header.
    public static func formatAll(
        ocrLines: [String]?,
        classifications: [ClassificationResult]?,
        barcodes: [BarcodeResult]?,
        faces: [FaceResult]?
    ) -> String {
        var sections: [String] = []

        if let lines = ocrLines, !lines.isEmpty {
            sections.append("=== OCR ===\n" + formatOCR(lines))
        }
        if let cls = classifications, !cls.isEmpty {
            sections.append("=== CLASSIFY ===\n" + formatClassification(cls))
        }
        if let bcs = barcodes, !bcs.isEmpty {
            sections.append("=== BARCODES ===\n" + formatBarcodes(bcs))
        }
        if let fcs = faces {
            sections.append("=== FACES ===\n" + formatFaces(fcs))
        }

        if sections.isEmpty {
            return "(no results across any mode)"
        }
        return sections.joined(separator: "\n\n")
    }

    /// Markdown for --all: each section as an H2.
    public static func markdownAll(
        ocrLines: [String]?,
        classifications: [ClassificationResult]?,
        barcodes: [BarcodeResult]?,
        faces: [FaceResult]?
    ) -> String {
        var sections: [String] = []

        if let lines = ocrLines, !lines.isEmpty {
            sections.append("## OCR\n\n" + markdownOCR(lines))
        }
        if let cls = classifications, !cls.isEmpty {
            sections.append("## Classification\n\n" + markdownClassification(cls))
        }
        if let bcs = barcodes, !bcs.isEmpty {
            sections.append("## Barcodes\n\n" + markdownBarcodes(bcs))
        }
        if let fcs = faces {
            sections.append("## Faces\n\n" + markdownFaces(fcs))
        }

        if sections.isEmpty {
            return "_(no results across any mode)_"
        }
        return sections.joined(separator: "\n\n")
    }
}
