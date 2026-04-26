// ============================================================================
// Clipboard.swift — Read an image from NSPasteboard.
// Writes the raw bytes to a temp file and returns the URL so the rest of
// auge can treat it like any other file input.
// ============================================================================

import AppKit
import Foundation
import AugeCore

enum Clipboard {
    /// Read the first available image off the pasteboard.
    /// Returns a URL pointing to a freshly written temp file with the right extension.
    /// Throws `.clipboardEmpty` if no image data and no file URL is present.
    static func readImage() throws -> URL {
        let pb = NSPasteboard.general

        let candidates: [(NSPasteboard.PasteboardType, String)] = [
            (.png, "png"),
            (NSPasteboard.PasteboardType("public.jpeg"), "jpg"),
            (NSPasteboard.PasteboardType("public.heic"), "heic"),
            (NSPasteboard.PasteboardType("public.heif"), "heif"),
            (.tiff, "tiff"),
        ]

        for (type, ext) in candidates {
            if let data = pb.data(forType: type), !data.isEmpty {
                return try writeTemp(data: data, ext: ext)
            }
        }

        // Fallback: pasteboard contains a file URL (e.g., copied a file in Finder)
        if let urlString = pb.string(forType: .fileURL),
           let url = URL(string: urlString),
           url.isFileURL,
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        throw AugeError.clipboardEmpty
    }

    private static func writeTemp(data: Data, ext: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("auge-clipboard-\(UUID().uuidString).\(ext)")
        do {
            try data.write(to: url)
        } catch {
            throw AugeError.unknown("could not write clipboard image to temp file: \(error.localizedDescription)")
        }
        return url
    }
}
