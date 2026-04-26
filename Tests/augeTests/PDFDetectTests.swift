import Foundation
import AugeCore

func runPDFDetectTests() {
    test("PDF magic bytes detected") {
        let pdfBytes = Data([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34])
        try assertTrue(PDFDetect.isPDF(pdfBytes))
    }
    test("exact 5-byte magic detected") {
        try assertTrue(PDFDetect.isPDF(Data(PDFDetect.magic)))
    }
    test("PNG magic not detected as PDF") {
        let pngBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        try assertFalse(PDFDetect.isPDF(pngBytes))
    }
    test("JPEG magic not detected as PDF") {
        let jpegBytes = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        try assertFalse(PDFDetect.isPDF(jpegBytes))
    }
    test("empty data not detected") {
        try assertFalse(PDFDetect.isPDF(Data()))
    }
    test("4 bytes too short to detect") {
        try assertFalse(PDFDetect.isPDF(Data([0x25, 0x50, 0x44, 0x46])))
    }
    test("partial match (different fifth byte) rejected") {
        try assertFalse(PDFDetect.isPDF(Data([0x25, 0x50, 0x44, 0x46, 0xFF])))
    }
    test("ASCII '%PDF-' also detected") {
        let asciiPDF = "%PDF-1.7\n".data(using: .ascii)!
        try assertTrue(PDFDetect.isPDF(asciiPDF))
    }
    test("magic bytes are exactly 5 long") {
        try assertEqual(PDFDetect.magic.count, 5)
    }
    test("magic decodes to '%PDF-'") {
        try assertEqual(String(bytes: PDFDetect.magic, encoding: .ascii), "%PDF-")
    }
    test("isPDF(at:) on missing file returns false") {
        let url = URL(fileURLWithPath: "/tmp/auge-nonexistent-\(UUID().uuidString).pdf")
        try assertFalse(PDFDetect.isPDF(at: url))
    }
    test("isPDF(at:) on real PDF file returns true") {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("auge-test-\(UUID().uuidString).pdf")
        let bytes = "%PDF-1.4\n%\u{00E2}\u{00E3}\u{00CF}\u{00D3}\n".data(using: .isoLatin1)!
        try bytes.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try assertTrue(PDFDetect.isPDF(at: tmp))
    }
    test("isPDF(at:) on PNG file returns false") {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("auge-test-\(UUID().uuidString).png")
        try Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]).write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        try assertFalse(PDFDetect.isPDF(at: tmp))
    }
}
