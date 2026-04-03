import Foundation
import AugeCore

func runAugeErrorTests() {
    // --- classify() from error descriptions ---

    test("file not found keyword -> .fileNotFound") {
        let err = NSError(domain: "auge", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "no such file or directory"])
        if case .fileNotFound = AugeError.classify(err) { } else {
            throw TestFailure("expected .fileNotFound")
        }
    }
    test("invalid image keyword -> .invalidImage") {
        let err = NSError(domain: "auge", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "the image could not be decoded"])
        try assertEqual(AugeError.classify(err), .invalidImage)
    }
    test("unsupported format keyword -> .unsupportedFormat") {
        let err = NSError(domain: "auge", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "unsupported image format"])
        if case .unsupportedFormat = AugeError.classify(err) { } else {
            throw TestFailure("expected .unsupportedFormat")
        }
    }
    test("vision unavailable keyword -> .visionUnavailable") {
        let err = NSError(domain: "auge", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "vision framework not available"])
        try assertEqual(AugeError.classify(err), .visionUnavailable)
    }
    test("unknown error -> .unknown") {
        let err = NSError(domain: "auge", code: 0,
            userInfo: [NSLocalizedDescriptionKey: "something went wrong"])
        if case .unknown = AugeError.classify(err) { } else {
            throw TestFailure("expected .unknown")
        }
    }

    // --- CLI labels ---

    test("CLI labels") {
        try assertEqual(AugeError.fileNotFound("/x").cliLabel, "[file not found]")
        try assertEqual(AugeError.invalidImage.cliLabel, "[invalid image]")
        try assertEqual(AugeError.unsupportedFormat("tiff").cliLabel, "[unsupported format]")
        try assertEqual(AugeError.visionUnavailable.cliLabel, "[vision unavailable]")
        try assertEqual(AugeError.noTextFound.cliLabel, "[no text found]")
        try assertEqual(AugeError.noResults.cliLabel, "[no results]")
        try assertEqual(AugeError.unknown("x").cliLabel, "[error]")
    }

    // --- Exit codes ---

    test("exit codes") {
        try assertEqual(AugeError.fileNotFound("/x").exitCode, 1)
        try assertEqual(AugeError.invalidImage.exitCode, 1)
        try assertEqual(AugeError.unsupportedFormat("x").exitCode, 1)
        try assertEqual(AugeError.visionUnavailable.exitCode, 5)
        try assertEqual(AugeError.noTextFound.exitCode, 0)
        try assertEqual(AugeError.noResults.exitCode, 0)
        try assertEqual(AugeError.unknown("x").exitCode, 1)
    }

    // --- User-facing messages ---

    test("userMessage is non-empty for all cases") {
        let cases: [AugeError] = [
            .fileNotFound("/tmp/x.png"), .invalidImage, .unsupportedFormat("bmp"),
            .visionUnavailable, .noTextFound, .noResults, .unknown("oops")
        ]
        for c in cases {
            try assertTrue(!c.userMessage.isEmpty, "\(c)")
        }
    }

    // --- classify passes through existing AugeError ---

    test("classify passes through existing AugeError unchanged") {
        try assertEqual(AugeError.classify(AugeError.invalidImage), .invalidImage)
        try assertEqual(AugeError.classify(AugeError.visionUnavailable), .visionUnavailable)
        try assertEqual(AugeError.classify(AugeError.noTextFound), .noTextFound)
        try assertEqual(AugeError.classify(AugeError.noResults), .noResults)
    }

    // --- Equatable ---

    test("equatable works for associated values") {
        try assertTrue(AugeError.fileNotFound("/a") == AugeError.fileNotFound("/a"))
        try assertFalse(AugeError.fileNotFound("/a") == AugeError.fileNotFound("/b"))
        try assertTrue(AugeError.unknown("x") == AugeError.unknown("x"))
        try assertFalse(AugeError.unknown("x") == AugeError.unknown("y"))
    }
}
