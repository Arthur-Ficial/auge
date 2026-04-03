import Foundation

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
