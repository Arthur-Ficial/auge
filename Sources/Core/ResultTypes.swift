import Foundation

// MARK: - Existing result types

public struct ClassificationResult: Codable, Sendable {
    public let label: String
    public let confidence: Double
    public init(label: String, confidence: Double) {
        self.label = label
        self.confidence = confidence
    }
}

public struct BarcodeResult: Codable, Sendable {
    public let payload: String
    public let symbology: String
    public init(payload: String, symbology: String) {
        self.payload = payload
        self.symbology = symbology
    }
}

public struct FaceResult: Codable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

// MARK: - Shared building blocks

public struct PointResult: Codable, Sendable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct BoundingBox: Codable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

// MARK: - v1.2+ result types

public struct HorizonResult: Codable, Sendable {
    public let angleRadians: Double
    public let angleDegrees: Double
    public init(angleRadians: Double) {
        self.angleRadians = angleRadians
        self.angleDegrees = angleRadians * 180.0 / .pi
    }
}

public struct RectangleResult: Codable, Sendable {
    public let topLeft: PointResult
    public let topRight: PointResult
    public let bottomLeft: PointResult
    public let bottomRight: PointResult
    public let confidence: Double
    public init(topLeft: PointResult, topRight: PointResult, bottomLeft: PointResult, bottomRight: PointResult, confidence: Double) {
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
        self.confidence = confidence
    }
}

public struct HumanResult: Codable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public let confidence: Double
    public let upperBodyOnly: Bool
    public init(x: Double, y: Double, width: Double, height: Double, confidence: Double, upperBodyOnly: Bool) {
        self.x = x; self.y = y; self.width = width; self.height = height
        self.confidence = confidence
        self.upperBodyOnly = upperBodyOnly
    }
}

public struct TextRectangleResult: Codable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public let confidence: Double
    public init(x: Double, y: Double, width: Double, height: Double, confidence: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
        self.confidence = confidence
    }
}

public struct AnimalResult: Codable, Sendable {
    public let label: String
    public let confidence: Double
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public init(label: String, confidence: Double, x: Double, y: Double, width: Double, height: Double) {
        self.label = label
        self.confidence = confidence
        self.x = x; self.y = y; self.width = width; self.height = height
    }
}

public struct SaliencyRegion: Codable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public let confidence: Double
    public init(x: Double, y: Double, width: Double, height: Double, confidence: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
        self.confidence = confidence
    }
}

public struct ContourPath: Codable, Sendable {
    public let pointCount: Int
    public let points: [PointResult]
    public init(points: [PointResult]) {
        self.points = points
        self.pointCount = points.count
    }
}

public struct ContoursResult: Codable, Sendable {
    public let contourCount: Int
    public let topLevelCount: Int
    public let paths: [ContourPath]
    public init(contourCount: Int, topLevelCount: Int, paths: [ContourPath]) {
        self.contourCount = contourCount
        self.topLevelCount = topLevelCount
        self.paths = paths
    }
}

public struct FaceLandmarksFace: Codable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public let roll: Double?
    public let yaw: Double?
    public let pitch: Double?
    public let landmarks: [String: [PointResult]]
    public init(x: Double, y: Double, width: Double, height: Double,
                roll: Double?, yaw: Double?, pitch: Double?,
                landmarks: [String: [PointResult]]) {
        self.x = x; self.y = y; self.width = width; self.height = height
        self.roll = roll; self.yaw = yaw; self.pitch = pitch
        self.landmarks = landmarks
    }
}

public struct FaceQualityResult: Codable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public let quality: Double
    public init(x: Double, y: Double, width: Double, height: Double, quality: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
        self.quality = quality
    }
}

public struct PoseJoint: Codable, Sendable {
    public let name: String
    public let x: Double
    public let y: Double
    public let confidence: Double
    public init(name: String, x: Double, y: Double, confidence: Double) {
        self.name = name; self.x = x; self.y = y
        self.confidence = confidence
    }
}

public struct BodyPoseResult: Codable, Sendable {
    public let joints: [PoseJoint]
    public init(joints: [PoseJoint]) { self.joints = joints }
}

public struct HandPoseResult: Codable, Sendable {
    public let chirality: String
    public let joints: [PoseJoint]
    public init(chirality: String, joints: [PoseJoint]) {
        self.chirality = chirality
        self.joints = joints
    }
}

public struct AnimalPoseResult: Codable, Sendable {
    public let joints: [PoseJoint]
    public init(joints: [PoseJoint]) { self.joints = joints }
}

public struct FeaturePrintResult: Codable, Sendable {
    public let dimension: Int
    public let elementType: String
    public let vector: [Double]
    public init(dimension: Int, elementType: String, vector: [Double]) {
        self.dimension = dimension
        self.elementType = elementType
        self.vector = vector
    }
}

public struct CompareResult: Codable, Sendable {
    public let fileA: String
    public let fileB: String
    public let distance: Double
    public init(fileA: String, fileB: String, distance: Double) {
        self.fileA = fileA; self.fileB = fileB
        self.distance = distance
    }
}

public struct AestheticsResult: Codable, Sendable {
    public let overall: Double
    public let isUtility: Bool
    public init(overall: Double, isUtility: Bool) {
        self.overall = overall
        self.isUtility = isUtility
    }
}

public struct SmudgeResult: Codable, Sendable {
    public let confidence: Double
    public init(confidence: Double) { self.confidence = confidence }
}

public struct DocumentParagraph: Codable, Sendable {
    public let text: String
    public init(text: String) { self.text = text }
}

public struct DocumentList: Codable, Sendable {
    public let items: [String]
    public init(items: [String]) { self.items = items }
}

public struct DocumentTable: Codable, Sendable {
    public let rowCount: Int
    public let columnCount: Int
    public let cells: [[String]]
    public init(rowCount: Int, columnCount: Int, cells: [[String]]) {
        self.rowCount = rowCount
        self.columnCount = columnCount
        self.cells = cells
    }
}

public struct DocumentResult: Codable, Sendable {
    public let text: String
    public let paragraphs: [DocumentParagraph]
    public let lists: [DocumentList]
    public let tables: [DocumentTable]
    public let urls: [String]
    public let emails: [String]
    public let phones: [String]
    public init(text: String,
                paragraphs: [DocumentParagraph],
                lists: [DocumentList],
                tables: [DocumentTable],
                urls: [String],
                emails: [String],
                phones: [String]) {
        self.text = text
        self.paragraphs = paragraphs
        self.lists = lists
        self.tables = tables
        self.urls = urls
        self.emails = emails
        self.phones = phones
    }
}
