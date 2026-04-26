// ============================================================================
// PDFProcessor.swift — PDF input handling via PDFKit.
// Embedded text layer when present (fast, no OCR); rasterize otherwise.
// ============================================================================

@preconcurrency import AppKit
@preconcurrency import CoreGraphics
@preconcurrency import PDFKit
import Foundation
import AugeCore

enum PDFProcessor {
    struct Configuration: Sendable {
        var dpi: Int
        var preferEmbedded: Bool

        init(dpi: Int = 200, preferEmbedded: Bool = true) {
            self.dpi = dpi
            self.preferEmbedded = preferEmbedded
        }
    }

    /// One page of a PDF, post-processing.
    enum PageContent {
        /// PDF text layer extracted directly — no OCR needed.
        case embeddedText(String)
        /// Rasterized page image, ready for Vision OCR.
        case rasterImage(CGImage)
    }

    /// Open the PDF and return content for each page.
    /// Embedded text is preferred when `config.preferEmbedded` is true and the page has a text layer.
    static func process(url: URL, config: Configuration) throws -> [PageContent] {
        guard let document = PDFDocument(url: url) else {
            throw AugeError.invalidImage
        }
        if document.isEncrypted && !document.unlock(withPassword: "") {
            throw AugeError.unknown("encrypted PDF requires a password")
        }
        guard document.pageCount > 0 else {
            throw AugeError.invalidImage
        }

        var pages: [PageContent] = []
        pages.reserveCapacity(document.pageCount)

        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else {
                throw AugeError.invalidImage
            }

            let embedded = (page.string ?? "")
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if config.preferEmbedded && !embedded.isEmpty {
                pages.append(.embeddedText(embedded))
            } else {
                let image = try rasterize(page: page, dpi: config.dpi)
                pages.append(.rasterImage(image))
            }
        }

        return pages
    }

    private static func rasterize(page: PDFPage, dpi: Int) throws -> CGImage {
        // Use PDFKit's built-in thumbnail API — handles page rotation, media box,
        // and coordinate flipping correctly across all PDF variants.
        let bounds = page.bounds(for: .mediaBox)
        let scale = CGFloat(dpi) / 72.0
        let pixelWidth = max(1, bounds.width * scale)
        let pixelHeight = max(1, bounds.height * scale)
        let size = NSSize(width: pixelWidth, height: pixelHeight)

        let nsImage = page.thumbnail(of: size, for: .mediaBox)
        guard let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let cgImage = rep.cgImage else {
            throw AugeError.unknown("could not rasterize PDF page")
        }
        return cgImage
    }
}
