// ============================================================================
// Analyzer.swift — Vision framework integration
// Part of auge — Apple Vision from the command line
// ============================================================================

import Foundation
import Vision
import CoreVideo
import CoreML
import CoreImage
import AVFoundation
import AugeCore

// MARK: - Analysis Mode

package enum AnalysisMode: String, Sendable {
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
    case subject
    case personsMask
    case model
    case motion
    case align
    case track
    case trajectories
    case video
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

    // MARK: OCR — detailed (per-line confidence + optional boxes + tunable knobs)

    struct OCROptions: Sendable {
        var languages: [String] = []
        var autoDetectLanguage: Bool = false
        var customWords: [String] = []
        var useLanguageCorrection: Bool = true
        var fast: Bool = false
        var withBoxes: Bool = false
        var enhance: Bool = false
    }

    static func recognizeTextDetailed(at url: URL, options: OCROptions) throws -> [OCRLineDetail] {
        let image = try ImagePreprocessor.load(url: url, enhance: options.enhance)
        return try recognizeTextDetailed(in: image, options: options)
    }

    static func recognizeTextDetailed(in image: CGImage, options: OCROptions) throws -> [OCRLineDetail] {
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = options.fast ? .fast : .accurate
        request.usesLanguageCorrection = options.useLanguageCorrection
        if !options.languages.isEmpty {
            request.recognitionLanguages = options.languages
        }
        if options.autoDetectLanguage {
            request.automaticallyDetectsLanguage = true
        }
        if !options.customWords.isEmpty {
            request.customWords = options.customWords
        }
        try handler.perform([request])

        guard let observations = request.results else { return [] }

        return observations.compactMap { obs -> OCRLineDetail? in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            let confidence = Double(candidate.confidence)
            let box = obs.boundingBox
            if options.withBoxes {
                return OCRLineDetail(
                    text: candidate.string,
                    confidence: confidence,
                    x: Double(box.origin.x),
                    y: Double(box.origin.y),
                    width: Double(box.size.width),
                    height: Double(box.size.height)
                )
            } else {
                return OCRLineDetail(text: candidate.string, confidence: confidence)
            }
        }
    }

    /// PDF-aware variant returning detailed line records across pages.
    static func recognizeTextDetailedInPDF(
        at url: URL,
        config: PDFProcessor.Configuration,
        options: OCROptions
    ) throws -> [OCRLineDetail] {
        let pages = try PDFProcessor.process(url: url, config: config)
        var all: [OCRLineDetail] = []
        for (index, page) in pages.enumerated() {
            if index > 0 {
                // Page separator marker: empty-text record with confidence 0
                all.append(OCRLineDetail(text: "", confidence: 0))
            }
            switch page {
            case .embeddedText(let text):
                let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
                for l in lines { all.append(OCRLineDetail(text: l, confidence: 1.0)) }
            case .rasterImage(let image):
                let prepared = try ImagePreprocessor.apply(image, enhance: options.enhance)
                let details = try recognizeTextDetailed(in: prepared, options: options)
                all.append(contentsOf: details)
            }
        }
        return all
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
        // Return the full sorted list — the CLI layer is the single place that
        // applies --min-confidence and --top, so neither is silently clamped here.
        return observations
            .sorted { $0.confidence > $1.confidence }
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
                // Vision returns landmark points normalized to the FACE bounding box, not
                // the image. Map them into image-normalized coords (bottom-left origin) so
                // they share one coordinate space with every other bbox/point auge emits.
                func add(_ name: String, _ region: VNFaceLandmarkRegion2D?) {
                    guard let r = region else { return }
                    regions[name] = r.normalizedPoints.map {
                        PointResult(
                            x: Double(box.origin.x) + Double($0.x) * Double(box.size.width),
                            y: Double(box.origin.y) + Double($0.y) * Double(box.size.height)
                        )
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
                // Clamp to the actual buffer length so a short/padded buffer can never over-read.
                let safe = min(count, raw.count / MemoryLayout<Float>.stride)
                let buf = raw.bindMemory(to: Float.self)
                for i in 0..<safe { vector.append(Double(buf[i])) }
            case .double:
                let safe = min(count, raw.count / MemoryLayout<Double>.stride)
                let buf = raw.bindMemory(to: Double.self)
                for i in 0..<safe { vector.append(buf[i]) }
            case .unknown:
                break
            @unknown default:
                break
            }
        }

        return (FeaturePrintResult(dimension: count, elementType: elementType, vector: vector), obs)
    }

    // MARK: Subject lifting (foreground instance mask)

    /// Each Vision observation gives one foreground instance plus its bbox in
    /// image-pixel coordinates. We map to normalized Vision coords (bottom-left
    /// origin), and compute coverage by rendering the per-instance mask to a
    /// byte buffer and summing.
    static func detectSubjectInstances(at url: URL) throws -> SubjectResult {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])

        guard let observation = request.results?.first else {
            return SubjectResult(coverage: 0, instances: [])
        }

        var instances: [SubjectInstance] = []
        var totalCoverage = 0.0
        let allInstances = observation.allInstances
        for (i, instance) in allInstances.enumerated() {
            do {
                let buffer = try observation.generateMask(forInstances: [instance])
                let (w, h, pixels) = pixelBufferToBytes(buffer)
                guard w > 0, h > 0, !pixels.isEmpty else { continue }
                let cov = MaskAnalysis.coverage(width: w, height: h, pixels: pixels)
                totalCoverage += cov
                guard let bb = MaskAnalysis.boundingBox(width: w, height: h, pixels: pixels) else {
                    continue
                }
                instances.append(SubjectInstance(
                    index: i + 1,
                    area: cov,
                    x: bb.x, y: bb.y, width: bb.width, height: bb.height
                ))
            } catch {
                continue
            }
        }
        return SubjectResult(coverage: min(totalCoverage, 1.0), instances: instances)
    }

    // MARK: Persons mask (semantic segmentation of all people)

    /// `VNGeneratePersonSegmentationRequest` returns a single mask spanning every
    /// person in the frame. We compute coverage, then split that mask into
    /// connected components so multiple separated people appear as separate
    /// regions in the JSON.
    static func detectPersonsMask(at url: URL) throws -> PersonsMaskResult {
        let handler = VNImageRequestHandler(url: url, options: [:])
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        try handler.perform([request])

        guard let observation = request.results?.first else {
            return PersonsMaskResult(coverage: 0, instances: [])
        }

        let buffer = observation.pixelBuffer
        let (w, h, pixels) = pixelBufferToBytes(buffer)
        guard w > 0, h > 0, !pixels.isEmpty else {
            return PersonsMaskResult(coverage: 0, instances: [])
        }

        let coverage = MaskAnalysis.coverage(width: w, height: h, pixels: pixels)
        // 0.4% of the image minimum keeps stray pixels from showing up as people.
        let minPixels = max(1, (w * h) / 250)
        let components = MaskAnalysis.connectedComponents(
            width: w, height: h, pixels: pixels, minPixels: minPixels
        )
        let instances = components.enumerated().map { (i, c) in
            SubjectInstance(
                index: i + 1,
                area: c.area,
                x: c.x, y: c.y, width: c.width, height: c.height
            )
        }
        return PersonsMaskResult(coverage: coverage, instances: instances)
    }

    /// Pull a `CVPixelBuffer` (`kCVPixelFormatType_OneComponent8` after the request
    /// runs) into a flat `[UInt8]` byte buffer for the mask post-processor.
    /// Returns `(width, height, bytes)`. Bytes are stored row-major, top-origin —
    /// exactly what `MaskAnalysis` expects.
    private static func pixelBufferToBytes(_ buffer: CVPixelBuffer) -> (Int, Int, [UInt8]) {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let w = CVPixelBufferGetWidth(buffer)
        let h = CVPixelBufferGetHeight(buffer)
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        guard w > 0, h > 0, stride >= w,
              let base = CVPixelBufferGetBaseAddress(buffer) else {
            return (0, 0, [])
        }
        var pixels = [UInt8](repeating: 0, count: w * h)
        let src = base.assumingMemoryBound(to: UInt8.self)
        for row in 0..<h {
            let srcRow = src.advanced(by: row * stride)
            let dstStart = row * w
            for col in 0..<w {
                pixels[dstStart + col] = srcRow[col]
            }
        }
        return (w, h, pixels)
    }

    // MARK: Custom Core ML model passthrough (v1.6)

    /// Load + run an arbitrary `.mlmodel` or `.mlmodelc` against an image, returning
    /// the observations normalized into `CoreMLResult`. `.mlmodel` source files are
    /// compiled to a tmp `.mlmodelc` on the fly.
    static func runCoreMLModel(modelPath: String, imageURL: URL) throws -> CoreMLResult {
        let modelKind = ModelPath.classify(modelPath)
        guard modelKind != .invalid else {
            throw AugeError.unsupportedFormat("--model: \(modelPath) must end with .mlmodel or .mlmodelc")
        }

        let modelURL = URL(fileURLWithPath: modelPath)
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw AugeError.fileNotFound(modelPath)
        }

        let compiledURL: URL
        if modelKind == .source {
            do {
                compiledURL = try MLModel.compileModel(at: modelURL)
            } catch {
                throw AugeError.unknown("--model: failed to compile \(modelPath): \(error.localizedDescription)")
            }
        } else {
            compiledURL = modelURL
        }

        // Only a compiled-from-source model lives in a temp dir we own; clean it up on
        // every exit path. Never delete a user-supplied .mlmodelc.
        let didCompile = (modelKind == .source)
        defer {
            if didCompile { try? FileManager.default.removeItem(at: compiledURL) }
        }

        let mlModel: MLModel
        do {
            mlModel = try MLModel(contentsOf: compiledURL)
        } catch {
            throw AugeError.unknown("--model: failed to load compiled model: \(error.localizedDescription)")
        }

        let visionModel: VNCoreMLModel
        do {
            visionModel = try VNCoreMLModel(for: mlModel)
        } catch {
            throw AugeError.unknown("--model: VNCoreMLModel rejected this model: \(error.localizedDescription)")
        }

        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = .scaleFit
        let handler = VNImageRequestHandler(url: imageURL, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        let modelName = modelURL.lastPathComponent

        // Classification first — these are scalar predictions, so we treat any
        // non-empty stream of classification observations as a classification
        // result and bail out before checking the other branches.
        let classifications = observations.compactMap { obs -> CoreMLClassification? in
            guard let c = obs as? VNClassificationObservation else { return nil }
            return CoreMLClassification(label: c.identifier, confidence: Double(c.confidence))
        }
        if !classifications.isEmpty {
            let sorted = classifications.sorted { $0.confidence > $1.confidence }
            return CoreMLResult(
                modelName: modelName,
                observationType: .classification,
                classifications: Array(sorted.prefix(20)),
                detections: [], features: []
            )
        }

        // Detection: VNRecognizedObjectObservation has a bbox + labels[].
        let detections = observations.flatMap { obs -> [CoreMLDetection] in
            guard let d = obs as? VNRecognizedObjectObservation else { return [] }
            let bb = d.boundingBox
            let topLabel = d.labels.first
            return [CoreMLDetection(
                label: topLabel?.identifier ?? "object",
                confidence: Double(topLabel?.confidence ?? d.confidence),
                x: Double(bb.origin.x),
                y: Double(bb.origin.y),
                width: Double(bb.size.width),
                height: Double(bb.size.height)
            )]
        }
        if !detections.isEmpty {
            return CoreMLResult(
                modelName: modelName,
                observationType: .detection,
                classifications: [],
                detections: detections,
                features: []
            )
        }

        // Feature value: arbitrary multi-array / image / dictionary output.
        var features: [CoreMLFeature] = []
        for obs in observations {
            guard let f = obs as? VNCoreMLFeatureValueObservation else { continue }
            features.append(coreMLFeatureFrom(featureName: f.featureName, value: f.featureValue))
        }
        return CoreMLResult(
            modelName: modelName,
            observationType: .feature,
            classifications: [],
            detections: [],
            features: features
        )
    }

    private static func coreMLFeatureFrom(featureName: String, value: MLFeatureValue) -> CoreMLFeature {
        switch value.type {
        case .multiArray:
            if let array = value.multiArrayValue {
                let shape = array.shape.map { $0.intValue }
                let count = array.count
                let limit = min(count, CoreMLFeature.sampleLimit)
                var sample = [Double](repeating: 0, count: limit)
                let elementType: String
                switch array.dataType {
                case .double, .float64:
                    let ptr = array.dataPointer.bindMemory(to: Double.self, capacity: count)
                    for i in 0..<limit { sample[i] = ptr[i] }
                    elementType = "double"
                case .float32, .float:
                    let ptr = array.dataPointer.bindMemory(to: Float.self, capacity: count)
                    for i in 0..<limit { sample[i] = Double(ptr[i]) }
                    elementType = "float32"
                case .float16:
                    // Float16 is available on the macOS 26 baseline — decode real values
                    // instead of emitting zeros (which silently misrepresented the data).
                    let ptr = array.dataPointer.bindMemory(to: Float16.self, capacity: count)
                    for i in 0..<limit { sample[i] = Double(ptr[i]) }
                    elementType = "float16"
                case .int32:
                    let ptr = array.dataPointer.bindMemory(to: Int32.self, capacity: count)
                    for i in 0..<limit { sample[i] = Double(ptr[i]) }
                    elementType = "int32"
                case .int8:
                    let ptr = array.dataPointer.bindMemory(to: Int8.self, capacity: count)
                    for i in 0..<limit { sample[i] = Double(ptr[i]) }
                    elementType = "int8"
                @unknown default:
                    elementType = "unknown"
                }
                return CoreMLFeature(
                    name: featureName, shape: shape, elementType: elementType,
                    sample: sample, elementCount: count
                )
            }
        case .dictionary:
            if let dict = value.dictionaryValue as? [String: Double] {
                let keys = dict.keys.sorted().prefix(CoreMLFeature.sampleLimit)
                let sample = keys.map { dict[$0] ?? 0 }
                return CoreMLFeature(
                    name: featureName,
                    shape: [dict.count],
                    elementType: "dictionary<string,double>",
                    sample: Array(sample),
                    elementCount: dict.count
                )
            }
        case .double:
            return CoreMLFeature(name: featureName, shape: [1], elementType: "double",
                                 sample: [value.doubleValue], elementCount: 1)
        case .int64:
            return CoreMLFeature(name: featureName, shape: [1], elementType: "int64",
                                 sample: [Double(value.int64Value)], elementCount: 1)
        case .string:
            return CoreMLFeature(name: featureName, shape: [1], elementType: "string",
                                 sample: [], elementCount: 1)
        case .image:
            return CoreMLFeature(name: featureName, shape: [], elementType: "image",
                                 sample: [], elementCount: 0)
        case .sequence:
            return CoreMLFeature(name: featureName, shape: [], elementType: "sequence",
                                 sample: [], elementCount: 0)
        case .invalid:
            return CoreMLFeature(name: featureName, shape: [], elementType: "invalid",
                                 sample: [], elementCount: 0)
        case .state:
            return CoreMLFeature(name: featureName, shape: [], elementType: "state",
                                 sample: [], elementCount: 0)
        @unknown default:
            break
        }
        return CoreMLFeature(name: featureName, shape: [], elementType: "unknown",
                             sample: [], elementCount: 0)
    }

    // MARK: --motion (optical flow summary)

    /// Run `VNGenerateOpticalFlowRequest` against two frames and reduce the
    /// vector field down to a single magnitude + direction summary. We do not
    /// emit the full vector field — that would be raster output, and auge sees,
    /// it does not paint.
    static func motion(from a: URL, to b: URL) throws -> MotionResult {
        let imageA = try cgImage(from: a)
        let imageB = try cgImage(from: b)

        let request = VNGenerateOpticalFlowRequest(targetedCGImage: imageB, options: [:])
        request.computationAccuracy = .medium
        request.outputPixelFormat = kCVPixelFormatType_TwoComponent32Float

        let handler = VNImageRequestHandler(cgImage: imageA, options: [:])
        try handler.perform([request])

        guard let observation = request.results?.first as? VNPixelBufferObservation else {
            return MotionResult(summary: OpticalFlowSummary.summarize(vectors: []))
        }

        let vectors = sampleFlowVectors(observation.pixelBuffer)
        let summary = OpticalFlowSummary.summarize(vectors: vectors)
        return MotionResult(summary: summary)
    }

    /// Pull a sparse sample of (dx, dy) float-pairs out of an optical-flow
    /// CVPixelBuffer (`kCVPixelFormatType_TwoComponent32Float`). We only
    /// sample at most 4 096 points; the post-processor only needs the
    /// aggregate, not the full field.
    private static func sampleFlowVectors(_ buffer: CVPixelBuffer) -> [(Double, Double)] {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let w = CVPixelBufferGetWidth(buffer)
        let h = CVPixelBufferGetHeight(buffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        guard w > 0, h > 0, let base = CVPixelBufferGetBaseAddress(buffer) else { return [] }
        // Round the stride up so ceil(N/stride) ≤ 4096 holds exactly and the samples
        // stay uniformly spaced across the whole frame (the old floor-division stride
        // could overshoot the cap and bias sampling).
        let stride = max(1, Int((Double(w * h) / 4096.0).rounded(.up)))
        var out: [(Double, Double)] = []
        out.reserveCapacity(4096)
        var counter = 0
        for row in 0..<h {
            let ptr = base.advanced(by: row * rowBytes).assumingMemoryBound(to: Float.self)
            for col in 0..<w {
                if counter % stride == 0 {
                    let dx = Double(ptr[col * 2])
                    let dy = Double(ptr[col * 2 + 1])
                    out.append((dx, dy))
                }
                counter += 1
            }
        }
        return out
    }

    // MARK: --align (image registration)

    /// Try translational alignment first (cheap, fits camera-shake / panning).
    /// If translation reports no movement (identity), fall back to a homography.
    static func align(from a: URL, to b: URL) throws -> AlignResult {
        let imageA = try cgImage(from: a)
        let imageB = try cgImage(from: b)

        // Step 1 — translational.
        let translation = VNTranslationalImageRegistrationRequest(targetedCGImage: imageB, options: [:])
        let handlerT = VNImageRequestHandler(cgImage: imageA, options: [:])
        try handlerT.perform([translation])

        if let obs = translation.results?.first as? VNImageTranslationAlignmentObservation {
            let tx = Double(obs.alignmentTransform.tx)
            let ty = Double(obs.alignmentTransform.ty)
            let matrix: [Double] = [
                1, 0, tx,
                0, 1, ty,
                0, 0, 1
            ]
            let transform = RegistrationTransform(matrix: matrix, kind: .translation)
            // The identity check uses 1e-9 tolerance; subpixel motion is real.
            if !transform.isIdentity {
                return AlignResult(transform: transform, isIdentity: false)
            }
        }

        // Step 2 — homography fallback.
        let homography = VNHomographicImageRegistrationRequest(targetedCGImage: imageB, options: [:])
        let handlerH = VNImageRequestHandler(cgImage: imageA, options: [:])
        try handlerH.perform([homography])

        if let obs = homography.results?.first as? VNImageHomographicAlignmentObservation {
            let m = obs.warpTransform
            let matrix: [Double] = [
                Double(m.columns.0.x), Double(m.columns.1.x), Double(m.columns.2.x),
                Double(m.columns.0.y), Double(m.columns.1.y), Double(m.columns.2.y),
                Double(m.columns.0.z), Double(m.columns.1.z), Double(m.columns.2.z)
            ]
            let transform = RegistrationTransform(matrix: matrix, kind: .homography)
            return AlignResult(transform: transform, isIdentity: transform.isIdentity)
        }

        let identity = RegistrationTransform(matrix: [1,0,0,0,1,0,0,0,1], kind: .translation)
        return AlignResult(transform: identity, isIdentity: true)
    }

    // MARK: --track (sequence handler)

    /// Track a normalized bounding box across an ordered list of frame URLs
    /// using `VNSequenceRequestHandler` + `VNTrackObjectRequest`. The first
    /// frame establishes the box; subsequent frames are tracked from there.
    static func track(initialBox: BoundingBox, frames: [URL]) throws -> TrackResult {
        guard !frames.isEmpty else {
            return TrackResult(initial: initialBox, frames: [])
        }
        let sequence = VNSequenceRequestHandler()
        let visionBox = CGRect(x: initialBox.x, y: initialBox.y,
                               width: initialBox.width, height: initialBox.height)
        var detected = VNDetectedObjectObservation(boundingBox: visionBox)
        var tracked: [TrackedFrame] = []

        // First frame: emit the user-supplied box as the seed observation.
        tracked.append(TrackedFrame(
            file: frames[0].lastPathComponent,
            x: initialBox.x, y: initialBox.y,
            width: initialBox.width, height: initialBox.height,
            confidence: 1.0
        ))

        for i in 1..<frames.count {
            let request = VNTrackObjectRequest(detectedObjectObservation: detected)
            request.trackingLevel = .accurate
            request.isLastFrame = (i == frames.count - 1)
            let image = try cgImage(from: frames[i])
            try sequence.perform([request], on: image)

            guard let next = request.results?.first as? VNDetectedObjectObservation else {
                tracked.append(TrackedFrame(
                    file: frames[i].lastPathComponent,
                    x: detected.boundingBox.origin.x,
                    y: detected.boundingBox.origin.y,
                    width: detected.boundingBox.size.width,
                    height: detected.boundingBox.size.height,
                    confidence: 0.0
                ))
                continue
            }
            tracked.append(TrackedFrame(
                file: frames[i].lastPathComponent,
                x: Double(next.boundingBox.origin.x),
                y: Double(next.boundingBox.origin.y),
                width: Double(next.boundingBox.size.width),
                height: Double(next.boundingBox.size.height),
                confidence: Double(next.confidence)
            ))
            detected = next
        }
        return TrackResult(initial: initialBox, frames: tracked)
    }

    // MARK: --trajectories

    static func detectTrajectories(at url: URL) throws -> TrajectoryResult {
        // Trajectories are most useful over a video stream — but Vision also
        // accepts single-image input which returns at most the projected
        // trajectory of any in-flight object. Frame-by-frame video sampling is
        // handled by the dispatcher.
        let request = VNDetectTrajectoriesRequest(
            frameAnalysisSpacing: .zero,
            trajectoryLength: 5,
            completionHandler: nil
        )
        let handler = VNImageRequestHandler(url: url, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        let trajectories: [Trajectory] = observations.map { obs in
            Trajectory(
                detected: obs.detectedPoints.map {
                    PointResult(x: Double($0.location.x), y: Double($0.location.y))
                },
                projected: obs.projectedPoints.map {
                    PointResult(x: Double($0.x), y: Double($0.y))
                },
                equationCoefficients: [
                    Double(obs.equationCoefficients.x),
                    Double(obs.equationCoefficients.y),
                    Double(obs.equationCoefficients.z),
                ]
            )
        }
        return TrajectoryResult(trajectories: trajectories)
    }

    // MARK: Video sampling

    static let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "avi", "mkv"]

    static func isVideo(at url: URL) -> Bool {
        videoExtensions.contains(url.pathExtension.lowercased())
    }

    /// Sample frames from a video at fixed intervals and run lightweight
    /// per-frame OCR + classification. Returns a `VideoResult` containing one
    /// `VideoFrameResult` per sampled instant.
    static func sampleVideo(
        at url: URL,
        everySeconds: Double,
        runOCR: Bool,
        runClassify: Bool,
        languages: [String]
    ) throws -> VideoResult {
        let asset = AVURLAsset(url: url)
        // NOTE: AVAsset.duration / copyCGImage are deprecated in favor of the async
        // load(.duration) / image(at:) APIs. We deliberately keep the synchronous calls:
        // the CLI's runAsync bridge blocks the calling thread, and the async AVFoundation
        // APIs deadlock when awaited under that block. Migrating cleanly needs an async
        // top-level main (tracked as a follow-up); the sync calls work on macOS 26.
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite, duration > 0 else {
            return VideoResult(durationSeconds: 0, frames: [])
        }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        var frames: [VideoFrameResult] = []
        var t: Double = 0
        while t < duration {
            let cmTime = CMTime(seconds: t, preferredTimescale: 600)
            guard let cgImage = try? generator.copyCGImage(at: cmTime, actualTime: nil) else {
                t += everySeconds
                continue
            }
            var ocrLines: [String] = []
            var classifications: [ClassificationResult] = []
            if runOCR {
                ocrLines = (try? recognizeText(in: cgImage, languages: languages)) ?? []
            }
            if runClassify {
                let request = VNClassifyImageRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? handler.perform([request])
                if let obs = request.results {
                    classifications = obs
                        .filter { $0.confidence > 0.05 }
                        .sorted { $0.confidence > $1.confidence }
                        .prefix(5)
                        .map { ClassificationResult(label: $0.identifier, confidence: Double($0.confidence)) }
                }
            }
            frames.append(VideoFrameResult(time: t, ocr: ocrLines, classifications: classifications))
            t += everySeconds
        }
        return VideoResult(durationSeconds: duration, frames: frames)
    }

    // MARK: helpers

    /// Load a CGImage from a file URL — straight CGImageSource pass-through.
    private static func cgImage(from url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw AugeError.invalidImage
        }
        return image
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
