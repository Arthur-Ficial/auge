import Foundation
import AugeCore

let version = buildVersion
let appName = "auge"

package let exitSuccess: Int32 = 0
package let exitRuntimeError: Int32 = 1
package let exitUsageError: Int32 = 2
package let exitVisionUnavailable: Int32 = 5

func exitCode(for error: AugeError) -> Int32 { error.exitCode }

package struct AugeReleaseCapability: Encodable, Sendable {
    package let id: String
    package let summary: String
}

package struct AugeReleaseInfo: Encodable, Sendable {
    package let version: String
    package let commit: String
    package let branch: String
    package let built: String
    package let swift: String
    package let os: String
    package let framework: String
    package let requires: String
    package let formats: [String]
    package let outputFormats: [String]
    package let capabilities: [AugeReleaseCapability]
}

package func makeReleaseInfo() -> AugeReleaseInfo {
    AugeReleaseInfo(
        version: version,
        commit: buildCommit,
        branch: buildBranch,
        built: buildDate,
        swift: buildSwiftVersion,
        os: buildOS,
        framework: "Vision (macOS 26 Tahoe baseline)",
        requires: "macOS 26 (Tahoe)",
        formats: ["PNG", "JPEG", "TIFF", "BMP", "GIF", "HEIC", "PDF"],
        outputFormats: ["plain", "json", "md", "ndjson"],
        capabilities: [
            .init(id: "ocr", summary: "text recognition (accurate + fast modes)"),
            .init(id: "classify", summary: "image classification (1000+ categories)"),
            .init(id: "barcode", summary: "QR codes, EAN, Code128, and more"),
            .init(id: "faces", summary: "detection / landmarks (76 pts) / capture quality"),
            .init(id: "bodies", summary: "human rectangles, body pose, hand pose"),
            .init(id: "animals", summary: "cats / dogs / animal pose"),
            .init(id: "geometry", summary: "rectangles, horizon, contours, text rectangles"),
            .init(id: "saliency", summary: "attention + objectness (boxes only, never heatmap)"),
            .init(id: "embeddings", summary: "feature-print + compare (cosine distance)"),
            .init(id: "document", summary: "structured document extraction"),
            .init(id: "aesthetics", summary: "overall image aesthetics score"),
            .init(id: "smudge", summary: "lens smudge confidence"),
            .init(id: "masks", summary: "subject lift + persons mask"),
        ]
    )
}
