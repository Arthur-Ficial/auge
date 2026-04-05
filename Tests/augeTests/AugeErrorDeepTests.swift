import Foundation
import AugeCore

func runAugeErrorDeepTests() {
    // --- classify: every keyword variant ---

    test("classify: 'file not found' keyword") {
        let err = NSError(domain: "", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "file not found at path"])
        if case .fileNotFound = AugeError.classify(err) { } else {
            throw TestFailure("expected .fileNotFound")
        }
    }
    test("classify: 'No Such File' (mixed case)") {
        let err = NSError(domain: "", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "No Such File or Directory"])
        if case .fileNotFound = AugeError.classify(err) { } else {
            throw TestFailure("expected .fileNotFound")
        }
    }
    test("classify: 'INVALID IMAGE' (uppercase)") {
        let err = NSError(domain: "", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "INVALID IMAGE data received"])
        try assertEqual(AugeError.classify(err), .invalidImage)
    }
    test("classify: 'unsupported image' triggers unsupportedFormat") {
        let err = NSError(domain: "", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "unsupported image type"])
        if case .unsupportedFormat = AugeError.classify(err) { } else {
            throw TestFailure("expected .unsupportedFormat")
        }
    }
    test("classify: 'vision unavailable' triggers visionUnavailable") {
        let err = NSError(domain: "", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "The vision framework is unavailable"])
        try assertEqual(AugeError.classify(err), .visionUnavailable)
    }
    test("classify: 'vision' alone without 'available' does not match") {
        let err = NSError(domain: "", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "vision error occurred"])
        if case .unknown = AugeError.classify(err) { } else {
            throw TestFailure("expected .unknown, got something else")
        }
    }
    test("classify: 'unsupported' alone without 'format'/'image' does not match") {
        let err = NSError(domain: "", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "unsupported operation"])
        if case .unknown = AugeError.classify(err) { } else {
            throw TestFailure("expected .unknown")
        }
    }
    test("classify: empty description -> .unknown") {
        let err = NSError(domain: "", code: 0,
            userInfo: [NSLocalizedDescriptionKey: ""])
        if case .unknown = AugeError.classify(err) { } else {
            throw TestFailure("expected .unknown")
        }
    }

    // --- classify passthrough for ALL cases with associated values ---

    test("classify passthrough: fileNotFound preserves path") {
        let original = AugeError.fileNotFound("/specific/path.png")
        let classified = AugeError.classify(original)
        try assertEqual(classified, original)
        if case .fileNotFound(let path) = classified {
            try assertEqual(path, "/specific/path.png")
        } else {
            throw TestFailure("wrong case")
        }
    }
    test("classify passthrough: unsupportedFormat preserves format") {
        let original = AugeError.unsupportedFormat("webp")
        let classified = AugeError.classify(original)
        try assertEqual(classified, original)
        if case .unsupportedFormat(let fmt) = classified {
            try assertEqual(fmt, "webp")
        } else {
            throw TestFailure("wrong case")
        }
    }
    test("classify passthrough: unknown preserves message") {
        let original = AugeError.unknown("custom error msg")
        let classified = AugeError.classify(original)
        try assertEqual(classified, original)
        if case .unknown(let msg) = classified {
            try assertEqual(msg, "custom error msg")
        } else {
            throw TestFailure("wrong case")
        }
    }
    test("classify passthrough: pdfRenderFailure preserves detail") {
        let original = AugeError.pdfRenderFailure("no pages")
        let classified = AugeError.classify(original)
        try assertEqual(classified, original)
        if case .pdfRenderFailure(let detail) = classified {
            try assertEqual(detail, "no pages")
        } else {
            throw TestFailure("wrong case")
        }
    }

    // --- Cross-type inequality ---

    test("different error types are not equal") {
        try assertFalse(AugeError.invalidImage == AugeError.visionUnavailable)
        try assertFalse(AugeError.noTextFound == AugeError.noResults)
        try assertFalse(AugeError.fileNotFound("/x") == AugeError.unknown("/x"))
        try assertFalse(AugeError.unsupportedFormat("png") == AugeError.fileNotFound("png"))
    }

    // --- userMessage contains associated value ---

    test("userMessage for fileNotFound includes the path") {
        let msg = AugeError.fileNotFound("/tmp/missing.png").userMessage
        try assertTrue(msg.contains("/tmp/missing.png"), "message: \(msg)")
    }
    test("userMessage for unsupportedFormat includes the format") {
        let msg = AugeError.unsupportedFormat("webp").userMessage
        try assertTrue(msg.contains("webp"), "message: \(msg)")
    }
    test("userMessage for pdfRenderFailure includes the detail") {
        let msg = AugeError.pdfRenderFailure("no pages").userMessage
        try assertTrue(msg.contains("no pages"), "message: \(msg)")
    }
    test("userMessage for unknown includes the original message") {
        let msg = AugeError.unknown("something broke").userMessage
        try assertTrue(msg.contains("something broke"), "message: \(msg)")
    }

    // --- cliLabel format consistency ---

    test("all cliLabels are bracketed") {
        let allErrors: [AugeError] = [
            .fileNotFound("x"), .invalidImage, .unsupportedFormat("x"),
            .visionUnavailable, .noTextFound, .noResults, .pdfRenderFailure("x"), .unknown("x")
        ]
        for err in allErrors {
            let label = err.cliLabel
            try assertTrue(label.hasPrefix("["), "\(err): \(label)")
            try assertTrue(label.hasSuffix("]"), "\(err): \(label)")
        }
    }

    // --- exitCode consistency ---

    test("noTextFound and noResults are non-error exit codes") {
        try assertEqual(AugeError.noTextFound.exitCode, 0)
        try assertEqual(AugeError.noResults.exitCode, 0)
    }
    test("all real errors have non-zero exit codes") {
        let errors: [AugeError] = [
            .fileNotFound("x"), .invalidImage, .unsupportedFormat("x"),
            .visionUnavailable, .pdfRenderFailure("x"), .unknown("x")
        ]
        for err in errors {
            try assertTrue(err.exitCode != 0, "\(err) should have non-zero exit")
        }
    }
}
