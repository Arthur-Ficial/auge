import Foundation

/// Pure-logic chunker for the `--clean` post-pass.
/// FoundationModels has practical limits per request; we split long inputs by paragraph,
/// staying under `maxCharacters` per chunk and only hard-splitting if a single paragraph exceeds it.
public enum CleanChunker {
    public static let defaultMaxCharacters: Int = 5_000

    public static func chunk(_ string: String, maxCharacters: Int = defaultMaxCharacters) -> [String] {
        guard maxCharacters > 0 else { return [string] }
        guard string.count > maxCharacters else { return string.isEmpty ? [] : [string] }

        var chunks: [String] = []
        var current = ""

        for paragraph in string.components(separatedBy: "\n\n") {
            if current.count + paragraph.count + 2 <= maxCharacters {
                current += current.isEmpty ? paragraph : "\n\n\(paragraph)"
            } else {
                if !current.isEmpty {
                    chunks.append(current)
                    current = ""
                }
                if paragraph.count <= maxCharacters {
                    current = paragraph
                } else {
                    chunks.append(contentsOf: hardChunks(paragraph, maxCharacters: maxCharacters))
                }
            }
        }

        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks
    }

    private static func hardChunks(_ string: String, maxCharacters: Int) -> [String] {
        var out: [String] = []
        var start = string.startIndex
        while start < string.endIndex {
            let end = string.index(start, offsetBy: maxCharacters, limitedBy: string.endIndex) ?? string.endIndex
            out.append(String(string[start..<end]))
            start = end
        }
        return out
    }
}
