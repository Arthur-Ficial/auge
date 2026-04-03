import Foundation
import AugeCore

func runImageSourceDeepTests() {
    // --- validatePath with relative paths ---

    test("validatePath with relative path to existing file") {
        let path = "/tmp/auge_deep_test.png"
        FileManager.default.createFile(atPath: path, contents: Data([0x89, 0x50, 0x4E, 0x47]))
        defer { try? FileManager.default.removeItem(atPath: path) }
        let result = ImageSource.validatePath(path)
        if case .success = result { } else {
            throw TestFailure("expected success for existing .png")
        }
    }

    // --- validatePath returns correct URL ---

    test("validatePath success URL has correct path") {
        let path = "/tmp/auge_url_test.jpg"
        FileManager.default.createFile(atPath: path, contents: Data())
        defer { try? FileManager.default.removeItem(atPath: path) }
        if case .success(let url) = ImageSource.validatePath(path) {
            try assertTrue(url.isFileURL, "should be file URL")
            try assertEqual(url.pathExtension, "jpg")
        } else {
            throw TestFailure("expected success")
        }
    }

    // --- validatePath with unicode paths ---

    test("validatePath with unicode filename") {
        let path = "/tmp/auge_\u{00FC}bung.png"  // übung
        FileManager.default.createFile(atPath: path, contents: Data())
        defer { try? FileManager.default.removeItem(atPath: path) }
        let result = ImageSource.validatePath(path)
        if case .success = result { } else {
            throw TestFailure("should accept unicode filename")
        }
    }

    // --- validatePath with spaces ---

    test("validatePath with spaces in filename") {
        let path = "/tmp/auge test image.png"
        FileManager.default.createFile(atPath: path, contents: Data())
        defer { try? FileManager.default.removeItem(atPath: path) }
        if case .success = ImageSource.validatePath(path) { } else {
            throw TestFailure("should accept spaces in filename")
        }
    }

    // --- validatePath error types carry correct info ---

    test("validatePath fileNotFound carries the original path") {
        let path = "/tmp/auge_does_not_exist_12345.png"
        if case .failure(let err) = ImageSource.validatePath(path) {
            if case .fileNotFound(let p) = err {
                try assertEqual(p, path)
            } else {
                throw TestFailure("expected .fileNotFound, got \(err)")
            }
        } else {
            throw TestFailure("expected failure")
        }
    }
    test("validatePath unsupportedFormat carries the extension") {
        let path = "/tmp/auge_deep_bad.xyz"
        FileManager.default.createFile(atPath: path, contents: Data())
        defer { try? FileManager.default.removeItem(atPath: path) }
        if case .failure(let err) = ImageSource.validatePath(path) {
            if case .unsupportedFormat(let fmt) = err {
                try assertEqual(fmt, "xyz")
            } else {
                throw TestFailure("expected .unsupportedFormat, got \(err)")
            }
        } else {
            throw TestFailure("expected failure")
        }
    }

    // --- validatePath with no-extension file ---

    test("validatePath rejects file with no extension") {
        let path = "/tmp/auge_noext_test"
        FileManager.default.createFile(atPath: path, contents: Data())
        defer { try? FileManager.default.removeItem(atPath: path) }
        if case .failure(let err) = ImageSource.validatePath(path) {
            if case .unsupportedFormat(let fmt) = err {
                try assertEqual(fmt, "unknown")
            } else {
                throw TestFailure("expected .unsupportedFormat, got \(err)")
            }
        } else {
            throw TestFailure("expected failure")
        }
    }

    // --- isSupportedExtension exhaustive ---

    test("all 10 supported extensions individually") {
        let supported = ["png", "jpg", "jpeg", "tiff", "tif", "bmp", "gif", "heic", "heif", "pdf"]
        for ext in supported {
            try assertTrue(ImageSource.isSupportedExtension(ext), "\(ext) should be supported")
        }
    }
    test("common unsupported formats individually") {
        let unsupported = ["webp", "svg", "ico", "raw", "cr2", "nef", "psd", "ai", "eps", "mp4", "mov", "txt", "html", "json", "xml"]
        for ext in unsupported {
            try assertFalse(ImageSource.isSupportedExtension(ext), "\(ext) should NOT be supported")
        }
    }

    // --- extensionFrom edge cases ---

    test("extensionFrom with trailing dot") {
        // "file." — URL sees no extension
        let ext = ImageSource.extensionFrom(path: "/tmp/file.")
        // macOS URL(fileURLWithPath:) treats trailing dot as empty extension
        try assertNil(ext)
    }
    test("extensionFrom normalizes to lowercase") {
        try assertEqual(ImageSource.extensionFrom(path: "/tmp/img.PNG"), "png")
        try assertEqual(ImageSource.extensionFrom(path: "/tmp/img.JpEg"), "jpeg")
    }
}
