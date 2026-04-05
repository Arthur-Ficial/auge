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

    // MARK: - PDF detection

    private static func isPDF(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "pdf"
    }

    // MARK: - Handler creation

    /// Create VNImageRequestHandlers for a given URL.
    /// For PDFs, renders each page to a CGImage. For images, returns a single handler.
    private static func makeHandlers(for url: URL) throws -> [VNImageRequestHandler] {
        if isPDF(url) {
            let images = try PDFRenderer.renderPages(at: url)
            return images.map { VNImageRequestHandler(cgImage: $0, options: [:]) }
        } else {
            return [VNImageRequestHandler(url: url, options: [:])]
        }
    }

    // MARK: - OCR

    /// Perform OCR on an image at the given URL.
    static func recognizeText(at url: URL) throws -> [String] {
        let handlers = try makeHandlers(for: url)
        var allLines: [String] = []

        for handler in handlers {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            try handler.perform([request])

            guard let observations = request.results else { continue }
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            allLines.append(contentsOf: lines)
        }
        return allLines
    }

    // MARK: - Classification

    /// Classify an image at the given URL.
    static func classifyImage(at url: URL) throws -> [ClassificationResult] {
        let handlers = try makeHandlers(for: url)
        var allResults: [ClassificationResult] = []

        for handler in handlers {
            let request = VNClassifyImageRequest()
            try handler.perform([request])

            guard let observations = request.results else { continue }
            let results = observations
                .filter { $0.confidence > 0.01 }
                .sorted { $0.confidence > $1.confidence }
                .prefix(10)
                .map { ClassificationResult(label: $0.identifier, confidence: Double($0.confidence)) }
            allResults.append(contentsOf: results)
        }
        return allResults
    }

    // MARK: - Barcodes

    /// Detect barcodes in an image at the given URL.
    static func detectBarcodes(at url: URL) throws -> [BarcodeResult] {
        let handlers = try makeHandlers(for: url)
        var allResults: [BarcodeResult] = []

        for handler in handlers {
            let request = VNDetectBarcodesRequest()
            try handler.perform([request])

            guard let observations = request.results else { continue }
            let results = observations.compactMap { obs in
                guard let payload = obs.payloadStringValue else { return nil as BarcodeResult? }
                let symbology = obs.symbology.rawValue
                    .replacingOccurrences(of: "VNBarcodeSymbology", with: "")
                return BarcodeResult(payload: payload, symbology: symbology)
            }
            allResults.append(contentsOf: results)
        }
        return allResults
    }

    // MARK: - Faces

    /// Detect faces in an image at the given URL.
    static func detectFaces(at url: URL) throws -> [FaceResult] {
        let handlers = try makeHandlers(for: url)
        var allResults: [FaceResult] = []

        for handler in handlers {
            let request = VNDetectFaceRectanglesRequest()
            try handler.perform([request])

            guard let observations = request.results else { continue }
            let results = observations.map { obs in
                let box = obs.boundingBox
                return FaceResult(
                    x: Double(box.origin.x),
                    y: Double(box.origin.y),
                    width: Double(box.size.width),
                    height: Double(box.size.height)
                )
            }
            allResults.append(contentsOf: results)
        }
        return allResults
    }
}
