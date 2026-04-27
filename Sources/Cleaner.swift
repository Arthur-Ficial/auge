// ============================================================================
// Cleaner.swift — Optional --clean post-pass for OCR text.
// Uses Apple FoundationModels (LanguageModelSession) to dehyphenate, reflow,
// and fix obvious OCR errors. macOS 26 (Tahoe) only — gated @available.
// ============================================================================

@preconcurrency import FoundationModels
import Foundation
import AugeCore

enum Cleaner {
    private static let instructions = """
    Clean OCR text only.
    Preserve meaning, numbers, names, punctuation, and original language.
    Fix obvious OCR spelling errors.
    Join words broken by end-of-line hyphenation.
    Reflow lines that were split only by layout.
    Preserve real paragraphs and list/table cell content.
    Return only the cleaned text — no commentary, no preamble.
    """

    /// Clean a list of OCR lines. Returns cleaned lines (may differ in count).
    static func clean(lines: [String]) async throws -> [String] {
        let joined = lines.joined(separator: "\n")
        let cleaned = try await clean(text: joined)
        return cleaned
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    /// Clean a single text blob. Chunks long inputs to stay under model limits.
    static func clean(text: String) async throws -> String {
        guard SystemLanguageModel.default.isAvailable else {
            throw AugeError.unknown("FoundationModels system language model is not available on this device")
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return text }

        let chunks = CleanChunker.chunk(trimmed)
        var output: [String] = []
        output.reserveCapacity(chunks.count)

        for chunk in chunks {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: chunk)
            output.append(response.content.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return output.joined(separator: "\n\n")
    }
}
