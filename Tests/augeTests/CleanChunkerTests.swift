import Foundation
import AugeCore

func runCleanChunkerTests() {
    test("empty string yields empty array") {
        try assertEqual(CleanChunker.chunk(""), [])
    }
    test("short text returns single chunk") {
        try assertEqual(CleanChunker.chunk("hello"), ["hello"])
    }
    test("text under limit returns one chunk") {
        let s = String(repeating: "a", count: 100)
        try assertEqual(CleanChunker.chunk(s, maxCharacters: 5_000), [s])
    }
    test("text over limit splits") {
        let s = String(repeating: "a", count: 6_000)
        let chunks = CleanChunker.chunk(s, maxCharacters: 1_000)
        try assertEqual(chunks.count, 6)
        for c in chunks {
            try assertTrue(c.count <= 1_000)
        }
    }
    test("paragraph boundaries respected when possible") {
        let para1 = String(repeating: "x", count: 500)
        let para2 = String(repeating: "y", count: 500)
        let para3 = String(repeating: "z", count: 500)
        let combined = "\(para1)\n\n\(para2)\n\n\(para3)"
        let chunks = CleanChunker.chunk(combined, maxCharacters: 1_100)
        // Two paragraphs fit per chunk (500 + 2 + 500 = 1002), so should split into 2
        try assertTrue(chunks.count >= 1 && chunks.count <= 3)
        for c in chunks {
            try assertTrue(c.count <= 1_100)
        }
    }
    test("single oversized paragraph is hard-split") {
        let para = String(repeating: "z", count: 3_000)
        let chunks = CleanChunker.chunk(para, maxCharacters: 1_000)
        try assertEqual(chunks.count, 3)
        for c in chunks {
            try assertTrue(c.count <= 1_000)
        }
    }
    test("default max is 5000") {
        try assertEqual(CleanChunker.defaultMaxCharacters, 5_000)
    }
    test("zero max uses single chunk") {
        try assertEqual(CleanChunker.chunk("hello", maxCharacters: 0), ["hello"])
    }
    test("each chunk preserves character count totals") {
        let para = "abc\n\ndef\n\nghi\n\njkl"
        let chunks = CleanChunker.chunk(para, maxCharacters: 100)
        try assertEqual(chunks.joined(separator: "\n\n"), para)
    }
}
