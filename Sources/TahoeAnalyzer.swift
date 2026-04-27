// ============================================================================
// TahoeAnalyzer.swift — New Swift Vision API requests (macOS 14/15/26+).
// Use the WWDC24+ Swift API: typed Request → perform(on:) → typed Observation.
// ============================================================================

import Foundation
import Vision
import AugeCore

enum TahoeAnalyzer {
    // MARK: --aesthetics (macOS 15+, WWDC24)

    static func aesthetics(at url: URL) async throws -> AestheticsResult {
        let image = try ImagePreprocessor.load(url: url, enhance: false)
        let request = CalculateImageAestheticsScoresRequest()
        let obs = try await request.perform(on: image)
        return AestheticsResult(overall: Double(obs.overallScore), isUtility: obs.isUtility)
    }

    // MARK: --smudge (macOS 26+, WWDC25)

    static func smudge(at url: URL) async throws -> SmudgeResult {
        let image = try ImagePreprocessor.load(url: url, enhance: false)
        let request = DetectLensSmudgeRequest()
        let obs = try await request.perform(on: image)
        return SmudgeResult(confidence: Double(obs.confidence))
    }

    // MARK: --document (macOS 26+, WWDC25)

    static func document(at url: URL) async throws -> DocumentResult? {
        let image = try ImagePreprocessor.load(url: url, enhance: false)
        let request = RecognizeDocumentsRequest()
        let observations = try await request.perform(on: image)
        guard let obs = observations.first else { return nil }
        return makeDocumentResult(from: obs)
    }

    private static func makeDocumentResult(from obs: DocumentObservation) -> DocumentResult {
        let doc = obs.document

        let paragraphs: [DocumentParagraph] = doc.paragraphs.map { p in
            DocumentParagraph(text: p.transcript)
        }

        let lists: [DocumentList] = doc.lists.map { list in
            // Items are Container.Text; access via reflection if needed, else .transcript.
            let items: [String] = list.items.compactMap { item in
                let mirror = Mirror(reflecting: item)
                for c in mirror.children {
                    if c.label == "transcript", let s = c.value as? String { return s }
                }
                // Try direct transcript by reflection-as-Text fallback:
                return reflectTranscript(of: item)
            }
            return DocumentList(items: items)
        }

        let tables: [DocumentTable] = doc.tables.map { table in
            tableResult(table)
        }

        let fullText = paragraphs.map { $0.text }.joined(separator: "\n\n")

        return DocumentResult(
            text: fullText,
            paragraphs: paragraphs,
            lists: lists,
            tables: tables,
            urls: [],
            emails: [],
            phones: []
        )
    }

    /// Recursively walk a value's mirror, returning the first String found
    /// under a label of "transcript", "text", or "content".
    private static func reflectTranscript(of value: Any, depth: Int = 0) -> String {
        if depth > 5 { return "" }
        if let s = value as? String { return s }
        for c in Mirror(reflecting: value).children {
            if let label = c.label,
               (label == "transcript" || label == "text" || label == "content") {
                if let s = c.value as? String { return s }
            }
        }
        // Recurse one level if no direct hit
        for c in Mirror(reflecting: value).children {
            let r = reflectTranscript(of: c.value, depth: depth + 1)
            if !r.isEmpty { return r }
        }
        return ""
    }

    private static func tableResult(_ table: Any) -> DocumentTable {
        let mirror = Mirror(reflecting: table)
        var rowCount = 0
        var colCount = 0
        var cellGrid: [[String]] = []

        // First pass: detect rowCount / columnCount / rows.
        for c in mirror.children {
            switch c.label {
            case "rowCount":
                if let n = c.value as? Int { rowCount = n }
            case "columnCount":
                if let n = c.value as? Int { colCount = n }
            case "rows":
                if let rows = c.value as? [Any] {
                    cellGrid = rows.map { row in
                        let rm = Mirror(reflecting: row)
                        // row may be a struct holding [Cell]
                        var cells: [String] = []
                        for cc in rm.children {
                            if let cellArr = cc.value as? [Any] {
                                for cell in cellArr {
                                    cells.append(reflectTranscript(of: cell))
                                }
                            } else {
                                cells.append(reflectTranscript(of: cc.value))
                            }
                        }
                        return cells
                    }
                    rowCount = cellGrid.count
                    colCount = cellGrid.first?.count ?? 0
                }
            default:
                break
            }
        }
        return DocumentTable(rowCount: rowCount, columnCount: colCount, cells: cellGrid)
    }
}
