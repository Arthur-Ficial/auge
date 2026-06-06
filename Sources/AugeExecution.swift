import Foundation
import AugeCore

package struct AugeExecutionOptions: Sendable {
    package var topN: Int = 10
    package var minConfidence: Double = 0.01
    package var pdfDPI: Int = 200
    package var preferEmbedded: Bool = true
    package var languageHints: [String] = []
    package var enhanceImages: Bool = false
    package var cleanText: Bool = false
    package var upperBodyOnly: Bool = false
    package var maxHands: Int = 2
    package var autoDetectLanguage: Bool = false
    package var ocrFast: Bool = false
    package var ocrNoCorrect: Bool = false
    package var ocrWithBoxes: Bool = false
    package var ocrCustomWords: [String] = []
    package var modelPath: String? = nil
    package var trackBoundingBox: BoundingBox? = nil
    package var videoEverySeconds: Double = 1.0

    package init() {}
}

package struct AugeExecutionRequest: Sendable {
    package let mode: AnalysisMode
    package let filePaths: [String]
    package let options: AugeExecutionOptions

    package init(mode: AnalysisMode, filePaths: [String], options: AugeExecutionOptions) {
        self.mode = mode
        self.filePaths = filePaths
        self.options = options
    }
}

package struct AugeExecutionNotice: Sendable {
    package enum Kind: String, Sendable {
        case warning
        case noResult
    }

    package let kind: Kind
    package let file: String?
    package let message: String
}

package struct AugeExecutionFailure: Sendable {
    package let file: String?
    package let error: AugeError
}

enum AugeExecutionOutcome {
    case response(AugeResponse)
    case notice(AugeExecutionNotice)
    case failure(AugeExecutionFailure)
}

package struct AugeExecutionReport {
    package let mode: AnalysisMode
    let outcomes: [AugeExecutionOutcome]

    var responses: [AugeResponse] {
        outcomes.compactMap {
            guard case .response(let response) = $0 else { return nil }
            return response
        }
    }

    package var notices: [AugeExecutionNotice] {
        outcomes.compactMap {
            guard case .notice(let notice) = $0 else { return nil }
            return notice
        }
    }

    package var failures: [AugeExecutionFailure] {
        outcomes.compactMap {
            guard case .failure(let failure) = $0 else { return nil }
            return failure
        }
    }

    package var hasFailures: Bool { !failures.isEmpty }
}

package extension AnalysisMode {
    var cliName: String {
        switch self {
        case .ocr: return "ocr"
        case .classify: return "classify"
        case .barcode: return "barcode"
        case .faces: return "faces"
        case .faceLandmarks: return "face-landmarks"
        case .faceQuality: return "face-quality"
        case .humans: return "humans"
        case .textRectangles: return "text-rectangles"
        case .rectangles: return "rectangles"
        case .horizon: return "horizon"
        case .animals: return "animals"
        case .animalPose: return "animal-pose"
        case .bodyPose: return "body-pose"
        case .handPose: return "hand-pose"
        case .saliencyAttention: return "saliency-attention"
        case .saliencyObjectness: return "saliency-objectness"
        case .contours: return "contours"
        case .featurePrint: return "feature-print"
        case .compare: return "compare"
        case .aesthetics: return "aesthetics"
        case .smudge: return "smudge"
        case .document: return "document"
        case .subject: return "subject"
        case .personsMask: return "persons-mask"
        case .model: return "model"
        case .motion: return "motion"
        case .align: return "align"
        case .track: return "track"
        case .trajectories: return "trajectories"
        case .video: return "video"
        case .all: return "all"
        }
    }

    var toolName: String {
        "auge_" + cliName.replacingOccurrences(of: "-", with: "_")
    }

    static let mcpModes: [AnalysisMode] = [
        .ocr,
        .classify,
        .barcode,
        .faces,
        .faceLandmarks,
        .faceQuality,
        .humans,
        .textRectangles,
        .rectangles,
        .horizon,
        .animals,
        .animalPose,
        .bodyPose,
        .handPose,
        .saliencyAttention,
        .saliencyObjectness,
        .contours,
        .featurePrint,
        .compare,
        .aesthetics,
        .smudge,
        .document,
        .all,
    ]
}

private func makeResponse(mode: AnalysisMode, file: String, payload: ResultPayload) -> AugeResponse {
    AugeResponse(
        mode: mode.cliName,
        file: file,
        results: payload,
        metadata: .init(onDevice: true, version: version, schema: augeSchemaVersion)
    )
}

package enum AugeExecutionEngine {
    package static func run(_ request: AugeExecutionRequest) -> AugeExecutionReport {
        var outcomes: [AugeExecutionOutcome] = []
        let options = request.options

        func addNotice(_ kind: AugeExecutionNotice.Kind, file: String?, _ message: String) {
            outcomes.append(.notice(.init(kind: kind, file: file, message: message)))
        }

        func addFailure(file: String?, _ error: AugeError) {
            outcomes.append(.failure(.init(file: file, error: error)))
        }

        if request.mode == .compare {
            guard request.filePaths.count == 2 else {
                addFailure(file: nil, .unknown("--compare requires exactly two image paths"))
                return AugeExecutionReport(mode: request.mode, outcomes: outcomes)
            }

            let a = request.filePaths[0]
            let b = request.filePaths[1]
            switch (ImageSource.validatePath(a), ImageSource.validatePath(b)) {
            case (.failure(let error), _), (_, .failure(let error)):
                addFailure(file: nil, error)
            case (.success(let urlA), .success(let urlB)):
                do {
                    let result = try Analyzer.compareImages(urlA, urlB)
                    outcomes.append(.response(makeResponse(
                        mode: .compare,
                        file: "\(a) vs \(b)",
                        payload: .compare(ComparePayload(compare: result))
                    )))
                } catch {
                    addFailure(file: nil, AugeError.classify(error))
                }
            }

            return AugeExecutionReport(mode: request.mode, outcomes: outcomes)
        }

        if request.mode == .motion {
            guard request.filePaths.count == 2 else {
                addFailure(file: nil, .unknown("--motion requires exactly two image paths"))
                return AugeExecutionReport(mode: request.mode, outcomes: outcomes)
            }

            let a = request.filePaths[0]
            let b = request.filePaths[1]
            switch (ImageSource.validatePath(a), ImageSource.validatePath(b)) {
            case (.failure(let error), _), (_, .failure(let error)):
                addFailure(file: nil, error)
            case (.success(let urlA), .success(let urlB)):
                do {
                    let result = try Analyzer.motion(from: urlA, to: urlB)
                    outcomes.append(.response(makeResponse(
                        mode: .motion,
                        file: "\(a) -> \(b)",
                        payload: .motion(MotionPayload(motion: result))
                    )))
                } catch {
                    addFailure(file: nil, AugeError.classify(error))
                }
            }

            return AugeExecutionReport(mode: request.mode, outcomes: outcomes)
        }

        if request.mode == .align {
            guard request.filePaths.count == 2 else {
                addFailure(file: nil, .unknown("--align requires exactly two image paths"))
                return AugeExecutionReport(mode: request.mode, outcomes: outcomes)
            }

            let a = request.filePaths[0]
            let b = request.filePaths[1]
            switch (ImageSource.validatePath(a), ImageSource.validatePath(b)) {
            case (.failure(let error), _), (_, .failure(let error)):
                addFailure(file: nil, error)
            case (.success(let urlA), .success(let urlB)):
                do {
                    let result = try Analyzer.align(from: urlA, to: urlB)
                    outcomes.append(.response(makeResponse(
                        mode: .align,
                        file: "\(a) -> \(b)",
                        payload: .align(AlignPayload(align: result))
                    )))
                } catch {
                    addFailure(file: nil, AugeError.classify(error))
                }
            }

            return AugeExecutionReport(mode: request.mode, outcomes: outcomes)
        }

        if request.mode == .model {
            guard let modelPath = options.modelPath, !modelPath.isEmpty else {
                addFailure(file: nil, .unknown("--model requires a path to .mlmodel or .mlmodelc"))
                return AugeExecutionReport(mode: request.mode, outcomes: outcomes)
            }
            guard request.filePaths.count == 1 else {
                addFailure(file: nil, .unknown("--model requires exactly one image path"))
                return AugeExecutionReport(mode: request.mode, outcomes: outcomes)
            }
            let filePath = request.filePaths[0]
            switch ImageSource.validatePath(filePath) {
            case .failure(let error):
                addFailure(file: filePath, error)
            case .success(let imageURL):
                do {
                    let result = try Analyzer.runCoreMLModel(modelPath: modelPath, imageURL: imageURL)
                    outcomes.append(.response(makeResponse(
                        mode: .model,
                        file: filePath,
                        payload: .model(ModelPayload(model: result))
                    )))
                } catch {
                    addFailure(file: filePath, AugeError.classify(error))
                }
            }

            return AugeExecutionReport(mode: request.mode, outcomes: outcomes)
        }

        if request.mode == .track {
            guard let initialBox = options.trackBoundingBox else {
                addFailure(file: nil, .unknown("--track requires --bbox x,y,w,h"))
                return AugeExecutionReport(mode: request.mode, outcomes: outcomes)
            }
            guard !request.filePaths.isEmpty else {
                addFailure(file: nil, .unknown("--track requires at least one frame path"))
                return AugeExecutionReport(mode: request.mode, outcomes: outcomes)
            }

            var frameURLs: [URL] = []
            frameURLs.reserveCapacity(request.filePaths.count)
            for filePath in request.filePaths {
                switch ImageSource.validatePath(filePath) {
                case .failure(let error):
                    addFailure(file: filePath, error)
                    return AugeExecutionReport(mode: request.mode, outcomes: outcomes)
                case .success(let url):
                    frameURLs.append(url)
                }
            }

            do {
                let result = try Analyzer.track(initialBox: initialBox, frames: frameURLs)
                outcomes.append(.response(makeResponse(
                    mode: .track,
                    file: request.filePaths.joined(separator: ","),
                    payload: .track(TrackPayload(track: result))
                )))
            } catch {
                addFailure(file: nil, AugeError.classify(error))
            }

            return AugeExecutionReport(mode: request.mode, outcomes: outcomes)
        }

        if request.mode == .video {
            guard !request.filePaths.isEmpty else {
                addFailure(file: nil, .unknown("--video requires at least one video path"))
                return AugeExecutionReport(mode: request.mode, outcomes: outcomes)
            }

            for filePath in request.filePaths {
                let url = URL(fileURLWithPath: filePath)
                guard FileManager.default.fileExists(atPath: filePath) else {
                    addFailure(file: filePath, .fileNotFound(filePath))
                    continue
                }
                guard Analyzer.videoExtensions.contains(url.pathExtension.lowercased()) else {
                    addFailure(file: filePath, .unsupportedFormat(url.pathExtension.isEmpty ? "unknown" : url.pathExtension.lowercased()))
                    continue
                }
                do {
                    let result = try Analyzer.sampleVideo(
                        at: url,
                        everySeconds: options.videoEverySeconds,
                        runOCR: true,
                        runClassify: true,
                        languages: options.languageHints
                    )
                    outcomes.append(.response(makeResponse(
                        mode: .video,
                        file: filePath,
                        payload: .video(.init(video: result))
                    )))
                } catch {
                    addFailure(file: filePath, AugeError.classify(error))
                }
            }

            return AugeExecutionReport(mode: request.mode, outcomes: outcomes)
        }

        for filePath in request.filePaths {
            switch ImageSource.validatePath(filePath) {
            case .failure(let error):
                addFailure(file: filePath, error)
                continue
            case .success(let url):
                do {
                    switch request.mode {
                    case .ocr:
                        let result = try runOCR(at: url, filePath: filePath, options: options)
                        outcomes.append(contentsOf: result.outcomes)

                    case .classify:
                        var results = try Analyzer.classifyImage(at: url)
                        results = results.filter { $0.confidence >= options.minConfidence }
                        if results.count > options.topN { results = Array(results.prefix(options.topN)) }
                        if results.isEmpty {
                            addNotice(.noResult, file: filePath, "No classifications detected in \(filePath)")
                        } else {
                            outcomes.append(.response(makeResponse(
                                mode: .classify,
                                file: filePath,
                                payload: .classification(.init(classifications: results))
                            )))
                        }

                    case .barcode:
                        let results = try Analyzer.detectBarcodes(at: url)
                        if results.isEmpty {
                            addNotice(.noResult, file: filePath, "No barcodes detected in \(filePath)")
                        } else {
                            outcomes.append(.response(makeResponse(
                                mode: .barcode,
                                file: filePath,
                                payload: .barcodes(.init(barcodes: results))
                            )))
                        }

                    case .faces:
                        let results = try Analyzer.detectFaces(at: url)
                        outcomes.append(.response(makeResponse(
                            mode: .faces,
                            file: filePath,
                            payload: .faces(.init(count: results.count, faces: results))
                        )))

                    case .faceLandmarks:
                        let results = try Analyzer.detectFaceLandmarks(at: url)
                        outcomes.append(.response(makeResponse(
                            mode: .faceLandmarks,
                            file: filePath,
                            payload: .faceLandmarks(.init(count: results.count, faces: results))
                        )))

                    case .faceQuality:
                        let results = try Analyzer.detectFaceQuality(at: url)
                        outcomes.append(.response(makeResponse(
                            mode: .faceQuality,
                            file: filePath,
                            payload: .faceQuality(.init(count: results.count, faces: results))
                        )))

                    case .humans:
                        let results = try Analyzer.detectHumans(at: url, upperBodyOnly: options.upperBodyOnly)
                        outcomes.append(.response(makeResponse(
                            mode: .humans,
                            file: filePath,
                            payload: .humans(.init(count: results.count, humans: results))
                        )))

                    case .textRectangles:
                        let results = try Analyzer.detectTextRectangles(at: url)
                        outcomes.append(.response(makeResponse(
                            mode: .textRectangles,
                            file: filePath,
                            payload: .textRectangles(.init(count: results.count, rectangles: results))
                        )))

                    case .rectangles:
                        let results = try Analyzer.detectRectangles(at: url)
                        outcomes.append(.response(makeResponse(
                            mode: .rectangles,
                            file: filePath,
                            payload: .rectangles(.init(count: results.count, rectangles: results))
                        )))

                    case .horizon:
                        let result = try Analyzer.detectHorizon(at: url)
                        outcomes.append(.response(makeResponse(
                            mode: .horizon,
                            file: filePath,
                            payload: .horizon(.init(horizon: result))
                        )))

                    case .animals:
                        let results = try Analyzer.recognizeAnimals(at: url)
                        outcomes.append(.response(makeResponse(
                            mode: .animals,
                            file: filePath,
                            payload: .animals(.init(count: results.count, animals: results))
                        )))

                    case .animalPose:
                        let results = try Analyzer.detectAnimalPose(at: url)
                        outcomes.append(.response(makeResponse(
                            mode: .animalPose,
                            file: filePath,
                            payload: .animalPose(.init(count: results.count, animals: results))
                        )))

                    case .bodyPose:
                        let results = try Analyzer.detectBodyPose(at: url)
                        outcomes.append(.response(makeResponse(
                            mode: .bodyPose,
                            file: filePath,
                            payload: .bodyPose(.init(count: results.count, bodies: results))
                        )))

                    case .handPose:
                        let results = try Analyzer.detectHandPose(at: url, maximumHands: options.maxHands)
                        outcomes.append(.response(makeResponse(
                            mode: .handPose,
                            file: filePath,
                            payload: .handPose(.init(count: results.count, hands: results))
                        )))

                    case .saliencyAttention:
                        let results = try Analyzer.attentionSaliency(at: url)
                        outcomes.append(.response(makeResponse(
                            mode: .saliencyAttention,
                            file: filePath,
                            payload: .saliencyAttention(.init(count: results.count, regions: results))
                        )))

                    case .saliencyObjectness:
                        let results = try Analyzer.objectnessSaliency(at: url)
                        outcomes.append(.response(makeResponse(
                            mode: .saliencyObjectness,
                            file: filePath,
                            payload: .saliencyObjectness(.init(count: results.count, regions: results))
                        )))

                    case .contours:
                        let result = try Analyzer.detectContours(at: url)
                        outcomes.append(.response(makeResponse(
                            mode: .contours,
                            file: filePath,
                            payload: .contours(.init(contours: result))
                        )))

                    case .featurePrint:
                        let (result, _) = try Analyzer.featurePrint(at: url)
                        outcomes.append(.response(makeResponse(
                            mode: .featurePrint,
                            file: filePath,
                            payload: .featurePrint(.init(featurePrint: result))
                        )))

                    case .aesthetics:
                        let result = try runAsync { try await TahoeAnalyzer.aesthetics(at: url) }
                        outcomes.append(.response(makeResponse(
                            mode: .aesthetics,
                            file: filePath,
                            payload: .aesthetics(.init(aesthetics: result))
                        )))

                    case .smudge:
                        let result = try runAsync { try await TahoeAnalyzer.smudge(at: url) }
                        outcomes.append(.response(makeResponse(
                            mode: .smudge,
                            file: filePath,
                            payload: .smudge(.init(smudge: result))
                        )))

                    case .document:
                        let result = try runAsync { try await TahoeAnalyzer.document(at: url) }
                        outcomes.append(.response(makeResponse(
                            mode: .document,
                            file: filePath,
                            payload: .document(.init(document: result))
                        )))

                    case .subject:
                        let result = try Analyzer.detectSubjectInstances(at: url)
                        outcomes.append(.response(makeResponse(
                            mode: .subject,
                            file: filePath,
                            payload: .subject(.init(subject: result))
                        )))

                    case .personsMask:
                        let result = try Analyzer.detectPersonsMask(at: url)
                        outcomes.append(.response(makeResponse(
                            mode: .personsMask,
                            file: filePath,
                            payload: .personsMask(.init(personsMask: result))
                        )))

                    case .trajectories:
                        let result = try Analyzer.detectTrajectories(at: url)
                        outcomes.append(.response(makeResponse(
                            mode: .trajectories,
                            file: filePath,
                            payload: .trajectories(.init(trajectories: result))
                        )))

                    case .video:
                        break

                    case .all:
                        var allNotices: [AugeExecutionOutcome] = []
                        let allPayload = runAll(at: url, filePath: filePath, options: options, notices: &allNotices)
                        outcomes.append(contentsOf: allNotices)
                        outcomes.append(.response(makeResponse(
                            mode: .all,
                            file: filePath,
                            payload: .all(allPayload)
                        )))

                    case .compare:
                        break
                    case .model, .motion, .align, .track:
                        break
                    }
                } catch {
                    addFailure(file: filePath, AugeError.classify(error))
                }
            }
        }

        return AugeExecutionReport(mode: request.mode, outcomes: outcomes)
    }

    private static func runOCR(at url: URL, filePath: String, options: AugeExecutionOptions) throws -> AugeExecutionReport {
        var outcomes: [AugeExecutionOutcome] = []
        let useDetailedOCR = options.autoDetectLanguage || options.ocrFast || options.ocrNoCorrect || options.ocrWithBoxes || !options.ocrCustomWords.isEmpty
        var lines: [String]
        var details: [OCRLineDetail]? = nil

        if useDetailedOCR {
            let opts = Analyzer.OCROptions(
                languages: options.languageHints,
                autoDetectLanguage: options.autoDetectLanguage,
                customWords: options.ocrCustomWords,
                useLanguageCorrection: !options.ocrNoCorrect,
                fast: options.ocrFast,
                withBoxes: options.ocrWithBoxes,
                enhance: options.enhanceImages
            )
            let detail: [OCRLineDetail]
            if PDFDetect.isPDF(at: url) {
                let cfg = PDFProcessor.Configuration(dpi: options.pdfDPI, preferEmbedded: options.preferEmbedded)
                detail = try Analyzer.recognizeTextDetailedInPDF(at: url, config: cfg, options: opts)
            } else {
                detail = try Analyzer.recognizeTextDetailed(at: url, options: opts)
            }
            lines = detail.map(\.text)
            details = detail
        } else if PDFDetect.isPDF(at: url) {
            let cfg = PDFProcessor.Configuration(dpi: options.pdfDPI, preferEmbedded: options.preferEmbedded)
            lines = try Analyzer.recognizeTextInPDF(at: url, config: cfg, languages: options.languageHints, enhance: options.enhanceImages)
        } else {
            lines = try Analyzer.recognizeText(at: url, languages: options.languageHints, enhance: options.enhanceImages)
        }

        if options.cleanText && !lines.isEmpty {
            let input = lines
            do {
                lines = try runAsync { try await Cleaner.clean(lines: input) }
                details = nil
            } catch {
                outcomes.append(.notice(.init(
                    kind: .warning,
                    file: filePath,
                    message: "--clean skipped for \(filePath): \(error.localizedDescription)"
                )))
            }
        }

        if lines.isEmpty {
            outcomes.append(.notice(.init(kind: .noResult, file: filePath, message: "No text detected in \(filePath)")))
        } else {
            outcomes.append(.response(makeResponse(
                mode: .ocr,
                file: filePath,
                payload: .ocr(.init(
                    text: lines.joined(separator: "\n"),
                    lines: lines,
                    lineDetails: details
                ))
            )))
        }

        return AugeExecutionReport(mode: .ocr, outcomes: outcomes)
    }

    private static func runAll(at url: URL, filePath: String, options: AugeExecutionOptions, notices: inout [AugeExecutionOutcome]) -> AllPayload {
        func warn(_ capability: String, _ error: Error) {
            notices.append(.notice(.init(
                kind: .warning,
                file: filePath,
                message: "\(capability) failed for \(filePath): \(AugeError.classify(error).userMessage)"
            )))
        }

        var ocrPayload: OCRPayload? = nil
        var classifyPayload: ClassificationPayload? = nil
        var barcodesPayload: BarcodesPayload? = nil
        var facesPayload: FacesPayload? = nil
        var faceLandmarksPayload: FaceLandmarksPayload? = nil
        var faceQualityPayload: FaceQualityPayload? = nil
        var humansPayload: HumansPayload? = nil
        var textRectanglesPayload: TextRectanglesPayload? = nil
        var rectanglesPayload: RectanglesPayload? = nil
        var horizonPayload: HorizonPayload? = nil
        var animalsPayload: AnimalsPayload? = nil
        var animalPosePayload: AnimalPosePayload? = nil
        var bodyPosePayload: BodyPosePayload? = nil
        var handPosePayload: HandPosePayload? = nil
        var saliencyAttentionPayload: SaliencyPayload? = nil
        var saliencyObjectnessPayload: SaliencyPayload? = nil
        var contoursPayload: ContoursPayload? = nil
        var featurePrintPayload: FeaturePrintPayload? = nil
        var aestheticsPayload: AestheticsPayload? = nil
        var smudgePayload: SmudgePayload? = nil
        var documentPayload: DocumentPayload? = nil
        var subjectPayload: SubjectPayload? = nil
        var personsMaskPayload: PersonsMaskPayload? = nil

        do {
            var ocrLines: [String]
            if PDFDetect.isPDF(at: url) {
                let cfg = PDFProcessor.Configuration(dpi: options.pdfDPI, preferEmbedded: options.preferEmbedded)
                ocrLines = try Analyzer.recognizeTextInPDF(at: url, config: cfg, languages: options.languageHints, enhance: options.enhanceImages)
            } else {
                ocrLines = try Analyzer.recognizeText(at: url, languages: options.languageHints, enhance: options.enhanceImages)
            }
            if options.cleanText && !ocrLines.isEmpty {
                let input = ocrLines
                do {
                    ocrLines = try runAsync { try await Cleaner.clean(lines: input) }
                } catch {
                    notices.append(.notice(.init(kind: .warning, file: filePath, message: "--clean skipped for \(filePath): \(error.localizedDescription)")))
                }
            }
            ocrPayload = .init(text: ocrLines.joined(separator: "\n"), lines: ocrLines)
        } catch {
            warn("ocr", error)
        }

        do {
            var results = try Analyzer.classifyImage(at: url)
            results = results.filter { $0.confidence >= options.minConfidence }
            if results.count > options.topN { results = Array(results.prefix(options.topN)) }
            classifyPayload = .init(classifications: results)
        } catch {
            warn("classify", error)
        }

        do {
            barcodesPayload = .init(barcodes: try Analyzer.detectBarcodes(at: url))
        } catch {
            warn("barcode", error)
        }

        do {
            let results = try Analyzer.detectFaces(at: url)
            facesPayload = .init(count: results.count, faces: results)
        } catch {
            warn("faces", error)
        }

        do {
            let results = try Analyzer.detectFaceLandmarks(at: url)
            faceLandmarksPayload = .init(count: results.count, faces: results)
        } catch {
            warn("face-landmarks", error)
        }

        do {
            let results = try Analyzer.detectFaceQuality(at: url)
            faceQualityPayload = .init(count: results.count, faces: results)
        } catch {
            warn("face-quality", error)
        }

        do {
            let results = try Analyzer.detectHumans(at: url, upperBodyOnly: options.upperBodyOnly)
            humansPayload = .init(count: results.count, humans: results)
        } catch {
            warn("humans", error)
        }

        do {
            let results = try Analyzer.detectTextRectangles(at: url)
            textRectanglesPayload = .init(count: results.count, rectangles: results)
        } catch {
            warn("text-rectangles", error)
        }

        do {
            let results = try Analyzer.detectRectangles(at: url)
            rectanglesPayload = .init(count: results.count, rectangles: results)
        } catch {
            warn("rectangles", error)
        }

        do {
            horizonPayload = .init(horizon: try Analyzer.detectHorizon(at: url))
        } catch {
            warn("horizon", error)
        }

        do {
            let results = try Analyzer.recognizeAnimals(at: url)
            animalsPayload = .init(count: results.count, animals: results)
        } catch {
            warn("animals", error)
        }

        do {
            let results = try Analyzer.detectAnimalPose(at: url)
            animalPosePayload = .init(count: results.count, animals: results)
        } catch {
            warn("animal-pose", error)
        }

        do {
            let results = try Analyzer.detectBodyPose(at: url)
            bodyPosePayload = .init(count: results.count, bodies: results)
        } catch {
            warn("body-pose", error)
        }

        do {
            let results = try Analyzer.detectHandPose(at: url, maximumHands: options.maxHands)
            handPosePayload = .init(count: results.count, hands: results)
        } catch {
            warn("hand-pose", error)
        }

        do {
            let results = try Analyzer.attentionSaliency(at: url)
            saliencyAttentionPayload = .init(count: results.count, regions: results)
        } catch {
            warn("saliency-attention", error)
        }

        do {
            let results = try Analyzer.objectnessSaliency(at: url)
            saliencyObjectnessPayload = .init(count: results.count, regions: results)
        } catch {
            warn("saliency-objectness", error)
        }

        do {
            contoursPayload = .init(contours: try Analyzer.detectContours(at: url))
        } catch {
            warn("contours", error)
        }

        do {
            let (featurePrint, _) = try Analyzer.featurePrint(at: url)
            featurePrintPayload = .init(featurePrint: featurePrint)
        } catch {
            warn("feature-print", error)
        }

        do {
            aestheticsPayload = .init(aesthetics: try runAsync { try await TahoeAnalyzer.aesthetics(at: url) })
        } catch {
            warn("aesthetics", error)
        }

        do {
            smudgePayload = .init(smudge: try runAsync { try await TahoeAnalyzer.smudge(at: url) })
        } catch {
            warn("smudge", error)
        }

        do {
            documentPayload = .init(document: try runAsync { try await TahoeAnalyzer.document(at: url) })
        } catch {
            warn("document", error)
        }

        do {
            subjectPayload = .init(subject: try Analyzer.detectSubjectInstances(at: url))
        } catch {
            warn("subject", error)
        }

        do {
            personsMaskPayload = .init(personsMask: try Analyzer.detectPersonsMask(at: url))
        } catch {
            warn("persons-mask", error)
        }

        return AllPayload(
            ocr: ocrPayload,
            classify: classifyPayload,
            barcodes: barcodesPayload,
            faces: facesPayload,
            faceLandmarks: faceLandmarksPayload,
            faceQuality: faceQualityPayload,
            humans: humansPayload,
            textRectangles: textRectanglesPayload,
            rectangles: rectanglesPayload,
            horizon: horizonPayload,
            animals: animalsPayload,
            animalPose: animalPosePayload,
            bodyPose: bodyPosePayload,
            handPose: handPosePayload,
            saliencyAttention: saliencyAttentionPayload,
            saliencyObjectness: saliencyObjectnessPayload,
            contours: contoursPayload,
            featurePrint: featurePrintPayload,
            aesthetics: aestheticsPayload,
            smudge: smudgePayload,
            document: documentPayload,
            subject: subjectPayload,
            personsMask: personsMaskPayload
        )
    }
}
