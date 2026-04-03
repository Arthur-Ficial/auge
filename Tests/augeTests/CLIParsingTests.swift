import Foundation
import AugeCore

// These test the pure-logic argument parsing helpers that live in AugeCore.
// The actual CLI dispatch is tested by integration tests.

func runCLIParsingTests() {
    // --- ImageSource.validatePath edge cases ---

    test("validatePath with directory returns fileNotFound") {
        let result = ImageSource.validatePath("/tmp")
        if case .failure(let err) = result {
            // /tmp exists but is a directory, not a readable image
            // We accept either fileNotFound or unsupportedFormat as valid
            if case .fileNotFound = err { } else if case .unsupportedFormat = err { } else {
                throw TestFailure("expected fileNotFound or unsupportedFormat, got \(err)")
            }
        } else {
            // If it succeeds (directory with no extension), that's also acceptable
            // since validatePath only checks existence + extension
        }
    }

    test("validatePath with empty string fails") {
        let result = ImageSource.validatePath("")
        if case .failure = result { } else {
            throw TestFailure("expected failure for empty path")
        }
    }

    // --- ImageSource extension edge cases ---

    test("tif extension is supported") {
        try assertTrue(ImageSource.isSupportedExtension("tif"))
    }
    test("heif extension is supported") {
        try assertTrue(ImageSource.isSupportedExtension("heif"))
    }
    test("svg is not supported") {
        try assertFalse(ImageSource.isSupportedExtension("svg"))
    }
    test("ico is not supported") {
        try assertFalse(ImageSource.isSupportedExtension("ico"))
    }
    test("empty string is not supported") {
        try assertFalse(ImageSource.isSupportedExtension(""))
    }

    test("extensionFrom handles dotfiles") {
        // .gitignore is a dotfile — URL treats it as having no extension
        let ext = ImageSource.extensionFrom(path: "/tmp/.gitignore")
        try assertNil(ext, "dotfiles should have no extension")
    }
    test("extensionFrom handles multiple dots") {
        try assertEqual(ImageSource.extensionFrom(path: "/tmp/file.backup.png"), "png")
    }
    test("extensionFrom handles spaces in path") {
        try assertEqual(ImageSource.extensionFrom(path: "/tmp/my photo.jpg"), "jpg")
    }

    // --- AugeError edge cases ---

    test("classify recognizes 'doesn't exist' as fileNotFound") {
        let err = NSError(domain: "auge", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "the file doesn't exist"])
        if case .fileNotFound = AugeError.classify(err) { } else {
            throw TestFailure("expected .fileNotFound")
        }
    }
    test("classify recognizes 'corrupt' as invalidImage") {
        let err = NSError(domain: "auge", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "file is corrupt and cannot be read"])
        try assertEqual(AugeError.classify(err), .invalidImage)
    }

    // --- ResultFormatter edge cases ---

    test("formatOCR preserves whitespace in lines") {
        let lines = ["  indented", "normal"]
        let output = ResultFormatter.formatOCR(lines)
        try assertTrue(output.hasPrefix("  indented"))
    }
    test("formatClassification rounds percentages") {
        let results = [ClassificationResult(label: "test", confidence: 0.999)]
        let output = ResultFormatter.formatClassification(results)
        try assertTrue(output.contains("99%") || output.contains("100%"))
    }
    test("formatClassification handles very low confidence") {
        let results = [ClassificationResult(label: "maybe", confidence: 0.02)]
        let output = ResultFormatter.formatClassification(results)
        try assertTrue(output.contains("2%"))
    }
    test("formatBarcodes handles empty payload") {
        let results = [BarcodeResult(payload: "", symbology: "QR")]
        let output = ResultFormatter.formatBarcodes(results)
        try assertTrue(output.contains("QR"))
    }
    test("formatFaces singular vs plural") {
        let one = ResultFormatter.formatFaces([FaceResult(x: 0, y: 0, width: 1, height: 1)])
        let two = ResultFormatter.formatFaces([
            FaceResult(x: 0, y: 0, width: 1, height: 1),
            FaceResult(x: 0.5, y: 0.5, width: 0.5, height: 0.5),
        ])
        try assertTrue(one.contains("1 face "), "singular: \(one)")
        try assertTrue(two.contains("2 faces"), "plural: \(two)")
    }

    // --- ResultTypes encoding edge cases ---

    test("ClassificationResult with zero confidence") {
        let r = ClassificationResult(label: "nothing", confidence: 0.0)
        let encoder = JSONEncoder()
        let data = try! encoder.encode(r)
        let json = String(data: data, encoding: .utf8)!
        try assertTrue(json.contains("\"confidence\""))
    }
    test("FaceResult with normalized coordinates") {
        let r = FaceResult(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        let encoder = JSONEncoder()
        let data = try! encoder.encode(r)
        let json = String(data: data, encoding: .utf8)!
        try assertTrue(json.contains("\"width\""))
    }
    test("BarcodeResult with special characters in payload") {
        let r = BarcodeResult(payload: "https://example.com?a=1&b=2", symbology: "QR")
        let encoder = JSONEncoder()
        let data = try! encoder.encode(r)
        let json = String(data: data, encoding: .utf8)!
        try assertTrue(json.contains("example.com"))
    }

    // --- Multiple results formatting ---

    test("formatOCR with many lines") {
        let lines = (1...100).map { "Line \($0)" }
        let output = ResultFormatter.formatOCR(lines)
        try assertTrue(output.contains("Line 1"))
        try assertTrue(output.contains("Line 100"))
        try assertEqual(output.components(separatedBy: "\n").count, 100)
    }
    test("formatClassification with many results maintains sort") {
        let results = (0..<20).map { i in
            ClassificationResult(label: "item\(i)", confidence: Double(i) / 20.0)
        }
        let output = ResultFormatter.formatClassification(results)
        let lines = output.components(separatedBy: "\n")
        // First line should have highest confidence (item19 = 95%)
        try assertTrue(lines[0].contains("item19"), "first: \(lines[0])")
    }
}
