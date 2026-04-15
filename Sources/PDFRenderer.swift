// ============================================================================
// PDFRenderer.swift — Render PDF pages to CGImage for Vision processing
// Part of auge — Apple Vision from the command line
// ============================================================================

import Foundation
import PDFKit
import CoreGraphics
import AugeCore

enum PDFRenderer {
    /// Render all pages of a PDF to CGImages at 300 DPI.
    static func renderPages(at url: URL) throws -> [CGImage] {
        guard let document = PDFDocument(url: url) else {
            throw AugeError.pdfRenderFailure("Could not open PDF at \(url.path)")
        }
        guard document.pageCount > 0 else {
            throw AugeError.pdfRenderFailure("PDF has no pages")
        }

        let dpi: CGFloat = 300
        let scale = dpi / 72.0

        var images: [CGImage] = []
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let width = Int(bounds.width * scale)
            let height = Int(bounds.height * scale)

            guard width > 0, height > 0 else { continue }

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }

            // White background (PDFs assume white paper)
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))

            context.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context)

            guard let image = context.makeImage() else { continue }
            images.append(image)
        }

        guard !images.isEmpty else {
            throw AugeError.pdfRenderFailure("Could not render any pages")
        }
        return images
    }
}
