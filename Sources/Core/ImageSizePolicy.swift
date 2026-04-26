import Foundation

/// Pure-logic resize policy for OCR preprocessing.
/// - Always cap the long edge at `maxLongEdge` (large images slow OCR with no quality benefit).
/// - When `enhance` is true and the long edge is below `tinyLongEdge`, upscale to
///   `enhancedLongEdge` (capped at 2x — anything more is meaningless for OCR).
public enum ImageSizePolicy {
    public static let maxLongEdge: Int = 2_400
    public static let tinyLongEdge: Int = 1_200
    public static let enhancedLongEdge: Int = 1_600

    /// Compute the resize target for a given source size.
    /// Returns nil if the image already fits the policy and no resize is needed.
    public static func target(width: Int, height: Int, enhance: Bool) -> (width: Int, height: Int)? {
        let longEdge = max(width, height)
        guard longEdge > 0 else { return nil }

        if longEdge > maxLongEdge {
            let scale = Double(maxLongEdge) / Double(longEdge)
            return scaled(width: width, height: height, by: scale)
        }

        if enhance && longEdge < tinyLongEdge {
            let scale = min(Double(enhancedLongEdge) / Double(longEdge), 2.0)
            return scaled(width: width, height: height, by: scale)
        }

        return nil
    }

    private static func scaled(width: Int, height: Int, by scale: Double) -> (width: Int, height: Int) {
        let w = max(1, Int((Double(width) * scale).rounded()))
        let h = max(1, Int((Double(height) * scale).rounded()))
        return (w, h)
    }
}
