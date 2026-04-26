// ============================================================================
// Models.swift — Data types for CLI response output
// Part of auge — Apple Vision from the command line
// ============================================================================

import Foundation
import AugeCore

// MARK: - CLI Response Types

struct AugeResponse: Encodable {
    let mode: String
    let file: String
    let results: ResultPayload
    let metadata: Metadata

    struct Metadata: Encodable {
        let onDevice: Bool
        let version: String
        enum CodingKeys: String, CodingKey { case onDevice = "on_device"; case version }
    }
}

// MARK: - Result Payloads

enum ResultPayload: Encodable {
    case ocr(OCRPayload)
    case classification(ClassificationPayload)
    case barcodes(BarcodesPayload)
    case faces(FacesPayload)
    case all(AllPayload)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .ocr(let p): try container.encode(p)
        case .classification(let p): try container.encode(p)
        case .barcodes(let p): try container.encode(p)
        case .faces(let p): try container.encode(p)
        case .all(let p): try container.encode(p)
        }
    }
}

struct OCRPayload: Encodable {
    let text: String
    let lines: [String]
}

struct ClassificationPayload: Encodable {
    let classifications: [ClassificationResult]
}

struct BarcodesPayload: Encodable {
    let barcodes: [BarcodeResult]
}

struct FacesPayload: Encodable {
    let count: Int
    let faces: [FaceResult]
}

/// Combined payload for `--all` mode: every analysis bundled in one response.
struct AllPayload: Encodable {
    let ocr: OCRPayload?
    let classify: ClassificationPayload?
    let barcodes: BarcodesPayload?
    let faces: FacesPayload?
}
