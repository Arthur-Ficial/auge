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
        let schema: String
        enum CodingKeys: String, CodingKey {
            case onDevice = "on_device"
            case version
            case schema
        }
    }
}

// MARK: - Result Payloads

enum ResultPayload: Encodable {
    case ocr(OCRPayload)
    case classification(ClassificationPayload)
    case barcodes(BarcodesPayload)
    case faces(FacesPayload)
    case faceLandmarks(FaceLandmarksPayload)
    case faceQuality(FaceQualityPayload)
    case humans(HumansPayload)
    case textRectangles(TextRectanglesPayload)
    case rectangles(RectanglesPayload)
    case horizon(HorizonPayload)
    case animals(AnimalsPayload)
    case animalPose(AnimalPosePayload)
    case bodyPose(BodyPosePayload)
    case handPose(HandPosePayload)
    case saliencyAttention(SaliencyPayload)
    case saliencyObjectness(SaliencyPayload)
    case contours(ContoursPayload)
    case featurePrint(FeaturePrintPayload)
    case compare(ComparePayload)
    case aesthetics(AestheticsPayload)
    case smudge(SmudgePayload)
    case document(DocumentPayload)
    case all(AllPayload)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .ocr(let p): try container.encode(p)
        case .classification(let p): try container.encode(p)
        case .barcodes(let p): try container.encode(p)
        case .faces(let p): try container.encode(p)
        case .faceLandmarks(let p): try container.encode(p)
        case .faceQuality(let p): try container.encode(p)
        case .humans(let p): try container.encode(p)
        case .textRectangles(let p): try container.encode(p)
        case .rectangles(let p): try container.encode(p)
        case .horizon(let p): try container.encode(p)
        case .animals(let p): try container.encode(p)
        case .animalPose(let p): try container.encode(p)
        case .bodyPose(let p): try container.encode(p)
        case .handPose(let p): try container.encode(p)
        case .saliencyAttention(let p): try container.encode(p)
        case .saliencyObjectness(let p): try container.encode(p)
        case .contours(let p): try container.encode(p)
        case .featurePrint(let p): try container.encode(p)
        case .compare(let p): try container.encode(p)
        case .aesthetics(let p): try container.encode(p)
        case .smudge(let p): try container.encode(p)
        case .document(let p): try container.encode(p)
        case .all(let p): try container.encode(p)
        }
    }
}

struct OCRPayload: Encodable {
    let text: String
    let lines: [String]
    let lineDetails: [OCRLineDetail]?

    init(text: String, lines: [String], lineDetails: [OCRLineDetail]? = nil) {
        self.text = text
        self.lines = lines
        self.lineDetails = lineDetails
    }
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

struct FaceLandmarksPayload: Encodable {
    let count: Int
    let faces: [FaceLandmarksFace]
}

struct FaceQualityPayload: Encodable {
    let count: Int
    let faces: [FaceQualityResult]
}

struct HumansPayload: Encodable {
    let count: Int
    let humans: [HumanResult]
}

struct TextRectanglesPayload: Encodable {
    let count: Int
    let rectangles: [TextRectangleResult]
}

struct RectanglesPayload: Encodable {
    let count: Int
    let rectangles: [RectangleResult]
}

struct HorizonPayload: Encodable {
    let horizon: HorizonResult?
}

struct AnimalsPayload: Encodable {
    let count: Int
    let animals: [AnimalResult]
}

struct AnimalPosePayload: Encodable {
    let count: Int
    let animals: [AnimalPoseResult]
}

struct BodyPosePayload: Encodable {
    let count: Int
    let bodies: [BodyPoseResult]
}

struct HandPosePayload: Encodable {
    let count: Int
    let hands: [HandPoseResult]
}

struct SaliencyPayload: Encodable {
    let count: Int
    let regions: [SaliencyRegion]
}

struct ContoursPayload: Encodable {
    let contours: ContoursResult
}

struct FeaturePrintPayload: Encodable {
    let featurePrint: FeaturePrintResult
}

struct ComparePayload: Encodable {
    let compare: CompareResult
}

struct AestheticsPayload: Encodable {
    let aesthetics: AestheticsResult
}

struct SmudgePayload: Encodable {
    let smudge: SmudgeResult
}

struct DocumentPayload: Encodable {
    let document: DocumentResult?
}

/// Combined payload for `--all` mode: every analysis bundled in one response.
struct AllPayload: Encodable {
    let ocr: OCRPayload?
    let classify: ClassificationPayload?
    let barcodes: BarcodesPayload?
    let faces: FacesPayload?
}
