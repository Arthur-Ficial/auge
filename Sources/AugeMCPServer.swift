import Foundation
import AugeCore

private enum MCPProtocolError: Error {
    case parseError(String)
    case invalidRequest(String)
    case invalidParams(String)
    case methodNotFound(String)
    case serverError(String)

    var code: Int {
        switch self {
        case .parseError: return -32700
        case .invalidRequest: return -32600
        case .invalidParams: return -32602
        case .methodNotFound: return -32601
        case .serverError: return -32000
        }
    }

    var message: String {
        switch self {
        case .parseError(let message),
             .invalidRequest(let message),
             .invalidParams(let message),
             .methodNotFound(let message),
             .serverError(let message):
            return message
        }
    }
}

private enum MCPServerState: Equatable {
    case waitingForInitialize
    case waitingForInitializedNotification
    case running
}

package enum AugeMCPServer {
    private static let protocolVersion = "2025-03-26"

    package static func main() -> Int32 {
        NetworkGuard.install()

        var state = MCPServerState.waitingForInitialize

        while let line = readLine(strippingNewline: true) {
            guard !line.isEmpty else { continue }

            do {
                let data = Data(line.utf8)
                let json: Any
                do {
                    // Parse JSON including fragments (for example, bare strings/numbers).
                    // `handleEnvelope` then rejects non-object payloads as Invalid Request (-32600).
                    json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
                } catch {
                    throw MCPProtocolError.parseError("Invalid JSON payload")
                }

                if let batch = json as? [Any] {
                    if batch.isEmpty {
                        try writeJSONObject(errorResponse(id: nil, error: .invalidRequest("Batch request must contain at least one call")))
                        continue
                    }

                    var responses: [Any] = []
                    responses.reserveCapacity(batch.count)

                    for envelope in batch {
                        let responseID = batchResponseID(for: envelope)
                        do {
                            if let response = try handleEnvelope(envelope, state: &state) {
                                responses.append(response)
                            }
                        } catch let error as MCPProtocolError {
                            responses.append(errorResponse(id: responseID, error: error))
                        } catch {
                            responses.append(errorResponse(id: responseID, error: .serverError(error.localizedDescription)))
                        }
                    }

                    if !responses.isEmpty {
                        try writeJSONObject(responses)
                    }
                } else if let response = try handleEnvelope(json, state: &state) {
                    try writeJSONObject(response)
                }
            } catch let error as MCPProtocolError {
                try? writeJSONObject(errorResponse(id: nil, error: error))
            } catch {
                try? writeJSONObject(errorResponse(id: nil, error: .serverError(error.localizedDescription)))
            }
        }

        return exitSuccess
    }

    private static func handleEnvelope(_ envelope: Any, state: inout MCPServerState) throws -> Any? {
        guard let request = envelope as? [String: Any] else {
            throw MCPProtocolError.invalidRequest("Request body must be a JSON object")
        }

        guard (request["jsonrpc"] as? String) == "2.0" else {
            throw MCPProtocolError.invalidRequest("jsonrpc must be '2.0'")
        }

        guard let method = request["method"] as? String else {
            throw MCPProtocolError.invalidRequest("method is required")
        }

        let rawID = request["id"]
        let hasIDMember = request.keys.contains("id")
        var responseID: Any?

        do {
            let id = try validateRequestID(rawID)
            responseID = id
            let params = try requestObject(from: request["params"], field: "params")

            switch method {
            case "initialize":
                try requireRequestID(id, for: method)
                return try handleInitialize(id: id, params: params, state: &state)
            case "notifications/initialized":
                guard state == .waitingForInitializedNotification else {
                    return nil
                }
                state = .running
                return nil
            case "ping":
                try requireRequestID(id, for: method)
                return successResponse(id: id, result: [:])
            case "tools/list":
                try requireRequestID(id, for: method)
                guard state != .waitingForInitialize else {
                    throw MCPProtocolError.invalidRequest("initialize must be called before tools/list")
                }
                return successResponse(id: id, result: ["tools": toolDefinitions()])
            case "tools/call":
                try requireRequestID(id, for: method)
                guard state == .running || state == .waitingForInitializedNotification else {
                    throw MCPProtocolError.invalidRequest("initialize must be called before tools/call")
                }
                guard let name = params["name"] as? String else {
                    throw MCPProtocolError.invalidParams("tools/call requires a tool name")
                }
                let arguments = try requestObject(from: params["arguments"], field: "arguments")
                return successResponse(id: id, result: try callTool(named: name, arguments: arguments))
            default:
                throw MCPProtocolError.methodNotFound("Method not found: \(method)")
            }
        } catch let error as MCPProtocolError {
            guard hasIDMember else { return nil }
            return errorResponse(id: responseID, error: error)
        } catch {
            guard hasIDMember else { return nil }
            return errorResponse(id: responseID, error: .serverError(error.localizedDescription))
        }
    }

    private static func batchResponseID(for envelope: Any) -> Any? {
        guard let request = envelope as? [String: Any], request.keys.contains("id") else {
            return nil
        }
        return try? validateRequestID(request["id"])
    }

    private static func handleInitialize(id: Any?, params: [String: Any], state: inout MCPServerState) throws -> Any {
        if state != .waitingForInitialize {
            throw MCPProtocolError.invalidRequest("Server is already initialized")
        }

        let requestedVersion = params["protocolVersion"] as? String ?? protocolVersion
        let negotiatedVersion = requestedVersion == protocolVersion ? requestedVersion : protocolVersion
        state = .waitingForInitializedNotification

        return successResponse(id: id, result: [
            "protocolVersion": negotiatedVersion,
            "capabilities": [
                "tools": [
                    "listChanged": false,
                ],
            ],
            "serverInfo": [
                "name": "auge-mcp",
                "version": version,
            ],
            "instructions": "Local stdio MCP adapter for auge. All analysis stays on-device and never uses the network.",
        ])
    }

    private static func callTool(named name: String, arguments: [String: Any]) throws -> [String: Any] {
        switch name {
        case "auge_release":
            let info = makeReleaseInfo()
            let infoObject = try encodeJSONObject(info)
            let text = "auge v\(version) — \(info.framework)"
            return [
                "content": [["type": "text", "text": text]],
                "structuredContent": infoObject,
                "isError": false,
            ]

        case AnalysisMode.ocr.toolName:
            return try execute(mode: .ocr, arguments: arguments, allowClipboard: true, configure: configureOCR)
        case AnalysisMode.classify.toolName:
            return try execute(mode: .classify, arguments: arguments, allowClipboard: true, configure: configureClassification)
        case AnalysisMode.barcode.toolName:
            return try execute(mode: .barcode, arguments: arguments, allowClipboard: true, configure: { _, _ in })
        case AnalysisMode.faces.toolName:
            return try execute(mode: .faces, arguments: arguments, allowClipboard: true, configure: { _, _ in })
        case AnalysisMode.faceLandmarks.toolName:
            return try execute(mode: .faceLandmarks, arguments: arguments, allowClipboard: true, configure: { _, _ in })
        case AnalysisMode.faceQuality.toolName:
            return try execute(mode: .faceQuality, arguments: arguments, allowClipboard: true, configure: { _, _ in })
        case AnalysisMode.humans.toolName:
            return try execute(mode: .humans, arguments: arguments, allowClipboard: true, configure: configureHumans)
        case AnalysisMode.textRectangles.toolName:
            return try execute(mode: .textRectangles, arguments: arguments, allowClipboard: true, configure: { _, _ in })
        case AnalysisMode.rectangles.toolName:
            return try execute(mode: .rectangles, arguments: arguments, allowClipboard: true, configure: { _, _ in })
        case AnalysisMode.horizon.toolName:
            return try execute(mode: .horizon, arguments: arguments, allowClipboard: true, configure: { _, _ in })
        case AnalysisMode.animals.toolName:
            return try execute(mode: .animals, arguments: arguments, allowClipboard: true, configure: { _, _ in })
        case AnalysisMode.animalPose.toolName:
            return try execute(mode: .animalPose, arguments: arguments, allowClipboard: true, configure: { _, _ in })
        case AnalysisMode.bodyPose.toolName:
            return try execute(mode: .bodyPose, arguments: arguments, allowClipboard: true, configure: { _, _ in })
        case AnalysisMode.handPose.toolName:
            return try execute(mode: .handPose, arguments: arguments, allowClipboard: true, configure: configureHandPose)
        case AnalysisMode.saliencyAttention.toolName:
            return try execute(mode: .saliencyAttention, arguments: arguments, allowClipboard: true, configure: { _, _ in })
        case AnalysisMode.saliencyObjectness.toolName:
            return try execute(mode: .saliencyObjectness, arguments: arguments, allowClipboard: true, configure: { _, _ in })
        case AnalysisMode.contours.toolName:
            return try execute(mode: .contours, arguments: arguments, allowClipboard: true, configure: { _, _ in })
        case AnalysisMode.featurePrint.toolName:
            return try execute(mode: .featurePrint, arguments: arguments, allowClipboard: true, configure: { _, _ in })
        case AnalysisMode.compare.toolName:
            return try executeCompare(arguments: arguments)
        case AnalysisMode.aesthetics.toolName:
            return try execute(mode: .aesthetics, arguments: arguments, allowClipboard: true, configure: { _, _ in })
        case AnalysisMode.smudge.toolName:
            return try execute(mode: .smudge, arguments: arguments, allowClipboard: true, configure: { _, _ in })
        case AnalysisMode.document.toolName:
            return try execute(mode: .document, arguments: arguments, allowClipboard: true, configure: { _, _ in })
        case AnalysisMode.all.toolName:
            return try execute(mode: .all, arguments: arguments, allowClipboard: true, configure: configureAll)
        default:
            throw MCPProtocolError.invalidParams("Unknown tool: \(name)")
        }
    }

    private static func execute(
        mode: AnalysisMode,
        arguments: [String: Any],
        allowClipboard: Bool,
        configure: (inout AugeExecutionOptions, [String: Any]) throws -> Void
    ) throws -> [String: Any] {
        var options = AugeExecutionOptions()
        try configure(&options, arguments)
        let output = try parseOutputFormat(arguments)
        let quiet = arguments["quiet"] as? Bool ?? false
        let resolved = try resolvePaths(arguments: arguments, allowClipboard: allowClipboard)
        defer { cleanup(paths: resolved.cleanupPaths) }

        let report = AugeExecutionEngine.run(.init(mode: mode, filePaths: resolved.filePaths, options: options))
        return try toolResult(report: report, output: output.format, compact: output.compact, quiet: quiet)
    }

    private static func executeCompare(arguments: [String: Any]) throws -> [String: Any] {
        let options = AugeExecutionOptions()
        let output = try parseOutputFormat(arguments)
        let quiet = arguments["quiet"] as? Bool ?? false

        guard let pathA = arguments["pathA"] as? String, !pathA.isEmpty else {
            throw MCPProtocolError.invalidParams("pathA is required")
        }
        guard let pathB = arguments["pathB"] as? String, !pathB.isEmpty else {
            throw MCPProtocolError.invalidParams("pathB is required")
        }

        let report = AugeExecutionEngine.run(.init(mode: .compare, filePaths: [pathA, pathB], options: options))
        return try toolResult(report: report, output: output.format, compact: output.compact, quiet: quiet)
    }

    private static func configureOCR(_ options: inout AugeExecutionOptions, _ arguments: [String: Any]) throws {
        try configureSharedImageOptions(&options, arguments)
        if let autoLang = arguments["autoLang"] as? Bool { options.autoDetectLanguage = autoLang }
        if let fast = arguments["fast"] as? Bool { options.ocrFast = fast }
        if let noCorrect = arguments["noCorrect"] as? Bool { options.ocrNoCorrect = noCorrect }
        if let withBoxes = arguments["withBoxes"] as? Bool { options.ocrWithBoxes = withBoxes }
        if let vocabWords = try stringArray(arguments["vocabWords"], field: "vocabWords") {
            options.ocrCustomWords = vocabWords
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        if let vocabPath = arguments["vocabPath"] as? String, !vocabPath.isEmpty {
            let url = URL(fileURLWithPath: vocabPath)
            do {
                let raw = try String(contentsOf: url, encoding: .utf8)
                options.ocrCustomWords = raw
                    .split(whereSeparator: { $0.isNewline })
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            } catch {
                throw MCPProtocolError.invalidParams("Could not read vocabPath: \(error.localizedDescription)")
            }
        }
    }

    private static func configureClassification(_ options: inout AugeExecutionOptions, _ arguments: [String: Any]) throws {
        if let top = arguments["top"] as? Int {
            guard top > 0 else { throw MCPProtocolError.invalidParams("top must be positive") }
            options.topN = top
        }
        if let minConfidence = arguments["minConfidence"] as? Double {
            guard minConfidence >= 0 && minConfidence <= 1 else {
                throw MCPProtocolError.invalidParams("minConfidence must be between 0 and 1")
            }
            options.minConfidence = minConfidence
        } else if let minConfidenceNumber = arguments["minConfidence"] as? NSNumber {
            let value = minConfidenceNumber.doubleValue
            guard value >= 0 && value <= 1 else {
                throw MCPProtocolError.invalidParams("minConfidence must be between 0 and 1")
            }
            options.minConfidence = value
        }
    }

    private static func configureHumans(_ options: inout AugeExecutionOptions, _ arguments: [String: Any]) throws {
        if let upperBodyOnly = arguments["upperBodyOnly"] as? Bool {
            options.upperBodyOnly = upperBodyOnly
        }
    }

    private static func configureHandPose(_ options: inout AugeExecutionOptions, _ arguments: [String: Any]) throws {
        if let maxHands = arguments["maxHands"] as? Int {
            guard (1...4).contains(maxHands) else {
                throw MCPProtocolError.invalidParams("maxHands must be between 1 and 4")
            }
            options.maxHands = maxHands
        }
    }

    private static func configureAll(_ options: inout AugeExecutionOptions, _ arguments: [String: Any]) throws {
        try configureSharedImageOptions(&options, arguments)
        try configureClassification(&options, arguments)
        try configureHumans(&options, arguments)
        try configureHandPose(&options, arguments)
    }

    private static func configureSharedImageOptions(_ options: inout AugeExecutionOptions, _ arguments: [String: Any]) throws {
        if let dpi = arguments["dpi"] as? Int {
            guard (72...600).contains(dpi) else {
                throw MCPProtocolError.invalidParams("dpi must be between 72 and 600")
            }
            options.pdfDPI = dpi
        }
        if let preferEmbedded = arguments["preferEmbedded"] as? Bool {
            options.preferEmbedded = preferEmbedded
        }
        if let langs = try stringArray(arguments["langs"], field: "langs") {
            options.languageHints = langs
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        if let enhance = arguments["enhance"] as? Bool { options.enhanceImages = enhance }
        if let clean = arguments["clean"] as? Bool { options.cleanText = clean }
    }

    private static func parseOutputFormat(_ arguments: [String: Any]) throws -> (format: OutputFormat, compact: Bool) {
        let compact = arguments["compact"] as? Bool ?? false
        guard let raw = arguments["output"] as? String else {
            return (.plain, compact)
        }
        guard let format = OutputFormat(rawValue: raw) else {
            throw MCPProtocolError.invalidParams("output must be one of: plain, json, md, ndjson")
        }
        return (format, compact)
    }

    private static func resolvePaths(arguments: [String: Any], allowClipboard: Bool) throws -> (filePaths: [String], cleanupPaths: [String]) {
        var filePaths: [String] = []
        var cleanupPaths: [String] = []

        if let path = arguments["path"] as? String, !path.isEmpty {
            filePaths.append(path)
        }
        if let paths = try stringArray(arguments["paths"], field: "paths") {
            filePaths.append(contentsOf: paths.filter { !$0.isEmpty })
        }

        let useClipboard = arguments["clipboard"] as? Bool ?? false
        if useClipboard {
            guard allowClipboard else {
                throw MCPProtocolError.invalidParams("clipboard is not supported for this tool")
            }
            if !filePaths.isEmpty {
                throw MCPProtocolError.invalidParams("clipboard cannot be combined with path or paths")
            }
            do {
                let url = try Clipboard.readImage()
                filePaths.append(url.path)
                if url.lastPathComponent.hasPrefix("auge-clipboard-") {
                    cleanupPaths.append(url.path)
                }
            } catch let error as AugeError {
                throw MCPProtocolError.serverError(error.userMessage)
            } catch {
                throw MCPProtocolError.serverError(AugeError.classify(error).userMessage)
            }
        }

        guard !filePaths.isEmpty else {
            throw MCPProtocolError.invalidParams("Provide path, paths, or clipboard:true")
        }

        return (filePaths, cleanupPaths)
    }

    private static func toolResult(report: AugeExecutionReport, output: OutputFormat, compact: Bool, quiet: Bool) throws -> [String: Any] {
        let notices = quiet ? [] : report.notices
        let renderedResponses = report.responses.map { renderedResult(mode: $0.mode, file: $0.file, payload: $0.results, format: output, compact: compact) }
        let text = summaryText(renderedResponses: renderedResponses, notices: notices, failures: report.failures, outputFormat: output)

        let structured: [String: Any] = [
            "mode": report.mode.cliName,
            "responses": try report.responses.map { try encodeJSONObject($0) },
            "notices": notices.map {
                [
                    "kind": $0.kind.rawValue,
                    "file": $0.file ?? NSNull(),
                    "message": $0.message,
                ] as [String: Any]
            },
            "errors": report.failures.map {
                [
                    "file": $0.file ?? NSNull(),
                    "label": $0.error.cliLabel,
                    "message": $0.error.userMessage,
                    "exitCode": Int($0.error.exitCode),
                ] as [String: Any]
            },
            "rendered": renderedResponses,
        ]

        return [
            "content": [["type": "text", "text": text]],
            "structuredContent": structured,
            "isError": report.hasFailures,
        ]
    }

    private static func summaryText(renderedResponses: [String], notices: [AugeExecutionNotice], failures: [AugeExecutionFailure], outputFormat: OutputFormat) -> String {
        var parts: [String] = []
        parts.append(contentsOf: renderedResponses)
        if outputFormat != .json && outputFormat != .ndjson {
            parts.append(contentsOf: notices.map(\.message))
            parts.append(contentsOf: failures.map { "\($0.error.cliLabel) \($0.error.userMessage)" })
        }

        if parts.isEmpty {
            if outputFormat == .json || outputFormat == .ndjson {
                return ""
            }
            return "No output."
        }

        let separator = "\n"
        return parts.joined(separator: separator)
    }

    private static func requireRequestID(_ id: Any?, for method: String) throws {
        guard id != nil else {
            throw MCPProtocolError.invalidRequest("\(method) requires an id")
        }
    }

    private static func validateRequestID(_ id: Any?) throws -> Any? {
        guard let id else { return nil }

        switch id {
        case is Bool:
            throw MCPProtocolError.invalidRequest("id must be a string, number, or null")
        case is String, is NSNull, is NSNumber:
            return id
        default:
            throw MCPProtocolError.invalidRequest("id must be a string, number, or null")
        }
    }

    private static func requestObject(from value: Any?, field: String) throws -> [String: Any] {
        guard let value else { return [:] }
        guard let object = value as? [String: Any] else {
            throw MCPProtocolError.invalidParams("\(field) must be an object")
        }
        return object
    }

    private static func stringArray(_ value: Any?, field: String) throws -> [String]? {
        guard let value else { return nil }
        guard let array = value as? [Any] else {
            throw MCPProtocolError.invalidParams("\(field) must be an array of strings")
        }

        let strings = array.compactMap { $0 as? String }
        guard strings.count == array.count else {
            throw MCPProtocolError.invalidParams("\(field) must contain only strings")
        }

        return strings
    }

    private static func toolDefinitions() -> [[String: Any]] {
        var tools = AnalysisMode.mcpModes.map { toolDefinition(for: $0) }
        tools.append(releaseToolDefinition())
        return tools
    }

    private static func toolDefinition(for mode: AnalysisMode) -> [String: Any] {
        [
            "name": mode.toolName,
            "description": toolDescription(for: mode),
            "inputSchema": toolSchema(for: mode),
        ]
    }

    private static func releaseToolDefinition() -> [String: Any] {
        [
            "name": "auge_release",
            "description": "Return auge build metadata and supported capabilities.",
            "inputSchema": [
                "type": "object",
                "properties": [:],
                "additionalProperties": false,
            ],
        ]
    }

    private static func toolDescription(for mode: AnalysisMode) -> String {
        switch mode {
        case .ocr: return "Extract text from images or PDFs using Apple Vision OCR."
        case .classify: return "Classify image content and return labels with confidence."
        case .barcode: return "Detect QR codes and barcodes."
        case .faces: return "Detect faces and return bounding boxes."
        case .faceLandmarks: return "Detect 76-point face landmarks plus roll, yaw, and pitch."
        case .faceQuality: return "Score per-face capture quality."
        case .humans: return "Detect humans and return bounding boxes."
        case .textRectangles: return "Detect text regions without OCR."
        case .rectangles: return "Detect quadrilaterals such as paper, signs, and screens."
        case .horizon: return "Detect the image horizon angle."
        case .animals: return "Detect cats and dogs with labels and boxes."
        case .animalPose: return "Detect animal body pose joints."
        case .bodyPose: return "Detect human body pose joints."
        case .handPose: return "Detect hand pose keypoints."
        case .saliencyAttention: return "Return attention-based salient regions as boxes."
        case .saliencyObjectness: return "Return objectness-based salient regions as boxes."
        case .contours: return "Detect vector contours."
        case .featurePrint: return "Produce a Vision feature-print embedding."
        case .compare: return "Compare two images using Vision feature-print cosine distance."
        case .aesthetics: return "Score image aesthetics."
        case .smudge: return "Detect lens smudge confidence."
        case .document: return "Extract structured document content including paragraphs, lists, and tables."
        case .subject: return "Extract subject segmentation mask."
        case .personsMask: return "Extract person segmentation mask."
        case .model: return "Generate a 3D model from image."
        case .motion: return "Detect motion in image sequences."
        case .align: return "Align images."
        case .track: return "Track objects across frames."
        case .trajectories: return "Extract motion trajectories."
        case .video: return "Analyze video content."
        case .all: return "Run every auge analysis on each input and return a combined result."
        }
    }

    private static func toolSchema(for mode: AnalysisMode) -> [String: Any] {
        if mode == .compare {
            return [
                "type": "object",
                "properties": [
                    "pathA": ["type": "string", "description": "First image path."],
                    "pathB": ["type": "string", "description": "Second image path."],
                    "output": outputSchemaProperty(),
                    "compact": ["type": "boolean", "description": "When output=json, use compact JSON for rendered text."],
                    "quiet": ["type": "boolean", "description": "Suppress notices in the returned text and notice list."],
                ],
                "required": ["pathA", "pathB"],
                "additionalProperties": false,
            ]
        }

        var properties = basePathProperties()
        addRenderProperties(&properties)

        switch mode {
        case .ocr:
            addSharedImageOptions(&properties)
            properties["autoLang"] = ["type": "boolean", "description": "Auto-detect language instead of using langs."]
            properties["fast"] = ["type": "boolean", "description": "Use fast OCR recognition level."]
            properties["noCorrect"] = ["type": "boolean", "description": "Disable OCR language correction."]
            properties["withBoxes"] = ["type": "boolean", "description": "Include per-line bounding boxes and confidence in results."]
            properties["vocabPath"] = ["type": "string", "description": "Path to a custom OCR vocabulary file."]
            properties["vocabWords"] = ["type": "array", "items": ["type": "string"], "description": "Custom OCR vocabulary words."]

        case .classify:
            properties["top"] = ["type": "integer", "minimum": 1, "description": "Maximum classification results to keep."]
            properties["minConfidence"] = ["type": "number", "minimum": 0, "maximum": 1, "description": "Minimum confidence threshold."]

        case .humans:
            properties["upperBodyOnly"] = ["type": "boolean", "description": "Detect upper body only."]

        case .handPose:
            properties["maxHands"] = ["type": "integer", "minimum": 1, "maximum": 4, "description": "Maximum number of hands to detect."]

        case .all:
            addSharedImageOptions(&properties)
            properties["top"] = ["type": "integer", "minimum": 1, "description": "Maximum classification results to keep."]
            properties["minConfidence"] = ["type": "number", "minimum": 0, "maximum": 1, "description": "Minimum classification confidence threshold."]
            properties["upperBodyOnly"] = ["type": "boolean", "description": "When detecting humans, limit detection to upper bodies."]
            properties["maxHands"] = ["type": "integer", "minimum": 1, "maximum": 4, "description": "Maximum number of hands to detect."]

        case .barcode, .faces, .faceLandmarks, .faceQuality, .textRectangles, .rectangles, .horizon, .animals, .animalPose, .bodyPose, .saliencyAttention, .saliencyObjectness, .contours, .featurePrint, .aesthetics, .smudge, .document, .subject, .personsMask, .model, .motion, .align, .track, .trajectories, .video, .compare:
            break
        }

        return [
            "type": "object",
            "properties": properties,
            "additionalProperties": false,
        ]
    }

    private static func basePathProperties() -> [String: Any] {
        [
            "path": ["type": "string", "description": "Single image path."],
            "paths": ["type": "array", "items": ["type": "string"], "minItems": 1, "description": "One or more image paths."],
            "clipboard": ["type": "boolean", "description": "Read the input image from the macOS clipboard instead of a path."],
        ]
    }

    private static func addRenderProperties(_ properties: inout [String: Any]) {
        properties["output"] = outputSchemaProperty()
        properties["compact"] = ["type": "boolean", "description": "When output=json, use compact JSON for rendered text."]
        properties["quiet"] = ["type": "boolean", "description": "Suppress notices in the returned text and notice list."]
    }

    private static func addSharedImageOptions(_ properties: inout [String: Any]) {
        properties["dpi"] = ["type": "integer", "minimum": 72, "maximum": 600, "description": "PDF rasterization DPI."]
        properties["preferEmbedded"] = ["type": "boolean", "description": "Prefer PDF embedded text when present."]
        properties["langs"] = ["type": "array", "items": ["type": "string"], "description": "BCP-47 OCR language hints."]
        properties["enhance"] = ["type": "boolean", "description": "Upscale tiny images before OCR."]
        properties["clean"] = ["type": "boolean", "description": "Post-process OCR text with FoundationModels."]
    }

    private static func outputSchemaProperty() -> [String: Any] {
        [
            "type": "string",
            "enum": ["plain", "json", "md", "ndjson"],
            "description": "Rendered output format to include alongside structuredContent.",
        ]
    }

    private static func successResponse(id: Any?, result: Any) -> [String: Any] {
        [
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "result": result,
        ]
    }

    private static func errorResponse(id: Any?, error: MCPProtocolError) -> [String: Any] {
        [
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "error": [
                "code": error.code,
                "message": error.message,
            ],
        ]
    }

    private static func writeJSONObject(_ object: Any) throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private static func encodeJSONObject(_ value: some Encodable) throws -> Any {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data)
    }

    private static func cleanup(paths: [String]) {
        for path in paths {
            try? FileManager.default.removeItem(atPath: path)
        }
    }
}
