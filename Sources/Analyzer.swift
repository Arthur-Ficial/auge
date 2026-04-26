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
    case all
}

// MARK: - Analyzer

enum Analyzer {
    /// Perform OCR on an image at the given URL.
    /// - Parameters:
    ///   - languages: BCP-47 hints in priority order (e.g. ["en-US", "de-DE"]). Empty = no hint.
    ///   - enhance: When true, upscale tiny images before OCR (helps small text).
    static func recognizeText(at url: URL, languages: [String] = [], enhance: Bool = false) throws -> [String] {
        // Apply preprocessing only when enhance is on or downscale is needed.
        // For the common case (image already a reasonable size, no enhance), this is a no-op
        // because ImagePreprocessor.apply returns the original CGImage unchanged.
        let image = try ImagePreprocessor.load(url: url, enhance: enhance)
        return try recognizeText(in: image, languages: languages)
    }

    /// Perform OCR on a CGImage (used after rasterizing PDF pages).
    /// When `languages.count > 1`, runs Vision once per language and merges unique
    /// lines. Vision's recognizer biases to the first listed language and silently
    /// skips other scripts on multi-script inputs (e.g. a sign with Chinese +
    /// Portuguese + English) — multi-pass+merge is the only way to actually catch
    /// every script the caller asked for.
    static func recognizeText(in image: CGImage, languages: [String] = []) throws -> [String] {
        if languages.count <= 1 {
            return try recognizeTextSinglePass(in: image, languages: languages)
        }
        var runs: [[String]] = []
        runs.reserveCapacity(languages.count)
        for lang in languages {
            let lines = try recognizeTextSinglePass(in: image, languages: [lang])
            runs.append(lines)
        }
        return LineMerger.merge(runs)
    }

    private static func recognizeTextSinglePass(in image: CGImage, languages: [String]) throws -> [String] {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        if !languages.isEmpty {
            request.recognitionLanguages = languages
        }
        try handler.perform([request])

        guard let observations = request.results else {
            return []
        }
        return observations.compactMap { $0.topCandidates(1).first?.string }
    }

    /// Process a PDF: extract embedded text where available, OCR rasterized pages otherwise.
    /// Returns a flat list of lines across all pages, with a blank line separating pages.
    static func recognizeTextInPDF(
        at url: URL,
        config: PDFProcessor.Configuration,
        languages: [String] = [],
        enhance: Bool = false
    ) throws -> [String] {
        let pages = try PDFProcessor.process(url: url, config: config)
        var allLines: [String] = []
        for (index, page) in pages.enumerated() {
            if index > 0 { allLines.append("") }
            switch page {
            case .embeddedText(let text):
                let lines = text
                    .split(separator: "\n", omittingEmptySubsequences: false)
                    .map(String.init)
                allLines.append(contentsOf: lines)
            case .rasterImage(let image):
                let prepared = try ImagePreprocessor.apply(image, enhance: enhance)
                let lines = try recognizeText(in: prepared, languages: languages)
                allLines.append(contentsOf: lines)
            }
        }
        return allLines
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
