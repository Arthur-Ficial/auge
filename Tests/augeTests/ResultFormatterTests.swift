import Foundation
import AugeCore

func runResultFormatterTests() {
    // --- OCR result formatting ---

    test("formatOCR joins lines with newlines") {
        let lines = ["Hello", "World"]
        try assertEqual(ResultFormatter.formatOCR(lines), "Hello\nWorld")
    }
    test("formatOCR handles single line") {
        try assertEqual(ResultFormatter.formatOCR(["Hello"]), "Hello")
    }
    test("formatOCR handles empty array") {
        try assertEqual(ResultFormatter.formatOCR([]), "")
    }

    // --- Classification result formatting ---

    test("formatClassification shows label and confidence") {
        let results = [ClassificationResult(label: "cat", confidence: 0.95)]
        let output = ResultFormatter.formatClassification(results)
        try assertTrue(output.contains("cat"))
        try assertTrue(output.contains("95"))
    }
    test("formatClassification sorts by confidence descending") {
        let results = [
            ClassificationResult(label: "dog", confidence: 0.3),
            ClassificationResult(label: "cat", confidence: 0.9),
        ]
        let output = ResultFormatter.formatClassification(results)
        guard let catRange = output.range(of: "cat"),
              let dogRange = output.range(of: "dog") else {
            throw TestFailure("output missing 'cat' or 'dog': \(output)")
        }
        try assertTrue(catRange.lowerBound < dogRange.lowerBound, "cat should appear before dog")
    }
    test("formatClassification handles empty array") {
        try assertEqual(ResultFormatter.formatClassification([]), "")
    }

    // --- Barcode result formatting ---

    test("formatBarcodes shows payload and type") {
        let results = [BarcodeResult(payload: "https://example.com", symbology: "QR")]
        let output = ResultFormatter.formatBarcodes(results)
        try assertTrue(output.contains("https://example.com"))
        try assertTrue(output.contains("QR"))
    }
    test("formatBarcodes handles multiple results") {
        let results = [
            BarcodeResult(payload: "ABC", symbology: "Code128"),
            BarcodeResult(payload: "123", symbology: "EAN13"),
        ]
        let output = ResultFormatter.formatBarcodes(results)
        try assertTrue(output.contains("ABC"))
        try assertTrue(output.contains("123"))
    }
    test("formatBarcodes handles empty array") {
        try assertEqual(ResultFormatter.formatBarcodes([]), "")
    }

    // --- Face detection result formatting ---

    test("formatFaces shows count") {
        let results = [
            FaceResult(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            FaceResult(x: 0.5, y: 0.6, width: 0.2, height: 0.3),
        ]
        let output = ResultFormatter.formatFaces(results)
        try assertTrue(output.contains("2"))
    }
    test("formatFaces handles single face") {
        let results = [FaceResult(x: 0.1, y: 0.2, width: 0.3, height: 0.4)]
        let output = ResultFormatter.formatFaces(results)
        try assertTrue(output.contains("1"))
    }
    test("formatFaces handles empty array") {
        let output = ResultFormatter.formatFaces([])
        try assertTrue(output.contains("0"))
    }

    // --- JSON encoding of results ---

    test("ClassificationResult encodes to JSON") {
        let r = ClassificationResult(label: "cat", confidence: 0.95)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try! encoder.encode(r)
        let json = String(data: data, encoding: .utf8)!
        try assertTrue(json.contains("\"label\":\"cat\""))
        try assertTrue(json.contains("\"confidence\""))
    }
    test("BarcodeResult encodes to JSON") {
        let r = BarcodeResult(payload: "hello", symbology: "QR")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try! encoder.encode(r)
        let json = String(data: data, encoding: .utf8)!
        try assertTrue(json.contains("\"payload\":\"hello\""))
        try assertTrue(json.contains("\"symbology\":\"QR\""))
    }
    test("FaceResult encodes to JSON") {
        let r = FaceResult(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try! encoder.encode(r)
        let json = String(data: data, encoding: .utf8)!
        try assertTrue(json.contains("\"x\""))
        try assertTrue(json.contains("\"width\""))
    }
}
