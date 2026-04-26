import Foundation
import AugeCore

func runLineMergerTests() {
    test("empty input returns empty") {
        try assertEqual(LineMerger.merge([]), [])
    }
    test("single run pass-through") {
        try assertEqual(LineMerger.merge([["a", "b", "c"]]), ["a", "b", "c"])
    }
    test("two runs no overlap merges in order") {
        try assertEqual(LineMerger.merge([["a", "b"], ["c", "d"]]), ["a", "b", "c", "d"])
    }
    test("dedupe across runs keeps first seen") {
        try assertEqual(LineMerger.merge([["a", "b"], ["b", "c"]]), ["a", "b", "c"])
    }
    test("dedupe within single run") {
        try assertEqual(LineMerger.merge([["a", "a", "b"]]), ["a", "b"])
    }
    test("empty runs are no-ops") {
        try assertEqual(LineMerger.merge([[], ["a"], [], ["b"]]), ["a", "b"])
    }
    test("realistic multi-script Macau case") {
        // Pass 1 (en-US) — Latin only
        let en = ["Hotels", "Information", "Travel Agencies"]
        // Pass 2 (pt-PT) — accented Portuguese, plus Latin re-detection
        let pt = ["Hotéis", "Hotels", "Informações", "Information", "Agências de Viagens", "Travel Agencies"]
        // Pass 3 (zh-Hant) — Chinese + Latin re-detection
        let zh = ["Hotéis", "酒店", "Hotels", "Informações", "詢問處", "旅行案內所", "Information", "Agências de Viagens", "旅行社", "旅行代理店", "Travel Agencies"]
        let merged = LineMerger.merge([en, pt, zh])
        // All three scripts must appear
        try assertTrue(merged.contains("Hotels"))
        try assertTrue(merged.contains("Hotéis"))
        try assertTrue(merged.contains("酒店"))
        try assertTrue(merged.contains("詢問處"))
        try assertTrue(merged.contains("旅行社"))
        // No duplicates
        try assertEqual(merged.count, Set(merged).count)
    }
    test("different runs same content collapses to one") {
        try assertEqual(LineMerger.merge([["x"], ["x"], ["x"]]), ["x"])
    }
    test("whitespace-different lines kept separate") {
        // exact-string dedupe — leading/trailing space changes mean different line
        let merged = LineMerger.merge([["abc", "abc "]])
        try assertEqual(merged.count, 2)
    }
    test("preserves first-run order for duplicates") {
        // 'b' first appears in run 1, position 1; merged 'b' should be at position 1 not 2
        let merged = LineMerger.merge([["a", "b", "c"], ["x", "b", "y"]])
        try assertEqual(merged, ["a", "b", "c", "x", "y"])
    }
    test("unicode emoji line treated like any string") {
        try assertEqual(LineMerger.merge([["hi 👋", "hi"], ["hi 👋"]]), ["hi 👋", "hi"])
    }
    test("RTL Hebrew line preserved") {
        let merged = LineMerger.merge([["שלום"], ["שלום", "Hello"]])
        try assertEqual(merged, ["שלום", "Hello"])
    }
}
