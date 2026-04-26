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

/// Map an AugeError to the appropriate exit code.
func exitCode(for error: AugeError) -> Int32 {
    return error.exitCode
}

// MARK: - Network Guard
// Hard-block any HTTP/HTTPS/WS/WSS request inside the process. auge is on-device only.

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

// No args → print usage
if args.isEmpty {
    // Check for stdin pipe with no args
    if isatty(STDIN_FILENO) == 0 {
        // Piped data but no mode — can't determine what to do
        printError("no analysis mode specified. Use --ocr, --classify, --barcode, or --faces")
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

    case "--plain":
        outputFormat = .plain

    case "--md":
        outputFormat = .md

    case "--json":
        outputFormat = .json

    case "--ndjson":
        outputFormat = .ndjson

    case "--compact":
        compactMode = true

    case "-q", "--quiet":
        quietMode = true

    case "--no-color":
        noColorFlag = true

    case "--ocr":
        mode = .ocr

    case "--classify":
        mode = .classify

    case "--barcode":
        mode = .barcode

    case "--faces":
        mode = .faces

    case "--clipboard":
        useClipboard = true

    case "--dpi":
        i += 1
        guard i < args.count, let n = Int(args[i]), n >= 72, n <= 600 else {
            printError("--dpi requires a number between 72 and 600")
            exit(exitUsageError)
        }
        pdfDPI = n

    case "--prefer-embedded":
        preferEmbedded = true

    case "--no-prefer-embedded":
        preferEmbedded = false

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

    case "--enhance":
        enhanceImages = true

    case "--clean":
        cleanText = true

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

    default:
        if args[i].hasPrefix("-") {
            printError("unknown option: \(args[i])")
            exit(exitUsageError)
        }
        // Everything else is a file path
        filePaths.append(args[i])
    }
    i += 1
}

// --clipboard: read pasteboard image, write to temp file, treat as input.
// Cannot be combined with file paths. When set, stdin is not consulted for paths.
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
    // Read file paths from stdin if piped (no --clipboard)
    while let line = readLine() {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            filePaths.append(trimmed)
        }
    }
}

// Validate: must have a mode
guard let analysisMode = mode else {
    printError("no analysis mode specified. Use --ocr, --classify, --barcode, or --faces")
    exit(exitUsageError)
}

// Validate: must have at least one file
guard !filePaths.isEmpty else {
    printError("no input file specified")
    exit(exitUsageError)
}

// MARK: - Dispatch

var hasError = false

for filePath in filePaths {
    // Validate the file path
    switch ImageSource.validatePath(filePath) {
    case .failure(let error):
        printError("\(error.cliLabel) \(error.userMessage)")
        hasError = true
        continue
    case .success(let url):
        do {
            switch analysisMode {
            case .ocr:
                var lines: [String]
                if PDFDetect.isPDF(at: url) {
                    let cfg = PDFProcessor.Configuration(dpi: pdfDPI, preferEmbedded: preferEmbedded)
                    lines = try Analyzer.recognizeTextInPDF(at: url, config: cfg, languages: languageHints, enhance: enhanceImages)
                } else {
                    lines = try Analyzer.recognizeText(at: url, languages: languageHints, enhance: enhanceImages)
                }

                if cleanText && !lines.isEmpty {
                    if #available(macOS 26.0, *) {
                        let input = lines
                        do {
                            lines = try runAsync { try await Cleaner.clean(lines: input) }
                        } catch {
                            if !quietMode {
                                printStderr("warning: --clean skipped for \(filePath): \(error.localizedDescription)")
                            }
                        }
                    } else {
                        printError("--clean requires macOS 26 (Tahoe) — FoundationModels is unavailable on this OS")
                        exit(exitRuntimeError)
                    }
                }

                if lines.isEmpty {
                    if !quietMode {
                        printStderr("No text detected in \(filePath)")
                    }
                } else {
                    outputResult(mode: "ocr", file: filePath, payload: .ocr(OCRPayload(
                        text: lines.joined(separator: "\n"),
                        lines: lines
                    )))
                }

            case .classify:
                var results = try Analyzer.classifyImage(at: url)
                results = results.filter { $0.confidence >= minConfidence }
                if results.count > topN {
                    results = Array(results.prefix(topN))
                }
                if results.isEmpty {
                    if !quietMode {
                        printStderr("No classifications detected in \(filePath)")
                    }
                } else {
                    outputResult(mode: "classify", file: filePath, payload: .classification(
                        ClassificationPayload(classifications: results)
                    ))
                }

            case .barcode:
                let results = try Analyzer.detectBarcodes(at: url)
                if results.isEmpty {
                    if !quietMode {
                        printStderr("No barcodes detected in \(filePath)")
                    }
                } else {
                    outputResult(mode: "barcode", file: filePath, payload: .barcodes(
                        BarcodesPayload(barcodes: results)
                    ))
                }

            case .faces:
                let results = try Analyzer.detectFaces(at: url)
                outputResult(mode: "faces", file: filePath, payload: .faces(
                    FacesPayload(count: results.count, faces: results)
                ))
            }
        } catch {
            let classified = AugeError.classify(error)
            printError("\(classified.cliLabel) \(classified.userMessage)")
            hasError = true
        }
    }
}

exit(hasError ? exitRuntimeError : exitSuccess)
