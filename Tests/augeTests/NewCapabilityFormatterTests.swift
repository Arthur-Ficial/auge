// NewCapabilityFormatterTests.swift
// Validates the new v1.2 capability formatters produce sensible output and that
// the result types Codable-encode round-trip cleanly via JSONEncoder.

import Foundation
import AugeCore

func runNewCapabilityFormatterTests() {
    test("HorizonResult derives degrees from radians") {
        let h = HorizonResult(angleRadians: .pi / 4)
        try assertTrue(abs(h.angleDegrees - 45.0) < 1e-9)
    }

    test("formatHorizon nil → 'no horizon detected'") {
        try assertEqual(ResultFormatter.formatHorizon(nil), "no horizon detected")
    }

    test("markdownHorizon non-nil contains angle") {
        let h = HorizonResult(angleRadians: 0.5)
        let md = ResultFormatter.markdownHorizon(h)
        try assertTrue(md.contains("horizon angle"))
    }

    test("formatRectangles empty → '0 rectangles detected'") {
        try assertEqual(ResultFormatter.formatRectangles([]), "0 rectangles detected")
    }

    test("formatRectangles non-empty includes confidence") {
        let r = RectangleResult(
            topLeft: PointResult(x: 0, y: 1),
            topRight: PointResult(x: 1, y: 1),
            bottomLeft: PointResult(x: 0, y: 0),
            bottomRight: PointResult(x: 1, y: 0),
            confidence: 0.85
        )
        let s = ResultFormatter.formatRectangles([r])
        try assertTrue(s.contains("0.850"))
        try assertTrue(s.contains("rect 1"))
    }

    test("formatHumans 0 → '0 humans detected'") {
        try assertEqual(ResultFormatter.formatHumans([]), "0 humans detected")
    }

    test("formatHumans bbox formatted") {
        let h = HumanResult(x: 0.1, y: 0.2, width: 0.3, height: 0.4, confidence: 0.9, upperBodyOnly: false)
        let s = ResultFormatter.formatHumans([h])
        try assertTrue(s.contains("human 1"))
        try assertTrue(s.contains("0.900"))
    }

    test("formatTextRectangles 0 → '0 text regions detected'") {
        try assertEqual(ResultFormatter.formatTextRectangles([]), "0 text regions detected")
    }

    test("formatAnimals 0 → '0 animals detected'") {
        try assertEqual(ResultFormatter.formatAnimals([]), "0 animals detected")
    }

    test("formatAnimals includes label and percent") {
        let a = AnimalResult(label: "Cat", confidence: 0.95, x: 0, y: 0, width: 1, height: 1)
        let s = ResultFormatter.formatAnimals([a])
        try assertTrue(s.contains("Cat"))
        try assertTrue(s.contains("95%"))
    }

    test("formatBodyPose includes joint count") {
        let b = BodyPoseResult(joints: [
            PoseJoint(name: "nose", x: 0.5, y: 0.5, confidence: 0.9),
            PoseJoint(name: "neck", x: 0.5, y: 0.4, confidence: 0.85),
        ])
        let s = ResultFormatter.formatBodyPose([b])
        try assertTrue(s.contains("2 joints"))
    }

    test("formatHandPose mentions chirality") {
        let h = HandPoseResult(chirality: "left", joints: [])
        let s = ResultFormatter.formatHandPose([h])
        try assertTrue(s.contains("left"))
    }

    test("formatSaliency 0 regions") {
        try assertEqual(ResultFormatter.formatSaliency([]), "0 salient regions")
    }

    test("formatContours summarises counts") {
        let c = ContoursResult(contourCount: 100, topLevelCount: 10, paths: [])
        let s = ResultFormatter.formatContours(c)
        try assertTrue(s.contains("100"))
        try assertTrue(s.contains("10 top-level"))
    }

    test("formatFeaturePrint shows dimension") {
        let fp = FeaturePrintResult(dimension: 768, elementType: "float", vector: Array(repeating: 0.1, count: 768))
        let s = ResultFormatter.formatFeaturePrint(fp)
        try assertTrue(s.contains("768"))
        try assertTrue(s.contains("float"))
    }

    test("formatCompare distance prefixes label") {
        let c = CompareResult(fileA: "a.jpg", fileB: "b.jpg", distance: 0.12345)
        let s = ResultFormatter.formatCompare(c)
        try assertTrue(s.hasPrefix("distance:"))
    }

    test("ContourPath stores point count") {
        let p = ContourPath(points: [PointResult(x: 0, y: 0), PointResult(x: 1, y: 1)])
        try assertEqual(p.pointCount, 2)
    }

    test("FaceLandmarksFace encodes landmarks dict") {
        let f = FaceLandmarksFace(
            x: 0, y: 0, width: 1, height: 1,
            roll: 0.1, yaw: 0.2, pitch: 0.3,
            landmarks: ["leftEye": [PointResult(x: 0.5, y: 0.5)]]
        )
        let data = try JSONEncoder().encode(f)
        let json = String(data: data, encoding: .utf8) ?? ""
        try assertTrue(json.contains("\"leftEye\""))
        try assertTrue(json.contains("\"roll\""))
    }

    test("CompareResult round-trips via Codable") {
        let c = CompareResult(fileA: "a", fileB: "b", distance: 1.5)
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(CompareResult.self, from: data)
        try assertEqual(decoded.fileA, "a")
        try assertEqual(decoded.fileB, "b")
        try assertEqual(decoded.distance, 1.5)
    }

    test("FeaturePrintResult round-trips via Codable") {
        let fp = FeaturePrintResult(dimension: 4, elementType: "float", vector: [1.0, 2.0, 3.0, 4.0])
        let data = try JSONEncoder().encode(fp)
        let decoded = try JSONDecoder().decode(FeaturePrintResult.self, from: data)
        try assertEqual(decoded.dimension, 4)
        try assertEqual(decoded.vector.count, 4)
    }

    test("ContoursResult round-trips via Codable") {
        let c = ContoursResult(contourCount: 5, topLevelCount: 2, paths: [
            ContourPath(points: [PointResult(x: 0, y: 0)])
        ])
        let data = try JSONEncoder().encode(c)
        let decoded = try JSONDecoder().decode(ContoursResult.self, from: data)
        try assertEqual(decoded.contourCount, 5)
        try assertEqual(decoded.paths.count, 1)
    }

    test("Saliency markdown for empty regions") {
        try assertEqual(ResultFormatter.markdownSaliency([]), "**0 salient regions**")
    }

    test("FeaturePrint markdown contains First 8 preview") {
        let fp = FeaturePrintResult(dimension: 16, elementType: "float", vector: Array(repeating: 0.5, count: 16))
        let md = ResultFormatter.markdownFeaturePrint(fp)
        try assertTrue(md.contains("First 8"))
    }

    // MARK: Tahoe-only payloads

    test("formatAesthetics shows utility flag") {
        let utility = AestheticsResult(overall: 0.5, isUtility: true)
        let memorable = AestheticsResult(overall: 0.8, isUtility: false)
        try assertTrue(ResultFormatter.formatAesthetics(utility).contains("utility"))
        try assertTrue(ResultFormatter.formatAesthetics(memorable).contains("memorable"))
    }

    test("AestheticsResult round-trips Codable") {
        let a = AestheticsResult(overall: 0.42, isUtility: false)
        let data = try JSONEncoder().encode(a)
        let decoded = try JSONDecoder().decode(AestheticsResult.self, from: data)
        try assertEqual(decoded.overall, 0.42)
        try assertEqual(decoded.isUtility, false)
    }

    test("formatSmudge prefixes label") {
        let s = SmudgeResult(confidence: 0.123)
        try assertTrue(ResultFormatter.formatSmudge(s).hasPrefix("smudge confidence"))
    }

    test("SmudgeResult round-trips Codable") {
        let s = SmudgeResult(confidence: 0.99)
        let data = try JSONEncoder().encode(s)
        let decoded = try JSONDecoder().decode(SmudgeResult.self, from: data)
        try assertEqual(decoded.confidence, 0.99)
    }

    test("formatDocument nil → 'no document detected'") {
        try assertEqual(ResultFormatter.formatDocument(nil), "no document detected")
    }

    test("formatDocument returns full text") {
        let d = DocumentResult(
            text: "Hello\n\nWorld",
            paragraphs: [DocumentParagraph(text: "Hello"), DocumentParagraph(text: "World")],
            lists: [], tables: [],
            urls: [], emails: [], phones: []
        )
        try assertEqual(ResultFormatter.formatDocument(d), "Hello\n\nWorld")
    }

    test("DocumentResult round-trips Codable with empty extras") {
        let d = DocumentResult(text: "x", paragraphs: [], lists: [], tables: [], urls: [], emails: [], phones: [])
        let data = try JSONEncoder().encode(d)
        let decoded = try JSONDecoder().decode(DocumentResult.self, from: data)
        try assertEqual(decoded.text, "x")
    }

    test("DocumentTable encodes row/column counts") {
        let t = DocumentTable(rowCount: 2, columnCount: 3, cells: [["a","b","c"],["d","e","f"]])
        let data = try JSONEncoder().encode(t)
        let decoded = try JSONDecoder().decode(DocumentTable.self, from: data)
        try assertEqual(decoded.rowCount, 2)
        try assertEqual(decoded.columnCount, 3)
        try assertEqual(decoded.cells.count, 2)
    }
}
