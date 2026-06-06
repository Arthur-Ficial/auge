import Foundation
import AugeCore

private let sigintAnsiReset: [UInt8] = [0x1B, 0x5B, 0x30, 0x6D]
private let sigintNewline: [UInt8] = [0x0A]

private func writeSignalBytes(_ fd: Int32, _ bytes: [UInt8]) {
    bytes.withUnsafeBytes { rawBuffer in
        guard let baseAddress = rawBuffer.baseAddress else { return }
        _ = write(fd, baseAddress, rawBuffer.count)
    }
}

private enum AugeCLIAction {
    case run(request: AugeExecutionRequest, cleanupPaths: [String])
    case help
    case usageHelp
    case version
    case release
}

private struct ParsedCLI {
    let action: AugeCLIAction
}

private enum CLIParseError: Error {
    case usage(String)
    case runtime(AugeError)

    var message: String {
        switch self {
        case .usage(let message):
            return message
        case .runtime(let error):
            return "\(error.cliLabel) \(error.userMessage)"
        }
    }

    var exitCode: Int32 {
        switch self {
        case .usage:
            return exitUsageError
        case .runtime(let error):
            return error.exitCode
        }
    }
}

package enum AugeCommandLine {
    package static func main(arguments: [String]) -> Int32 {
        NetworkGuard.install()

        signal(SIGINT) { _ in
            if isatty(STDOUT_FILENO) != 0 {
                writeSignalBytes(STDOUT_FILENO, sigintAnsiReset)
            }
            writeSignalBytes(STDERR_FILENO, sigintNewline)
            _exit(130)
        }

        return runParsed(arguments: arguments)
    }

    /// Parse-only entry point for unit tests. Unlike `main(arguments:)`, this does not
    /// install a SIGINT handler or run any Vision analysis. It still resets process-global
    /// output settings (`outputFormat`, `quietMode`, `compactMode`, `noColorFlag`) at the
    /// start of parsing to keep repeated parse tests deterministic, but does no other process-wide
    /// setup and is safe for test suites.
    package static func parseArguments(arguments: [String]) -> Int32 {
        do {
            let parsed = try parse(arguments: arguments)
            switch parsed.action {
            case .usageHelp:
                return exitUsageError
            case .help, .version, .release, .run:
                return exitSuccess
            }
        } catch let error as CLIParseError {
            return error.exitCode
        } catch {
            return AugeError.classify(error).exitCode
        }
    }

    private static func runParsed(arguments: [String]) -> Int32 {
        do {
            let parsed = try parse(arguments: arguments)
            switch parsed.action {
            case .help:
                printUsage()
                return exitSuccess

            case .usageHelp:
                printUsage()
                return exitUsageError

            case .version:
                print("\(appName) v\(version)")
                return exitSuccess

            case .release:
                printRelease()
                return exitSuccess

            case .run(let request, let cleanupPaths):
                defer { cleanup(paths: cleanupPaths) }
                let report = AugeExecutionEngine.run(request)
                render(report: report)
                return report.hasFailures ? exitRuntimeError : exitSuccess
            }
        } catch let error as CLIParseError {
            printError(error.message)
            return error.exitCode
        } catch {
            let classified = AugeError.classify(error)
            printError("\(classified.cliLabel) \(classified.userMessage)")
            return classified.exitCode
        }
    }

    private static func parse(arguments: [String]) throws -> ParsedCLI {
        let args = Array(arguments.dropFirst())

        if args.isEmpty {
            if isatty(STDIN_FILENO) == 0 {
                throw CLIParseError.usage("no analysis mode specified.")
            }
            return ParsedCLI(action: .usageHelp)
        }

        var mode: AnalysisMode? = nil
        var filePaths: [String] = []
        var useClipboard = false
        var options = AugeExecutionOptions()

        outputFormat = .plain
        quietMode = false
        compactMode = false
        noColorFlag = false

        var i = 0
        while i < args.count {
            switch args[i] {
            case "-h", "--help":
                return ParsedCLI(action: .help)

            case "-v", "--version":
                return ParsedCLI(action: .version)

            case "--release":
                return ParsedCLI(action: .release)

            case "-o", "--output":
                i += 1
                guard i < args.count else {
                    throw CLIParseError.usage("--output requires a value (plain, json, md, or ndjson)")
                }
                guard let fmt = OutputFormat(rawValue: args[i]) else {
                    throw CLIParseError.usage("unknown output format: \(args[i]) (use plain, json, md, or ndjson)")
                }
                outputFormat = fmt

            case "--plain": outputFormat = .plain
            case "--md": outputFormat = .md
            case "--json": outputFormat = .json
            case "--ndjson": outputFormat = .ndjson
            case "--compact": compactMode = true
            case "-q", "--quiet": quietMode = true
            case "--no-color": noColorFlag = true

            case "--ocr": mode = .ocr
            case "--classify": mode = .classify
            case "--barcode": mode = .barcode
            case "--faces": mode = .faces
            case "--face-landmarks": mode = .faceLandmarks
            case "--face-quality": mode = .faceQuality
            case "--humans": mode = .humans
            case "--text-rectangles": mode = .textRectangles
            case "--rectangles": mode = .rectangles
            case "--horizon": mode = .horizon
            case "--animals": mode = .animals
            case "--animal-pose": mode = .animalPose
            case "--body-pose": mode = .bodyPose
            case "--hand-pose": mode = .handPose
            case "--saliency-attention": mode = .saliencyAttention
            case "--saliency-objectness": mode = .saliencyObjectness
            case "--contours": mode = .contours
            case "--feature-print": mode = .featurePrint
            case "--compare": mode = .compare
            case "--aesthetics": mode = .aesthetics
            case "--smudge": mode = .smudge
            case "--document": mode = .document
            case "--subject": mode = .subject
            case "--persons-mask": mode = .personsMask
            case "--model":
                mode = .model
                i += 1
                guard i < args.count else {
                    throw CLIParseError.usage("--model requires a path to .mlmodel or .mlmodelc")
                }
                options.modelPath = args[i]
            case "--motion": mode = .motion
            case "--align": mode = .align
            case "--track": mode = .track
            case "--trajectories": mode = .trajectories
            case "--video": mode = .video
            case "--all": mode = .all

            case "--clipboard":
                useClipboard = true

            case "--dpi":
                i += 1
                guard i < args.count, let n = Int(args[i]), n >= 72, n <= 600 else {
                    throw CLIParseError.usage("--dpi requires a number between 72 and 600")
                }
                options.pdfDPI = n

            case "--prefer-embedded":
                options.preferEmbedded = true

            case "--no-prefer-embedded":
                options.preferEmbedded = false

            case "--langs":
                i += 1
                guard i < args.count else {
                    throw CLIParseError.usage("--langs requires a value (e.g. en-US,de-DE)")
                }
                let hints = LanguageHints.parse(args[i])
                guard !hints.isEmpty else {
                    throw CLIParseError.usage("--langs must contain at least one BCP-47 tag")
                }
                options.languageHints = hints

            case "--enhance":
                options.enhanceImages = true

            case "--clean":
                options.cleanText = true

            case "--top":
                i += 1
                guard i < args.count, let n = Int(args[i]), n > 0 else {
                    throw CLIParseError.usage("--top requires a positive number")
                }
                options.topN = n

            case "--min-confidence":
                i += 1
                guard i < args.count, let c = Double(args[i]), c >= 0, c <= 1 else {
                    throw CLIParseError.usage("--min-confidence requires a number between 0 and 1")
                }
                options.minConfidence = c

            case "--upper-body-only":
                options.upperBodyOnly = true

            case "--max-hands":
                i += 1
                guard i < args.count, let n = Int(args[i]), n > 0, n <= 4 else {
                    throw CLIParseError.usage("--max-hands requires a number between 1 and 4")
                }
                options.maxHands = n

            case "--auto-lang":
                options.autoDetectLanguage = true

            case "--fast":
                options.ocrFast = true

            case "--no-correct":
                options.ocrNoCorrect = true

            case "--with-boxes":
                options.ocrWithBoxes = true

            case "--vocab":
                i += 1
                guard i < args.count else {
                    throw CLIParseError.usage("--vocab requires a path to a words file (one per line)")
                }
                do {
                    let url = URL(fileURLWithPath: args[i])
                    let raw = try String(contentsOf: url, encoding: .utf8)
                    options.ocrCustomWords = raw
                        .split(whereSeparator: { $0.isNewline })
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                } catch {
                    throw CLIParseError.usage("--vocab: could not read \(args[i]): \(error.localizedDescription)")
                }

            case "--bbox":
                i += 1
                guard i < args.count, let bbox = BBoxString.parse(args[i]) else {
                    throw CLIParseError.usage("--bbox requires x,y,w,h with normalized values in [0,1]")
                }
                options.trackBoundingBox = bbox

            case "--every":
                i += 1
                guard i < args.count, let seconds = IntervalParser.parse(args[i]) else {
                    throw CLIParseError.usage("--every requires a positive duration (e.g. 1s, 500ms, 2.5s)")
                }
                options.videoEverySeconds = seconds

            default:
                if args[i].hasPrefix("-") {
                    throw CLIParseError.usage("unknown option: \(args[i])")
                }
                filePaths.append(args[i])
            }

            i += 1
        }

        guard let analysisMode = mode else {
            throw CLIParseError.usage("no analysis mode specified. See --help.")
        }

        switch analysisMode {
        case .compare:
            guard !useClipboard else {
                throw CLIParseError.usage("--compare does not support --clipboard")
            }
            guard filePaths.count == 2 else {
                throw CLIParseError.usage("--compare requires exactly two image paths")
            }
            return ParsedCLI(action: .run(
                request: .init(mode: analysisMode, filePaths: filePaths, options: options),
                cleanupPaths: []
            ))

        case .motion:
            guard !useClipboard else {
                throw CLIParseError.usage("--motion does not support --clipboard")
            }
            guard filePaths.count == 2 else {
                throw CLIParseError.usage("--motion requires exactly two image paths")
            }
            return ParsedCLI(action: .run(
                request: .init(mode: analysisMode, filePaths: filePaths, options: options),
                cleanupPaths: []
            ))

        case .align:
            guard !useClipboard else {
                throw CLIParseError.usage("--align does not support --clipboard")
            }
            guard filePaths.count == 2 else {
                throw CLIParseError.usage("--align requires exactly two image paths")
            }
            return ParsedCLI(action: .run(
                request: .init(mode: analysisMode, filePaths: filePaths, options: options),
                cleanupPaths: []
            ))

        case .model:
            guard !useClipboard else {
                throw CLIParseError.usage("--model does not support --clipboard")
            }
            guard options.modelPath != nil else {
                throw CLIParseError.usage("--model requires a path to .mlmodel or .mlmodelc")
            }
            guard filePaths.count == 1 else {
                throw CLIParseError.usage("--model requires exactly one image path")
            }
            return ParsedCLI(action: .run(
                request: .init(mode: analysisMode, filePaths: filePaths, options: options),
                cleanupPaths: []
            ))

        case .track:
            guard !useClipboard else {
                throw CLIParseError.usage("--track does not support --clipboard")
            }
            guard options.trackBoundingBox != nil else {
                throw CLIParseError.usage("--track requires --bbox x,y,w,h")
            }
            guard !filePaths.isEmpty else {
                throw CLIParseError.usage("--track requires at least one frame path")
            }
            return ParsedCLI(action: .run(
                request: .init(mode: analysisMode, filePaths: filePaths, options: options),
                cleanupPaths: []
            ))

        case .video:
            guard !useClipboard else {
                throw CLIParseError.usage("--video does not support --clipboard")
            }
            guard !filePaths.isEmpty else {
                throw CLIParseError.usage("--video requires at least one video path")
            }
            return ParsedCLI(action: .run(
                request: .init(mode: analysisMode, filePaths: filePaths, options: options),
                cleanupPaths: []
            ))

        default:
            let resolved = try resolveInputs(filePaths: filePaths, useClipboard: useClipboard)
            guard !resolved.filePaths.isEmpty else {
                throw CLIParseError.usage("no input file specified")
            }

            return ParsedCLI(action: .run(
                request: .init(mode: analysisMode, filePaths: resolved.filePaths, options: options),
                cleanupPaths: resolved.cleanupPaths
            ))
        }
    }

    private static func resolveInputs(filePaths: [String], useClipboard: Bool) throws -> (filePaths: [String], cleanupPaths: [String]) {
        var resolvedPaths = filePaths
        var cleanupPaths: [String] = []

        if useClipboard {
            if !resolvedPaths.isEmpty {
                throw CLIParseError.usage("--clipboard cannot be combined with file paths")
            }
            do {
                let url = try Clipboard.readImage()
                resolvedPaths.append(url.path)
                if url.lastPathComponent.hasPrefix("auge-clipboard-") {
                    cleanupPaths.append(url.path)
                }
            } catch let error as AugeError {
                throw CLIParseError.runtime(error)
            } catch {
                throw CLIParseError.runtime(AugeError.classify(error))
            }
        } else if isatty(STDIN_FILENO) == 0 && resolvedPaths.isEmpty {
            while let line = readLine() {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    resolvedPaths.append(trimmed)
                }
            }
        }

        return (resolvedPaths, cleanupPaths)
    }

    private static func render(report: AugeExecutionReport) {
        for outcome in report.outcomes {
            switch outcome {
            case .response(let response):
                outputResult(mode: response.mode, file: response.file, payload: response.results)
            case .notice(let notice):
                guard !quietMode else { continue }
                switch notice.kind {
                case .warning:
                    printStderr("warning: \(notice.message)")
                case .noResult:
                    printStderr(notice.message)
                }
            case .failure(let failure):
                printError("\(failure.error.cliLabel) \(failure.error.userMessage)")
            }
        }
    }

    private static func cleanup(paths: [String]) {
        for path in paths {
            try? FileManager.default.removeItem(atPath: path)
        }
    }
}
