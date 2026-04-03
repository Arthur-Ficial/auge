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
}
