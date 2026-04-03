import Foundation
import AugeCore

func runImageSourceTests() {
    // --- Supported file extensions ---

    test("png is supported") {
        try assertTrue(ImageSource.isSupportedExtension("png"))
    }
    test("jpg is supported") {
        try assertTrue(ImageSource.isSupportedExtension("jpg"))
    }
    test("jpeg is supported") {
        try assertTrue(ImageSource.isSupportedExtension("jpeg"))
    }
    test("tiff is supported") {
        try assertTrue(ImageSource.isSupportedExtension("tiff"))
    }
    test("bmp is supported") {
        try assertTrue(ImageSource.isSupportedExtension("bmp"))
    }
    test("gif is supported") {
        try assertTrue(ImageSource.isSupportedExtension("gif"))
    }
    test("heic is supported") {
        try assertTrue(ImageSource.isSupportedExtension("heic"))
    }
    test("pdf is supported") {
        try assertTrue(ImageSource.isSupportedExtension("pdf"))
    }
    test("webp is not supported") {
        try assertFalse(ImageSource.isSupportedExtension("webp"))
    }
    test("txt is not supported") {
        try assertFalse(ImageSource.isSupportedExtension("txt"))
    }
    test("extensions are case-insensitive") {
        try assertTrue(ImageSource.isSupportedExtension("PNG"))
        try assertTrue(ImageSource.isSupportedExtension("Jpg"))
        try assertTrue(ImageSource.isSupportedExtension("HEIC"))
    }

    // --- Extract extension from path ---

    test("extensionFrom extracts correctly") {
        try assertEqual(ImageSource.extensionFrom(path: "/tmp/photo.png"), "png")
        try assertEqual(ImageSource.extensionFrom(path: "image.JPEG"), "jpeg")
        try assertEqual(ImageSource.extensionFrom(path: "/a/b/c.TiFf"), "tiff")
    }
    test("extensionFrom returns nil for no extension") {
        try assertNil(ImageSource.extensionFrom(path: "/tmp/noext"))
        try assertNil(ImageSource.extensionFrom(path: "justfile"))
    }

    // --- Validate path ---

    test("validatePath rejects nonexistent file") {
        let result = ImageSource.validatePath("/nonexistent/file.png")
        if case .failure(let err) = result {
            if case .fileNotFound = err { } else {
                throw TestFailure("expected .fileNotFound, got \(err)")
            }
        } else {
            throw TestFailure("expected failure")
        }
    }

    test("validatePath rejects unsupported extension") {
        // Create a temp file with wrong extension
        let path = "/tmp/auge_test_bad.txt"
        FileManager.default.createFile(atPath: path, contents: Data("hello".utf8))
        defer { try? FileManager.default.removeItem(atPath: path) }
        let result = ImageSource.validatePath(path)
        if case .failure(let err) = result {
            if case .unsupportedFormat = err { } else {
                throw TestFailure("expected .unsupportedFormat, got \(err)")
            }
        } else {
            throw TestFailure("expected failure")
        }
    }

    test("validatePath accepts existing file with supported extension") {
        let path = "/tmp/auge_test_good.png"
        FileManager.default.createFile(atPath: path, contents: Data())
        defer { try? FileManager.default.removeItem(atPath: path) }
        let result = ImageSource.validatePath(path)
        if case .success(let url) = result {
            try assertEqual(url.path, path)
        } else {
            throw TestFailure("expected success")
        }
    }
}
