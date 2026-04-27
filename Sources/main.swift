// ============================================================================
// main.swift — Entry point for auge
// Apple Vision from the command line.
// https://github.com/Arthur-Ficial/auge
// ============================================================================

import Foundation
import AugeCore

// MARK: - Configuration

let version = buildVersion
let appName = "auge"

// MARK: - Exit Codes

let exitSuccess: Int32 = 0
let exitRuntimeError: Int32 = 1
let exitUsageError: Int32 = 2
let exitVisionUnavailable: Int32 = 5

func exitCode(for error: AugeError) -> Int32 { return error.exitCode }

// MARK: - Network Guard
NetworkGuard.install()

// MARK: - Signal Handling

signal(SIGINT) { _ in
    if isatty(STDOUT_FILENO) != 0 {
        FileHandle.standardOutput.write(Data("\u{001B}[0m".utf8))
    }
    FileHandle.standardError.write(Data("\n".utf8))
    _exit(130)
}

// MARK: - Argument Parsing

var args = Array(CommandLine.arguments.dropFirst())

if args.isEmpty {
    if isatty(STDIN_FILENO) == 0 {
        printError("no analysis mode specified.")
        exit(exitUsageError)
    }
    printUsage()
    exit(exitUsageError)
}

var mode: AnalysisMode? = nil
var filePaths: [String] = []
var topN: Int = 10
var minConfidence: Double = 0.01
var useClipboard = false
var pdfDPI: Int = 200
var preferEmbedded: Bool = true
var languageHints: [String] = []
var enhanceImages: Bool = false
var cleanText: Bool = false
var upperBodyOnly: Bool = false
var maxHands: Int = 2
var autoDetectLanguage: Bool = false
var ocrFast: Bool = false
var ocrNoCorrect: Bool = false
var ocrWithBoxes: Bool = false
var ocrCustomWords: [String] = []

var i = 0
while i < args.count {
    switch args[i] {
    case "-h", "--help":
        printUsage()
        exit(exitSuccess)

    case "-v", "--version":
        print("\(appName) v\(version)")
        exit(exitSuccess)

    case "--release":
        printRelease()
        exit(exitSuccess)

    case "-o", "--output":
        i += 1
        guard i < args.count else {
            printError("--output requires a value (plain, json, md, or ndjson)")
            exit(exitUsageError)
        }
        guard let fmt = OutputFormat(rawValue: args[i]) else {
            printError("unknown output format: \(args[i]) (use plain, json, md, or ndjson)")
            exit(exitUsageError)
        }
        outputFormat = fmt

    case "--plain": outputFormat = .plain
    case "--md":    outputFormat = .md
    case "--json":  outputFormat = .json
    case "--ndjson": outputFormat = .ndjson
    case "--compact": compactMode = true
    case "-q", "--quiet": quietMode = true
    case "--no-color": noColorFlag = true

    // Capability flags
    case "--ocr":                  mode = .ocr
    case "--classify":             mode = .classify
    case "--barcode":              mode = .barcode
    case "--faces":                mode = .faces
    case "--face-landmarks":       mode = .faceLandmarks
    case "--face-quality":         mode = .faceQuality
    case "--humans":               mode = .humans
    case "--text-rectangles":      mode = .textRectangles
    case "--rectangles":           mode = .rectangles
    case "--horizon":              mode = .horizon
    case "--animals":              mode = .animals
    case "--animal-pose":          mode = .animalPose
    case "--body-pose":            mode = .bodyPose
    case "--hand-pose":            mode = .handPose
    case "--saliency-attention":   mode = .saliencyAttention
    case "--saliency-objectness":  mode = .saliencyObjectness
    case "--contours":             mode = .contours
    case "--feature-print":        mode = .featurePrint
    case "--compare":              mode = .compare
    case "--aesthetics":           mode = .aesthetics
    case "--smudge":               mode = .smudge
    case "--document":             mode = .document
    case "--all":                  mode = .all

    case "--clipboard":
        useClipboard = true

    case "--dpi":
        i += 1
        guard i < args.count, let n = Int(args[i]), n >= 72, n <= 600 else {
            printError("--dpi requires a number between 72 and 600")
            exit(exitUsageError)
        }
        pdfDPI = n

    case "--prefer-embedded":     preferEmbedded = true
    case "--no-prefer-embedded":  preferEmbedded = false

    case "--langs":
        i += 1
        guard i < args.count else {
            printError("--langs requires a value (e.g. en-US,de-DE)")
            exit(exitUsageError)
        }
        languageHints = LanguageHints.parse(args[i])
        if languageHints.isEmpty {
            printError("--langs must contain at least one BCP-47 tag")
            exit(exitUsageError)
        }

    case "--enhance": enhanceImages = true
    case "--clean":   cleanText = true

    case "--top":
        i += 1
        guard i < args.count, let n = Int(args[i]), n > 0 else {
            printError("--top requires a positive number")
            exit(exitUsageError)
        }
        topN = n

    case "--min-confidence":
        i += 1
        guard i < args.count, let c = Double(args[i]), c >= 0, c <= 1 else {
            printError("--min-confidence requires a number between 0 and 1")
            exit(exitUsageError)
        }
        minConfidence = c

    case "--upper-body-only":
        upperBodyOnly = true

    case "--max-hands":
        i += 1
        guard i < args.count, let n = Int(args[i]), n > 0, n <= 4 else {
            printError("--max-hands requires a number between 1 and 4")
            exit(exitUsageError)
        }
        maxHands = n

    case "--auto-lang":
        autoDetectLanguage = true

    case "--fast":
        ocrFast = true

    case "--no-correct":
        ocrNoCorrect = true

    case "--with-boxes":
        ocrWithBoxes = true

    case "--vocab":
        i += 1
        guard i < args.count else {
            printError("--vocab requires a path to a words file (one per line)")
            exit(exitUsageError)
        }
        do {
            let url = URL(fileURLWithPath: args[i])
            let raw = try String(contentsOf: url, encoding: .utf8)
            ocrCustomWords = raw
                .split(whereSeparator: { $0.isNewline })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        } catch {
            printError("--vocab: could not read \(args[i]): \(error.localizedDescription)")
            exit(exitUsageError)
        }

    default:
        if args[i].hasPrefix("-") {
            printError("unknown option: \(args[i])")
            exit(exitUsageError)
        }
        filePaths.append(args[i])
    }
    i += 1
}

// --clipboard input
if useClipboard {
    if !filePaths.isEmpty {
        printError("--clipboard cannot be combined with file paths")
        exit(exitUsageError)
    }
    do {
        let url = try Clipboard.readImage()
        filePaths.append(url.path)
    } catch let err as AugeError {
        printError("\(err.cliLabel) \(err.userMessage)")
        exit(err.exitCode)
    } catch {
        let classified = AugeError.classify(error)
        printError("\(classified.cliLabel) \(classified.userMessage)")
        exit(classified.exitCode)
    }
} else if isatty(STDIN_FILENO) == 0 && filePaths.isEmpty {
    while let line = readLine() {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { filePaths.append(trimmed) }
    }
}

guard let analysisMode = mode else {
    printError("no analysis mode specified. See --help.")
    exit(exitUsageError)
}

guard !filePaths.isEmpty else {
    printError("no input file specified")
    exit(exitUsageError)
}

// MARK: - --compare special case (two files in, single result out)

if analysisMode == .compare {
    guard filePaths.count == 2 else {
        printError("--compare requires exactly two image paths")
        exit(exitUsageError)
    }
    let a = filePaths[0]
    let b = filePaths[1]
    switch (ImageSource.validatePath(a), ImageSource.validatePath(b)) {
    case (.failure(let e), _), (_, .failure(let e)):
        printError("\(e.cliLabel) \(e.userMessage)")
        exit(e.exitCode)
    case (.success(let urlA), .success(let urlB)):
        do {
            let result = try Analyzer.compareImages(urlA, urlB)
            outputResult(mode: "compare", file: "\(a) vs \(b)",
                         payload: .compare(ComparePayload(compare: result)))
            exit(exitSuccess)
        } catch {
            let classified = AugeError.classify(error)
            printError("\(classified.cliLabel) \(classified.userMessage)")
            exit(classified.exitCode)
        }
    }
}

// MARK: - Dispatch

var hasError = false

for filePath in filePaths {
    switch ImageSource.validatePath(filePath) {
    case .failure(let error):
        printError("\(error.cliLabel) \(error.userMessage)")
        hasError = true
        continue
    case .success(let url):
        do {
            switch analysisMode {
            case .ocr:
                let useDetailedOCR = autoDetectLanguage || ocrFast || ocrNoCorrect || ocrWithBoxes || !ocrCustomWords.isEmpty
                var lines: [String]
                var details: [OCRLineDetail]? = nil

                if useDetailedOCR {
                    let opts = Analyzer.OCROptions(
                        languages: languageHints,
                        autoDetectLanguage: autoDetectLanguage,
                        customWords: ocrCustomWords,
                        useLanguageCorrection: !ocrNoCorrect,
                        fast: ocrFast,
                        withBoxes: ocrWithBoxes,
                        enhance: enhanceImages
                    )
                    let detail: [OCRLineDetail]
                    if PDFDetect.isPDF(at: url) {
                        let cfg = PDFProcessor.Configuration(dpi: pdfDPI, preferEmbedded: preferEmbedded)
                        detail = try Analyzer.recognizeTextDetailedInPDF(at: url, config: cfg, options: opts)
                    } else {
                        detail = try Analyzer.recognizeTextDetailed(at: url, options: opts)
                    }
                    lines = detail.map { $0.text }
                    details = detail
                } else {
                    if PDFDetect.isPDF(at: url) {
                        let cfg = PDFProcessor.Configuration(dpi: pdfDPI, preferEmbedded: preferEmbedded)
                        lines = try Analyzer.recognizeTextInPDF(at: url, config: cfg, languages: languageHints, enhance: enhanceImages)
                    } else {
                        lines = try Analyzer.recognizeText(at: url, languages: languageHints, enhance: enhanceImages)
                    }
                }

                if cleanText && !lines.isEmpty {
                    let input = lines
                    do {
                        lines = try runAsync { try await Cleaner.clean(lines: input) }
                        // Cleaner reflows; per-line metadata no longer matches.
                        details = nil
                    } catch {
                        if !quietMode {
                            printStderr("warning: --clean skipped for \(filePath): \(error.localizedDescription)")
                        }
                    }
                }

                if lines.isEmpty {
                    if !quietMode { printStderr("No text detected in \(filePath)") }
                } else {
                    outputResult(mode: "ocr", file: filePath, payload: .ocr(OCRPayload(
                        text: lines.joined(separator: "\n"),
                        lines: lines,
                        lineDetails: details
                    )))
                }

            case .classify:
                var results = try Analyzer.classifyImage(at: url)
                results = results.filter { $0.confidence >= minConfidence }
                if results.count > topN { results = Array(results.prefix(topN)) }
                if results.isEmpty {
                    if !quietMode { printStderr("No classifications detected in \(filePath)") }
                } else {
                    outputResult(mode: "classify", file: filePath,
                                 payload: .classification(ClassificationPayload(classifications: results)))
                }

            case .barcode:
                let results = try Analyzer.detectBarcodes(at: url)
                if results.isEmpty {
                    if !quietMode { printStderr("No barcodes detected in \(filePath)") }
                } else {
                    outputResult(mode: "barcode", file: filePath,
                                 payload: .barcodes(BarcodesPayload(barcodes: results)))
                }

            case .faces:
                let results = try Analyzer.detectFaces(at: url)
                outputResult(mode: "faces", file: filePath,
                             payload: .faces(FacesPayload(count: results.count, faces: results)))

            case .faceLandmarks:
                let results = try Analyzer.detectFaceLandmarks(at: url)
                outputResult(mode: "face-landmarks", file: filePath,
                             payload: .faceLandmarks(FaceLandmarksPayload(count: results.count, faces: results)))

            case .faceQuality:
                let results = try Analyzer.detectFaceQuality(at: url)
                outputResult(mode: "face-quality", file: filePath,
                             payload: .faceQuality(FaceQualityPayload(count: results.count, faces: results)))

            case .humans:
                let results = try Analyzer.detectHumans(at: url, upperBodyOnly: upperBodyOnly)
                outputResult(mode: "humans", file: filePath,
                             payload: .humans(HumansPayload(count: results.count, humans: results)))

            case .textRectangles:
                let results = try Analyzer.detectTextRectangles(at: url)
                outputResult(mode: "text-rectangles", file: filePath,
                             payload: .textRectangles(TextRectanglesPayload(count: results.count, rectangles: results)))

            case .rectangles:
                let results = try Analyzer.detectRectangles(at: url)
                outputResult(mode: "rectangles", file: filePath,
                             payload: .rectangles(RectanglesPayload(count: results.count, rectangles: results)))

            case .horizon:
                let result = try Analyzer.detectHorizon(at: url)
                outputResult(mode: "horizon", file: filePath,
                             payload: .horizon(HorizonPayload(horizon: result)))

            case .animals:
                let results = try Analyzer.recognizeAnimals(at: url)
                outputResult(mode: "animals", file: filePath,
                             payload: .animals(AnimalsPayload(count: results.count, animals: results)))

            case .animalPose:
                let results = try Analyzer.detectAnimalPose(at: url)
                outputResult(mode: "animal-pose", file: filePath,
                             payload: .animalPose(AnimalPosePayload(count: results.count, animals: results)))

            case .bodyPose:
                let results = try Analyzer.detectBodyPose(at: url)
                outputResult(mode: "body-pose", file: filePath,
                             payload: .bodyPose(BodyPosePayload(count: results.count, bodies: results)))

            case .handPose:
                let results = try Analyzer.detectHandPose(at: url, maximumHands: maxHands)
                outputResult(mode: "hand-pose", file: filePath,
                             payload: .handPose(HandPosePayload(count: results.count, hands: results)))

            case .saliencyAttention:
                let results = try Analyzer.attentionSaliency(at: url)
                outputResult(mode: "saliency-attention", file: filePath,
                             payload: .saliencyAttention(SaliencyPayload(count: results.count, regions: results)))

            case .saliencyObjectness:
                let results = try Analyzer.objectnessSaliency(at: url)
                outputResult(mode: "saliency-objectness", file: filePath,
                             payload: .saliencyObjectness(SaliencyPayload(count: results.count, regions: results)))

            case .contours:
                let result = try Analyzer.detectContours(at: url)
                outputResult(mode: "contours", file: filePath,
                             payload: .contours(ContoursPayload(contours: result)))

            case .featurePrint:
                let (fp, _) = try Analyzer.featurePrint(at: url)
                outputResult(mode: "feature-print", file: filePath,
                             payload: .featurePrint(FeaturePrintPayload(featurePrint: fp)))

            case .compare:
                // Handled above via early-return.
                break

            case .aesthetics:
                let result = try runAsync { try await TahoeAnalyzer.aesthetics(at: url) }
                outputResult(mode: "aesthetics", file: filePath,
                             payload: .aesthetics(AestheticsPayload(aesthetics: result)))

            case .smudge:
                let result = try runAsync { try await TahoeAnalyzer.smudge(at: url) }
                outputResult(mode: "smudge", file: filePath,
                             payload: .smudge(SmudgePayload(smudge: result)))

            case .document:
                let result = try runAsync { try await TahoeAnalyzer.document(at: url) }
                outputResult(mode: "document", file: filePath,
                             payload: .document(DocumentPayload(document: result)))

            case .all:
                // --all means ALL: every capability auge supports runs here.
                // Each is wrapped in its own do/catch so a single failure does
                // not block the others. Failures surface as `null` in JSON
                // and a stderr warning (unless --quiet).
                func warnIfFailed(_ cap: String, _ error: Error) {
                    if !quietMode {
                        printStderr("warning: \(cap) failed for \(filePath): \(AugeError.classify(error).userMessage)")
                    }
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

                do {
                    var ocrLines: [String]
                    if PDFDetect.isPDF(at: url) {
                        let cfg = PDFProcessor.Configuration(dpi: pdfDPI, preferEmbedded: preferEmbedded)
                        ocrLines = try Analyzer.recognizeTextInPDF(at: url, config: cfg, languages: languageHints, enhance: enhanceImages)
                    } else {
                        ocrLines = try Analyzer.recognizeText(at: url, languages: languageHints, enhance: enhanceImages)
                    }
                    if cleanText && !ocrLines.isEmpty {
                        let input = ocrLines
                        do {
                            ocrLines = try runAsync { try await Cleaner.clean(lines: input) }
                        } catch {
                            if !quietMode {
                                printStderr("warning: --clean skipped: \(error.localizedDescription)")
                            }
                        }
                    }
                    ocrPayload = OCRPayload(text: ocrLines.joined(separator: "\n"), lines: ocrLines)
                } catch { warnIfFailed("ocr", error) }

                do {
                    var c = try Analyzer.classifyImage(at: url)
                    c = c.filter { $0.confidence >= minConfidence }
                    if c.count > topN { c = Array(c.prefix(topN)) }
                    classifyPayload = ClassificationPayload(classifications: c)
                } catch { warnIfFailed("classify", error) }

                do {
                    let b = try Analyzer.detectBarcodes(at: url)
                    barcodesPayload = BarcodesPayload(barcodes: b)
                } catch { warnIfFailed("barcode", error) }

                do {
                    let f = try Analyzer.detectFaces(at: url)
                    facesPayload = FacesPayload(count: f.count, faces: f)
                } catch { warnIfFailed("faces", error) }

                do {
                    let r = try Analyzer.detectFaceLandmarks(at: url)
                    faceLandmarksPayload = FaceLandmarksPayload(count: r.count, faces: r)
                } catch { warnIfFailed("face-landmarks", error) }

                do {
                    let r = try Analyzer.detectFaceQuality(at: url)
                    faceQualityPayload = FaceQualityPayload(count: r.count, faces: r)
                } catch { warnIfFailed("face-quality", error) }

                do {
                    let r = try Analyzer.detectHumans(at: url, upperBodyOnly: upperBodyOnly)
                    humansPayload = HumansPayload(count: r.count, humans: r)
                } catch { warnIfFailed("humans", error) }

                do {
                    let r = try Analyzer.detectTextRectangles(at: url)
                    textRectanglesPayload = TextRectanglesPayload(count: r.count, rectangles: r)
                } catch { warnIfFailed("text-rectangles", error) }

                do {
                    let r = try Analyzer.detectRectangles(at: url)
                    rectanglesPayload = RectanglesPayload(count: r.count, rectangles: r)
                } catch { warnIfFailed("rectangles", error) }

                do {
                    let r = try Analyzer.detectHorizon(at: url)
                    horizonPayload = HorizonPayload(horizon: r)
                } catch { warnIfFailed("horizon", error) }

                do {
                    let r = try Analyzer.recognizeAnimals(at: url)
                    animalsPayload = AnimalsPayload(count: r.count, animals: r)
                } catch { warnIfFailed("animals", error) }

                do {
                    let r = try Analyzer.detectAnimalPose(at: url)
                    animalPosePayload = AnimalPosePayload(count: r.count, animals: r)
                } catch { warnIfFailed("animal-pose", error) }

                do {
                    let r = try Analyzer.detectBodyPose(at: url)
                    bodyPosePayload = BodyPosePayload(count: r.count, bodies: r)
                } catch { warnIfFailed("body-pose", error) }

                do {
                    let r = try Analyzer.detectHandPose(at: url, maximumHands: maxHands)
                    handPosePayload = HandPosePayload(count: r.count, hands: r)
                } catch { warnIfFailed("hand-pose", error) }

                do {
                    let r = try Analyzer.attentionSaliency(at: url)
                    saliencyAttentionPayload = SaliencyPayload(count: r.count, regions: r)
                } catch { warnIfFailed("saliency-attention", error) }

                do {
                    let r = try Analyzer.objectnessSaliency(at: url)
                    saliencyObjectnessPayload = SaliencyPayload(count: r.count, regions: r)
                } catch { warnIfFailed("saliency-objectness", error) }

                do {
                    let r = try Analyzer.detectContours(at: url)
                    contoursPayload = ContoursPayload(contours: r)
                } catch { warnIfFailed("contours", error) }

                do {
                    let (fp, _) = try Analyzer.featurePrint(at: url)
                    featurePrintPayload = FeaturePrintPayload(featurePrint: fp)
                } catch { warnIfFailed("feature-print", error) }

                do {
                    let r = try runAsync { try await TahoeAnalyzer.aesthetics(at: url) }
                    aestheticsPayload = AestheticsPayload(aesthetics: r)
                } catch { warnIfFailed("aesthetics", error) }

                do {
                    let r = try runAsync { try await TahoeAnalyzer.smudge(at: url) }
                    smudgePayload = SmudgePayload(smudge: r)
                } catch { warnIfFailed("smudge", error) }

                do {
                    let r = try runAsync { try await TahoeAnalyzer.document(at: url) }
                    documentPayload = DocumentPayload(document: r)
                } catch { warnIfFailed("document", error) }

                outputResult(mode: "all", file: filePath, payload: .all(AllPayload(
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
                    document: documentPayload
                )))
            }
        } catch {
            let classified = AugeError.classify(error)
            printError("\(classified.cliLabel) \(classified.userMessage)")
            hasError = true
        }
    }
}

exit(hasError ? exitRuntimeError : exitSuccess)
