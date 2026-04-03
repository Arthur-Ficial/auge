// ============================================================================
// Analyzer.swift — Vision framework integration
// Part of auge — Apple Vision from the command line
// ============================================================================

import Foundation
import Vision
import AugeCore

// MARK: - Analysis Mode

enum AnalysisMode: String, Sendable {
    case ocr
    case classify
    case barcode
    case faces
}

// MARK: - Analyzer

enum Analyzer {
    /// Perform OCR on an image at the given URL.
    static func recognizeText(at url: URL) throws -> [String] {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try handler.perform([request])

        guard let observations = request.results else {
            return []
        }
        return observations.compactMap { $0.topCandidates(1).first?.string }
    }

    /// Classify an image at the given URL.
    static func classifyImage(at url: URL) throws -> [ClassificationResult] {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNClassifyImageRequest()
        try handler.perform([request])

        guard let observations = request.results else {
            return []
        }
        return observations
            .filter { $0.confidence > 0.01 }
            .sorted { $0.confidence > $1.confidence }
            .prefix(10)
            .map { ClassificationResult(label: $0.identifier, confidence: Double($0.confidence)) }
    }

    /// Detect barcodes in an image at the given URL.
    static func detectBarcodes(at url: URL) throws -> [BarcodeResult] {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNDetectBarcodesRequest()
        try handler.perform([request])

        guard let observations = request.results else {
            return []
        }
        return observations.compactMap { obs in
            guard let payload = obs.payloadStringValue else { return nil }
            let symbology = obs.symbology.rawValue
                .replacingOccurrences(of: "VNBarcodeSymbology", with: "")
            return BarcodeResult(payload: payload, symbology: symbology)
        }
    }

    /// Detect faces in an image at the given URL.
    static func detectFaces(at url: URL) throws -> [FaceResult] {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNDetectFaceRectanglesRequest()
        try handler.perform([request])

        guard let observations = request.results else {
            return []
        }
        return observations.map { obs in
            let box = obs.boundingBox
            return FaceResult(
                x: Double(box.origin.x),
                y: Double(box.origin.y),
                width: Double(box.size.width),
                height: Double(box.size.height)
            )
        }
    }
}
