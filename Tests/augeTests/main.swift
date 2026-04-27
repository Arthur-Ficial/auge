// auge-tests — pure Swift test runner, no XCTest/Testing framework needed
// Run: swift run auge-tests

import Foundation

// MARK: - Minimal test harness

nonisolated(unsafe) var _passed = 0
nonisolated(unsafe) var _failed = 0

func test(_ name: String, _ block: () throws -> Void) {
    do {
        try block()
        print("  \u{2705} \(name)")
        _passed += 1
    } catch {
        print("  \u{274C} \(name): \(error)")
        _failed += 1
    }
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "") throws {
    guard a == b else { throw TestFailure("\(a) != \(b)\(msg.isEmpty ? "" : " — \(msg)")") }
}
func assertNil<T>(_ v: T?, _ msg: String = "") throws {
    guard v == nil else { throw TestFailure("Expected nil, got \(v!)\(msg.isEmpty ? "" : " — \(msg)")") }
}
func assertNotNil<T>(_ v: T?, _ msg: String = "") throws {
    guard v != nil else { throw TestFailure("Expected non-nil\(msg.isEmpty ? "" : " — \(msg)")") }
}
func assertTrue(_ v: Bool, _ msg: String = "") throws {
    guard v else { throw TestFailure("Expected true\(msg.isEmpty ? "" : " — \(msg)")") }
}
func assertFalse(_ v: Bool, _ msg: String = "") throws {
    guard !v else { throw TestFailure("Expected false\(msg.isEmpty ? "" : " — \(msg)")") }
}

struct TestFailure: Error, CustomStringConvertible {
    let description: String
    init(_ msg: String) { description = msg }
}

func suite(_ name: String, _ block: () -> Void) {
    print("\n\(name)")
    block()
}

// MARK: - Run all test suites

suite("AugeErrorTests") { runAugeErrorTests() }
suite("AugeErrorDeepTests") { runAugeErrorDeepTests() }
suite("ImageSourceTests") { runImageSourceTests() }
suite("ImageSourceDeepTests") { runImageSourceDeepTests() }
suite("ResultFormatterTests") { runResultFormatterTests() }
suite("ResultFormatterDeepTests") { runResultFormatterDeepTests() }
suite("CLIParsingTests") { runCLIParsingTests() }
suite("NetworkGuardTests") { runNetworkGuardTests() }
suite("PDFDetectTests") { runPDFDetectTests() }
suite("MarkdownFormatterTests") { runMarkdownFormatterTests() }
suite("LanguageHintsTests") { runLanguageHintsTests() }
suite("ImageSizePolicyTests") { runImageSizePolicyTests() }
suite("CleanChunkerTests") { runCleanChunkerTests() }
suite("LineMergerTests") { runLineMergerTests() }
suite("NewCapabilityFormatterTests") { runNewCapabilityFormatterTests() }

// MARK: - Summary

print("\n\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}")
if _failed == 0 {
    print("\u{2705} All \(_passed) tests passed")
} else {
    print("\u{274C} \(_failed) failed, \(_passed) passed")
    exit(1)
}
