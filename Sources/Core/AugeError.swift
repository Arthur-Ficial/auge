import Foundation

public enum AugeError: Error, Equatable, Sendable {
    case fileNotFound(String)
    case invalidImage
    case unsupportedFormat(String)
    case visionUnavailable
    case noTextFound
    case noResults
    case clipboardEmpty
    case networkBlocked(String)
    case unknown(String)

    /// Classify any thrown error into a typed AugeError.
    /// Matches on Vision framework errors first, falls back to string matching.
    public static func classify(_ error: Error) -> AugeError {
        if let already = error as? AugeError { return already }

        let desc = error.localizedDescription.lowercased()

        if desc.contains("no such file") || desc.contains("file not found") || desc.contains("doesn't exist") {
            return .fileNotFound(error.localizedDescription)
        }
        if desc.contains("could not be decoded") || desc.contains("invalid image") || desc.contains("corrupt") {
            return .invalidImage
        }
        if desc.contains("unsupported") && (desc.contains("format") || desc.contains("image")) {
            return .unsupportedFormat(error.localizedDescription)
        }
        if desc.contains("vision") && (desc.contains("not available") || desc.contains("unavailable")) {
            return .visionUnavailable
        }
        return .unknown(error.localizedDescription)
    }

    public var cliLabel: String {
        switch self {
        case .fileNotFound:       return "[file not found]"
        case .invalidImage:       return "[invalid image]"
        case .unsupportedFormat:  return "[unsupported format]"
        case .visionUnavailable:  return "[vision unavailable]"
        case .noTextFound:        return "[no text found]"
        case .noResults:          return "[no results]"
        case .clipboardEmpty:     return "[clipboard empty]"
        case .networkBlocked:     return "[network blocked]"
        case .unknown:            return "[error]"
        }
    }

    public var exitCode: Int32 {
        switch self {
        case .fileNotFound:       return 1
        case .invalidImage:       return 1
        case .unsupportedFormat:  return 1
        case .visionUnavailable:  return 5
        case .noTextFound:        return 0
        case .noResults:          return 0
        case .clipboardEmpty:     return 1
        case .networkBlocked:     return 2
        case .unknown:            return 1
        }
    }

    public var userMessage: String {
        switch self {
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .invalidImage:
            return "The file is not a valid image or could not be decoded."
        case .unsupportedFormat(let fmt):
            return "Unsupported image format: \(fmt). Use PNG, JPEG, TIFF, BMP, GIF, HEIC, or PDF."
        case .visionUnavailable:
            return "Apple Vision framework is not available on this system."
        case .noTextFound:
            return "No text was detected in the image."
        case .noResults:
            return "No results were detected in the image."
        case .clipboardEmpty:
            return "Clipboard does not contain a PNG, JPEG, HEIC, TIFF image, or a file URL."
        case .networkBlocked(let url):
            return "Network call blocked (auge is on-device only): \(url)"
        case .unknown(let msg):
            return msg
        }
    }
}
