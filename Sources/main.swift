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
            printError("--output requires a value (plain or json)")
            exit(exitUsageError)
        }
        guard let fmt = OutputFormat(rawValue: args[i]) else {
            printError("unknown output format: \(args[i]) (use plain or json)")
            exit(exitUsageError)
        }
        outputFormat = fmt

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

// Read file paths from stdin if piped
if isatty(STDIN_FILENO) == 0 && filePaths.isEmpty {
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
                let lines = try Analyzer.recognizeText(at: url)
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
