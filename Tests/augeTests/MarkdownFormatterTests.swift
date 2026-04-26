import Foundation
import AugeCore

func runMarkdownFormatterTests() {
    test("markdownOCR with empty lines returns empty") {
        try assertEqual(ResultFormatter.markdownOCR([]), "")
    }
    test("markdownOCR preserves line breaks") {
        try assertEqual(ResultFormatter.markdownOCR(["a", "b", "c"]), "a\nb\nc")
    }
    test("markdownOCR is identical to plain (no structure yet)") {
        let lines = ["one", "two"]
        try assertEqual(ResultFormatter.markdownOCR(lines), ResultFormatter.formatOCR(lines))
    }

    test("markdownClassification produces bullet list") {
        let r = [ClassificationResult(label: "cat", confidence: 0.9)]
        let md = ResultFormatter.markdownClassification(r)
        try assertEqual(md, "- **cat** — 90%")
    }
    test("markdownClassification sorts by confidence descending") {
        let r = [
            ClassificationResult(label: "low", confidence: 0.1),
            ClassificationResult(label: "high", confidence: 0.9),
        ]
        let md = ResultFormatter.markdownClassification(r)
        let lines = md.components(separatedBy: "\n")
        try assertTrue(lines[0].contains("high"))
        try assertTrue(lines[1].contains("low"))
    }
    test("markdownClassification empty returns empty") {
        try assertEqual(ResultFormatter.markdownClassification([]), "")
    }

    test("markdownBarcodes uses backticks for symbology") {
        let r = [BarcodeResult(payload: "abc", symbology: "QR")]
        let md = ResultFormatter.markdownBarcodes(r)
        try assertEqual(md, "- `QR`: abc")
    }
    test("markdownBarcodes empty returns empty") {
        try assertEqual(ResultFormatter.markdownBarcodes([]), "")
    }

    test("markdownFaces zero produces explicit zero header") {
        try assertEqual(ResultFormatter.markdownFaces([]), "**0 faces detected**")
    }
    test("markdownFaces singular vs plural") {
        let one = ResultFormatter.markdownFaces([FaceResult(x: 0, y: 0, width: 1, height: 1)])
        let two = ResultFormatter.markdownFaces([
            FaceResult(x: 0, y: 0, width: 1, height: 1),
            FaceResult(x: 0.5, y: 0.5, width: 0.5, height: 0.5),
        ])
        try assertTrue(one.contains("1 face "))
        try assertTrue(two.contains("2 faces"))
    }
    test("markdownFaces includes per-face bullets") {
        let md = ResultFormatter.markdownFaces([
            FaceResult(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
        ])
        try assertTrue(md.contains("- face 1"))
        try assertTrue(md.contains("x=0.100"))
    }
}
