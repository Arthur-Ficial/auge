import Foundation
import AugeCore

func runResultFormatterDeepTests() {
    // --- formatClassification exact format ---

    test("formatClassification exact format: 'label: NN%'") {
        let results = [ClassificationResult(label: "cat", confidence: 0.95)]
        let output = ResultFormatter.formatClassification(results)
        try assertEqual(output, "cat: 95%")
    }
    test("formatClassification 100% confidence") {
        let results = [ClassificationResult(label: "sure", confidence: 1.0)]
        let output = ResultFormatter.formatClassification(results)
        try assertEqual(output, "sure: 100%")
    }
    test("formatClassification 0% confidence") {
        let results = [ClassificationResult(label: "nope", confidence: 0.0)]
        let output = ResultFormatter.formatClassification(results)
        try assertEqual(output, "nope: 0%")
    }
    test("formatClassification 1% confidence") {
        let results = [ClassificationResult(label: "tiny", confidence: 0.01)]
        let output = ResultFormatter.formatClassification(results)
        try assertEqual(output, "tiny: 1%")
    }
    test("formatClassification equal confidences — both present") {
        let results = [
            ClassificationResult(label: "a", confidence: 0.5),
            ClassificationResult(label: "b", confidence: 0.5),
        ]
        let output = ResultFormatter.formatClassification(results)
        try assertTrue(output.contains("a: 50%"))
        try assertTrue(output.contains("b: 50%"))
        try assertEqual(output.components(separatedBy: "\n").count, 2)
    }
    test("formatClassification multiline format") {
        let results = [
            ClassificationResult(label: "cat", confidence: 0.9),
            ClassificationResult(label: "dog", confidence: 0.3),
        ]
        let output = ResultFormatter.formatClassification(results)
        try assertEqual(output, "cat: 90%\ndog: 30%")
    }

    // --- formatBarcodes exact format ---

    test("formatBarcodes exact format: '[TYPE] payload'") {
        let results = [BarcodeResult(payload: "hello", symbology: "QR")]
        let output = ResultFormatter.formatBarcodes(results)
        try assertEqual(output, "[QR] hello")
    }
    test("formatBarcodes multiline format") {
        let results = [
            BarcodeResult(payload: "A", symbology: "QR"),
            BarcodeResult(payload: "B", symbology: "EAN13"),
        ]
        let output = ResultFormatter.formatBarcodes(results)
        try assertEqual(output, "[QR] A\n[EAN13] B")
    }
    test("formatBarcodes with URL payload") {
        let results = [BarcodeResult(payload: "https://example.com/path?q=1&r=2", symbology: "QR")]
        let output = ResultFormatter.formatBarcodes(results)
        try assertEqual(output, "[QR] https://example.com/path?q=1&r=2")
    }

    // --- formatFaces exact format ---

    test("formatFaces exact format: 'N face(s) detected'") {
        try assertEqual(ResultFormatter.formatFaces([]), "0 faces detected")
        try assertEqual(
            ResultFormatter.formatFaces([FaceResult(x: 0, y: 0, width: 1, height: 1)]),
            "1 face detected"
        )
        try assertEqual(
            ResultFormatter.formatFaces([
                FaceResult(x: 0, y: 0, width: 1, height: 1),
                FaceResult(x: 0.5, y: 0.5, width: 0.5, height: 0.5),
            ]),
            "2 faces detected"
        )
    }
    test("formatFaces with 100 faces") {
        let faces = (0..<100).map { _ in FaceResult(x: 0, y: 0, width: 0.1, height: 0.1) }
        let output = ResultFormatter.formatFaces(faces)
        try assertEqual(output, "100 faces detected")
    }

    // --- formatOCR edge cases ---

    test("formatOCR with empty strings in array") {
        let lines = ["Hello", "", "World"]
        let output = ResultFormatter.formatOCR(lines)
        try assertEqual(output, "Hello\n\nWorld")
    }
    test("formatOCR with unicode text") {
        let lines = ["\u{00FC}bung", "\u{00E4}\u{00F6}\u{00FC}", "\u{1F600}"]  // übung, äöü, emoji
        let output = ResultFormatter.formatOCR(lines)
        try assertTrue(output.contains("\u{00FC}bung"))
        try assertTrue(output.contains("\u{1F600}"))
    }
    test("formatOCR with very long line") {
        let longLine = String(repeating: "x", count: 10000)
        let output = ResultFormatter.formatOCR([longLine])
        try assertEqual(output.count, 10000)
    }
    test("formatOCR with newlines inside a line") {
        // Lines from Vision already have newlines stripped, but test that
        // formatOCR doesn't break if a line contains one
        let lines = ["line with\nnewline"]
        let output = ResultFormatter.formatOCR(lines)
        try assertEqual(output, "line with\nnewline")
    }

    // --- JSON round-trip: encode then decode ---

    test("ClassificationResult JSON round-trip") {
        let original = ClassificationResult(label: "cat", confidence: 0.95)
        let encoder = JSONEncoder()
        let data = try! encoder.encode(original)
        let decoded = try! JSONDecoder().decode(ClassificationResult.self, from: data)
        try assertEqual(decoded.label, "cat")
        try assertEqual(decoded.confidence, 0.95)
    }
    test("BarcodeResult JSON round-trip") {
        let original = BarcodeResult(payload: "https://example.com", symbology: "QR")
        let encoder = JSONEncoder()
        let data = try! encoder.encode(original)
        let decoded = try! JSONDecoder().decode(BarcodeResult.self, from: data)
        try assertEqual(decoded.payload, "https://example.com")
        try assertEqual(decoded.symbology, "QR")
    }
    test("FaceResult JSON round-trip") {
        let original = FaceResult(x: 0.123, y: 0.456, width: 0.789, height: 0.012)
        let encoder = JSONEncoder()
        let data = try! encoder.encode(original)
        let decoded = try! JSONDecoder().decode(FaceResult.self, from: data)
        try assertEqual(decoded.x, 0.123)
        try assertEqual(decoded.y, 0.456)
        try assertEqual(decoded.width, 0.789)
        try assertEqual(decoded.height, 0.012)
    }

    // --- JSON key names ---

    test("ClassificationResult JSON keys are 'label' and 'confidence'") {
        let r = ClassificationResult(label: "x", confidence: 0.5)
        let data = try! JSONEncoder().encode(r)
        let dict = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        try assertTrue(dict.keys.contains("label"), "missing 'label' key")
        try assertTrue(dict.keys.contains("confidence"), "missing 'confidence' key")
        try assertEqual(dict.count, 2, "should have exactly 2 keys")
    }
    test("BarcodeResult JSON keys are 'payload' and 'symbology'") {
        let r = BarcodeResult(payload: "x", symbology: "y")
        let data = try! JSONEncoder().encode(r)
        let dict = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        try assertTrue(dict.keys.contains("payload"), "missing 'payload' key")
        try assertTrue(dict.keys.contains("symbology"), "missing 'symbology' key")
        try assertEqual(dict.count, 2, "should have exactly 2 keys")
    }
    test("FaceResult JSON keys are x, y, width, height") {
        let r = FaceResult(x: 0, y: 0, width: 1, height: 1)
        let data = try! JSONEncoder().encode(r)
        let dict = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        for key in ["x", "y", "width", "height"] {
            try assertTrue(dict.keys.contains(key), "missing '\(key)' key")
        }
        try assertEqual(dict.count, 4, "should have exactly 4 keys")
    }

    // --- ClassificationResult with label containing special chars ---

    test("ClassificationResult with spaces in label") {
        let r = ClassificationResult(label: "ice cream", confidence: 0.8)
        let output = ResultFormatter.formatClassification([r])
        try assertEqual(output, "ice cream: 80%")
    }
    test("ClassificationResult with unicode label") {
        let r = ClassificationResult(label: "k\u{00E4}se", confidence: 0.7)  // käse
        let output = ResultFormatter.formatClassification([r])
        try assertTrue(output.contains("k\u{00E4}se"))
    }
}
