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
}
