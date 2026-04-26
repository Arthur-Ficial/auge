// ============================================================================
// ImagePreprocessor.swift — Resize images before OCR per ImageSizePolicy.
// Caps oversized images for speed; upscales tiny images when --enhance is set.
// ============================================================================

@preconcurrency import CoreGraphics
@preconcurrency import ImageIO
import Foundation
import AugeCore

enum ImagePreprocessor {
    /// Load the image at `url` and return a CGImage, applying the resize policy.
    /// Returns the original CGImage if no resize is needed.
    static func load(url: URL, enhance: Bool) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw AugeError.invalidImage
        }
        return try apply(image, enhance: enhance)
    }

    /// Apply the size policy to an existing CGImage.
    static func apply(_ image: CGImage, enhance: Bool) throws -> CGImage {
        guard let target = ImageSizePolicy.target(
            width: image.width,
            height: image.height,
            enhance: enhance
        ) else {
            return image
        }

        // Choose interpolation: medium when downscaling, high when upscaling.
        let isDownscale = target.width <= image.width
        let quality: CGInterpolationQuality = isDownscale ? .medium : .high

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: target.width,
            height: target.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw AugeError.unknown("could not allocate resize context")
        }

        context.interpolationQuality = quality
        context.draw(image, in: CGRect(x: 0, y: 0, width: target.width, height: target.height))

        guard let resized = context.makeImage() else {
            throw AugeError.unknown("could not create resized image")
        }
        return resized
    }
}
