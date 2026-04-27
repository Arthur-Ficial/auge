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
    case faceLandmarks
    case faceQuality
    case humans
    case textRectangles
    case rectangles
    case horizon
    case animals
    case animalPose
    case bodyPose
    case handPose
    case saliencyAttention
    case saliencyObjectness
    case contours
    case featurePrint
    case compare
    case aesthetics
    case smudge
    case document
    case all
}

// MARK: - Analyzer

enum Analyzer {
    // MARK: OCR

    /// Perform OCR on an image at the given URL.
    /// - Parameters:
    ///   - languages: BCP-47 hints in priority order (e.g. ["en-US", "de-DE"]). Empty = no hint.
    ///   - enhance: When true, upscale tiny images before OCR (helps small text).
    static func recognizeText(at url: URL, languages: [String] = [], enhance: Bool = false) throws -> [String] {
        let image = try ImagePreprocessor.load(url: url, enhance: enhance)
        return try recognizeText(in: image, languages: languages)
    }

    /// Perform OCR on a CGImage. Multi-language inputs run one pass per language and merge.
    /// Vision's recognizer biases to the first listed language and silently skips other scripts
    /// on multi-script inputs — multi-pass+merge is the only way to catch every script asked for.
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

    // MARK: Classify

    static func classifyImage(at url: URL) throws -> [ClassificationResult] {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNClassifyImageRequest()
        try handler.perform([request])

        guard let observations = request.results else { return [] }
        return observations
            .filter { $0.confidence > 0.01 }
            .sorted { $0.confidence > $1.confidence }
            .prefix(10)
            .map { ClassificationResult(label: $0.identifier, confidence: Double($0.confidence)) }
    }

    // MARK: Barcodes

    static func detectBarcodes(at url: URL) throws -> [BarcodeResult] {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNDetectBarcodesRequest()
        try handler.perform([request])

        guard let observations = request.results else { return [] }
        return observations.compactMap { obs in
            guard let payload = obs.payloadStringValue else { return nil }
            let symbology = obs.symbology.rawValue
                .replacingOccurrences(of: "VNBarcodeSymbology", with: "")
            return BarcodeResult(payload: payload, symbology: symbology)
        }
    }

    // MARK: Faces (rectangles)

    static func detectFaces(at url: URL) throws -> [FaceResult] {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNDetectFaceRectanglesRequest()
        try handler.perform([request])

        guard let observations = request.results else { return [] }
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

    // MARK: Face landmarks (76 points + roll/yaw/pitch)

    static func detectFaceLandmarks(at url: URL) throws -> [FaceLandmarksFace] {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNDetectFaceLandmarksRequest()
        try handler.perform([request])

        guard let observations = request.results else { return [] }
        return observations.map { obs in
            let box = obs.boundingBox
            var regions: [String: [PointResult]] = [:]

            if let lm = obs.landmarks {
                func add(_ name: String, _ region: VNFaceLandmarkRegion2D?) {
                    guard let r = region else { return }
                    regions[name] = r.normalizedPoints.map {
                        PointResult(x: Double($0.x), y: Double($0.y))
                    }
                }
                add("faceContour", lm.faceContour)
                add("leftEye", lm.leftEye)
                add("rightEye", lm.rightEye)
                add("leftEyebrow", lm.leftEyebrow)
                add("rightEyebrow", lm.rightEyebrow)
                add("nose", lm.nose)
                add("noseCrest", lm.noseCrest)
                add("medianLine", lm.medianLine)
                add("outerLips", lm.outerLips)
                add("innerLips", lm.innerLips)
                add("leftPupil", lm.leftPupil)
                add("rightPupil", lm.rightPupil)
            }

            return FaceLandmarksFace(
                x: Double(box.origin.x),
                y: Double(box.origin.y),
                width: Double(box.size.width),
                height: Double(box.size.height),
                roll: obs.roll.map { Double(truncating: $0) },
                yaw: obs.yaw.map { Double(truncating: $0) },
                pitch: obs.pitch.map { Double(truncating: $0) },
                landmarks: regions
            )
        }
    }

    // MARK: Face capture quality

    static func detectFaceQuality(at url: URL) throws -> [FaceQualityResult] {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNDetectFaceCaptureQualityRequest()
        try handler.perform([request])

        guard let observations = request.results else { return [] }
        return observations.map { obs in
            let box = obs.boundingBox
            return FaceQualityResult(
                x: Double(box.origin.x),
                y: Double(box.origin.y),
                width: Double(box.size.width),
                height: Double(box.size.height),
                quality: Double(obs.faceCaptureQuality ?? 0)
            )
        }
    }

    // MARK: Humans (rectangles)

    static func detectHumans(at url: URL, upperBodyOnly: Bool = false) throws -> [HumanResult] {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNDetectHumanRectanglesRequest()
        request.upperBodyOnly = upperBodyOnly
        try handler.perform([request])

        guard let observations = request.results else { return [] }
        return observations.map { obs in
            let box = obs.boundingBox
            return HumanResult(
                x: Double(box.origin.x),
                y: Double(box.origin.y),
                width: Double(box.size.width),
                height: Double(box.size.height),
                confidence: Double(obs.confidence),
                upperBodyOnly: upperBodyOnly
            )
        }
    }

    // MARK: Text rectangles

    static func detectTextRectangles(at url: URL) throws -> [TextRectangleResult] {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNDetectTextRectanglesRequest()
        try handler.perform([request])

        guard let observations = request.results else { return [] }
        return observations.map { obs in
            let box = obs.boundingBox
            return TextRectangleResult(
                x: Double(box.origin.x),
                y: Double(box.origin.y),
                width: Double(box.size.width),
                height: Double(box.size.height),
                confidence: Double(obs.confidence)
            )
        }
    }

    // MARK: Rectangles (quadrilaterals)

    static func detectRectangles(at url: URL) throws -> [RectangleResult] {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 16
        try handler.perform([request])

        guard let observations = request.results else { return [] }
        return observations.map { obs in
            RectangleResult(
                topLeft: PointResult(x: Double(obs.topLeft.x), y: Double(obs.topLeft.y)),
                topRight: PointResult(x: Double(obs.topRight.x), y: Double(obs.topRight.y)),
                bottomLeft: PointResult(x: Double(obs.bottomLeft.x), y: Double(obs.bottomLeft.y)),
                bottomRight: PointResult(x: Double(obs.bottomRight.x), y: Double(obs.bottomRight.y)),
                confidence: Double(obs.confidence)
            )
        }
    }

    // MARK: Horizon

    static func detectHorizon(at url: URL) throws -> HorizonResult? {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNDetectHorizonRequest()
        try handler.perform([request])

        guard let obs = request.results?.first else { return nil }
        return HorizonResult(angleRadians: Double(obs.angle))
    }

    // MARK: Animals (cats / dogs)

    static func recognizeAnimals(at url: URL) throws -> [AnimalResult] {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNRecognizeAnimalsRequest()
        try handler.perform([request])

        guard let observations = request.results else { return [] }
        return observations.flatMap { obs -> [AnimalResult] in
            let box = obs.boundingBox
            return obs.labels.map { label in
                AnimalResult(
                    label: label.identifier,
                    confidence: Double(label.confidence),
                    x: Double(box.origin.x),
                    y: Double(box.origin.y),
                    width: Double(box.size.width),
                    height: Double(box.size.height)
                )
            }
        }
    }

    // MARK: Animal body pose

    static func detectAnimalPose(at url: URL) throws -> [AnimalPoseResult] {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNDetectAnimalBodyPoseRequest()
        try handler.perform([request])

        guard let observations = request.results else { return [] }
        return observations.map { obs in
            let points = (try? obs.recognizedPoints(.all)) ?? [:]
            let joints: [PoseJoint] = points.map { (name, point) in
                PoseJoint(
                    name: name.rawValue.rawValue,
                    x: Double(point.location.x),
                    y: Double(point.location.y),
                    confidence: Double(point.confidence)
                )
            }
            return AnimalPoseResult(joints: joints.sorted { $0.name < $1.name })
        }
    }

    // MARK: Body pose

    static func detectBodyPose(at url: URL) throws -> [BodyPoseResult] {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNDetectHumanBodyPoseRequest()
        try handler.perform([request])

        guard let observations = request.results else { return [] }
        return observations.map { obs in
            let points = (try? obs.recognizedPoints(.all)) ?? [:]
            let joints: [PoseJoint] = points.map { (name, point) in
                PoseJoint(
                    name: name.rawValue.rawValue,
                    x: Double(point.location.x),
                    y: Double(point.location.y),
                    confidence: Double(point.confidence)
                )
            }
            return BodyPoseResult(joints: joints.sorted { $0.name < $1.name })
        }
    }

    // MARK: Hand pose

    static func detectHandPose(at url: URL, maximumHands: Int = 2) throws -> [HandPoseResult] {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = maximumHands
        try handler.perform([request])

        guard let observations = request.results else { return [] }
        return observations.map { obs in
            let chiralityName: String
            switch obs.chirality {
            case .left:    chiralityName = "left"
            case .right:   chiralityName = "right"
            case .unknown: chiralityName = "unknown"
            @unknown default: chiralityName = "unknown"
            }
            let points = (try? obs.recognizedPoints(.all)) ?? [:]
            let joints: [PoseJoint] = points.map { (name, point) in
                PoseJoint(
                    name: name.rawValue.rawValue,
                    x: Double(point.location.x),
                    y: Double(point.location.y),
                    confidence: Double(point.confidence)
                )
            }
            return HandPoseResult(chirality: chiralityName, joints: joints.sorted { $0.name < $1.name })
        }
    }

    // MARK: Saliency (attention + objectness)

    /// Returns salient regions as bounding boxes only. The pixel heatmap is intentionally
    /// not emitted — auge sees, it does not paint.
    static func attentionSaliency(at url: URL) throws -> [SaliencyRegion] {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        try handler.perform([request])

        guard let obs = request.results?.first else { return [] }
        let objects = obs.salientObjects ?? []
        return objects.map { rect in
            let b = rect.boundingBox
            return SaliencyRegion(
                x: Double(b.origin.x),
                y: Double(b.origin.y),
                width: Double(b.size.width),
                height: Double(b.size.height),
                confidence: Double(rect.confidence)
            )
        }
    }

    static func objectnessSaliency(at url: URL) throws -> [SaliencyRegion] {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNGenerateObjectnessBasedSaliencyImageRequest()
        try handler.perform([request])

        guard let obs = request.results?.first else { return [] }
        let objects = obs.salientObjects ?? []
        return objects.map { rect in
            let b = rect.boundingBox
            return SaliencyRegion(
                x: Double(b.origin.x),
                y: Double(b.origin.y),
                width: Double(b.size.width),
                height: Double(b.size.height),
                confidence: Double(rect.confidence)
            )
        }
    }

    // MARK: Contours

    /// Detect contours. Returns the count + a sample of top-level contours' point lists.
    /// We emit normalized vector points, never raster output.
    static func detectContours(at url: URL, maxPaths: Int = 32) throws -> ContoursResult {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNDetectContoursRequest()
        try handler.perform([request])

        guard let obs = request.results?.first else {
            return ContoursResult(contourCount: 0, topLevelCount: 0, paths: [])
        }
        var paths: [ContourPath] = []
        let topLevel = obs.topLevelContours
        for i in 0..<min(topLevel.count, maxPaths) {
            let contour = topLevel[i]
            let points = contour.normalizedPoints.map {
                PointResult(x: Double($0.x), y: Double($0.y))
            }
            paths.append(ContourPath(points: points))
        }
        return ContoursResult(
            contourCount: obs.contourCount,
            topLevelCount: obs.topLevelContourCount,
            paths: paths
        )
    }

    // MARK: Image feature print (embedding)

    static func featurePrint(at url: URL) throws -> (FeaturePrintResult, VNFeaturePrintObservation) {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNGenerateImageFeaturePrintRequest()
        try handler.perform([request])

        guard let obs = request.results?.first else {
            throw AugeError.noResults
        }
        let count = Int(obs.elementCount)
        let elementType: String
        switch obs.elementType {
        case .float:   elementType = "float"
        case .double:  elementType = "double"
        case .unknown: elementType = "unknown"
        @unknown default: elementType = "unknown"
        }

        let bytes = obs.data
        var vector: [Double] = []
        vector.reserveCapacity(count)
        bytes.withUnsafeBytes { raw in
            switch obs.elementType {
            case .float:
                let buf = raw.bindMemory(to: Float.self)
                for i in 0..<count { vector.append(Double(buf[i])) }
            case .double:
                let buf = raw.bindMemory(to: Double.self)
                for i in 0..<count { vector.append(buf[i]) }
            case .unknown:
                break
            @unknown default:
                break
            }
        }

        return (FeaturePrintResult(dimension: count, elementType: elementType, vector: vector), obs)
    }

    /// Compare two images via Vision's feature-print distance. Lower = more similar.
    static func compareImages(_ a: URL, _ b: URL) throws -> CompareResult {
        let (_, obsA) = try featurePrint(at: a)
        let (_, obsB) = try featurePrint(at: b)
        var distance: Float = 0
        try obsA.computeDistance(&distance, to: obsB)
        return CompareResult(fileA: a.path, fileB: b.path, distance: Double(distance))
    }
}
