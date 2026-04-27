import Foundation

public enum ResultFormatter {
    // MARK: OCR

    public static func formatOCR(_ lines: [String]) -> String {
        lines.joined(separator: "\n")
    }

    public static func markdownOCR(_ lines: [String]) -> String {
        lines.joined(separator: "\n")
    }

    // MARK: Classification

    public static func formatClassification(_ results: [ClassificationResult]) -> String {
        guard !results.isEmpty else { return "" }
        let sorted = results.sorted { $0.confidence > $1.confidence }
        return sorted.map { result in
            let pct = Int(result.confidence * 100)
            return "\(result.label): \(pct)%"
        }.joined(separator: "\n")
    }

    public static func markdownClassification(_ results: [ClassificationResult]) -> String {
        guard !results.isEmpty else { return "" }
        let sorted = results.sorted { $0.confidence > $1.confidence }
        return sorted.map { r in
            let pct = Int(r.confidence * 100)
            return "- **\(r.label)** — \(pct)%"
        }.joined(separator: "\n")
    }

    // MARK: Barcodes

    public static func formatBarcodes(_ results: [BarcodeResult]) -> String {
        guard !results.isEmpty else { return "" }
        return results.map { result in
            "[\(result.symbology)] \(result.payload)"
        }.joined(separator: "\n")
    }

    public static func markdownBarcodes(_ results: [BarcodeResult]) -> String {
        guard !results.isEmpty else { return "" }
        return results.map { r in
            "- `\(r.symbology)`: \(r.payload)"
        }.joined(separator: "\n")
    }

    // MARK: Faces (rectangles)

    public static func formatFaces(_ results: [FaceResult]) -> String {
        let count = results.count
        let noun = count == 1 ? "face" : "faces"
        return "\(count) \(noun) detected"
    }

    public static func markdownFaces(_ results: [FaceResult]) -> String {
        let count = results.count
        let noun = count == 1 ? "face" : "faces"
        if results.isEmpty {
            return "**0 faces detected**"
        }
        let header = "**\(count) \(noun) detected**"
        let bullets = results.enumerated().map { (i, f) in
            String(format: "- face %d: x=%.3f y=%.3f w=%.3f h=%.3f", i + 1, f.x, f.y, f.width, f.height)
        }
        return ([header] + bullets).joined(separator: "\n")
    }

    // MARK: Face landmarks

    public static func formatFaceLandmarks(_ faces: [FaceLandmarksFace]) -> String {
        if faces.isEmpty { return "0 faces detected" }
        var lines: [String] = ["\(faces.count) face\(faces.count == 1 ? "" : "s") with landmarks"]
        for (i, f) in faces.enumerated() {
            lines.append(String(format: "face %d: bbox x=%.3f y=%.3f w=%.3f h=%.3f", i + 1, f.x, f.y, f.width, f.height))
            if let r = f.roll, let y = f.yaw, let p = f.pitch {
                lines.append(String(format: "  pose roll=%.2f° yaw=%.2f° pitch=%.2f°",
                                    r * 180 / .pi, y * 180 / .pi, p * 180 / .pi))
            }
            for (region, points) in f.landmarks.sorted(by: { $0.key < $1.key }) {
                lines.append("  \(region): \(points.count) points")
            }
        }
        return lines.joined(separator: "\n")
    }

    public static func markdownFaceLandmarks(_ faces: [FaceLandmarksFace]) -> String {
        if faces.isEmpty { return "**0 faces detected**" }
        var lines: [String] = ["**\(faces.count) face\(faces.count == 1 ? "" : "s") with landmarks**"]
        for (i, f) in faces.enumerated() {
            lines.append("- face \(i + 1)")
            lines.append(String(format: "  - bbox: x=%.3f y=%.3f w=%.3f h=%.3f", f.x, f.y, f.width, f.height))
            if let r = f.roll, let y = f.yaw, let p = f.pitch {
                lines.append(String(format: "  - pose: roll=%.2f° yaw=%.2f° pitch=%.2f°",
                                    r * 180 / .pi, y * 180 / .pi, p * 180 / .pi))
            }
            for (region, points) in f.landmarks.sorted(by: { $0.key < $1.key }) {
                lines.append("  - `\(region)`: \(points.count) points")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: Face quality

    public static func formatFaceQuality(_ faces: [FaceQualityResult]) -> String {
        if faces.isEmpty { return "0 faces detected" }
        let lines = faces.enumerated().map { (i, f) in
            String(format: "face %d: quality=%.3f bbox=(%.3f,%.3f,%.3f,%.3f)", i + 1, f.quality, f.x, f.y, f.width, f.height)
        }
        return lines.joined(separator: "\n")
    }

    public static func markdownFaceQuality(_ faces: [FaceQualityResult]) -> String {
        if faces.isEmpty { return "**0 faces detected**" }
        let header = "**\(faces.count) face\(faces.count == 1 ? "" : "s")**"
        let bullets = faces.enumerated().map { (i, f) in
            String(format: "- face %d — quality `%.3f` — bbox=(%.3f,%.3f,%.3f,%.3f)", i + 1, f.quality, f.x, f.y, f.width, f.height)
        }
        return ([header] + bullets).joined(separator: "\n")
    }

    // MARK: Humans

    public static func formatHumans(_ humans: [HumanResult]) -> String {
        if humans.isEmpty { return "0 humans detected" }
        let lines = humans.enumerated().map { (i, h) in
            String(format: "human %d: confidence=%.3f bbox=(%.3f,%.3f,%.3f,%.3f)", i + 1, h.confidence, h.x, h.y, h.width, h.height)
        }
        return lines.joined(separator: "\n")
    }

    public static func markdownHumans(_ humans: [HumanResult]) -> String {
        if humans.isEmpty { return "**0 humans detected**" }
        let header = "**\(humans.count) human\(humans.count == 1 ? "" : "s") detected**"
        let bullets = humans.enumerated().map { (i, h) in
            String(format: "- human %d — confidence `%.3f` — bbox=(%.3f,%.3f,%.3f,%.3f)", i + 1, h.confidence, h.x, h.y, h.width, h.height)
        }
        return ([header] + bullets).joined(separator: "\n")
    }

    // MARK: Text rectangles

    public static func formatTextRectangles(_ rects: [TextRectangleResult]) -> String {
        if rects.isEmpty { return "0 text regions detected" }
        let lines = rects.enumerated().map { (i, r) in
            String(format: "region %d: confidence=%.3f bbox=(%.3f,%.3f,%.3f,%.3f)", i + 1, r.confidence, r.x, r.y, r.width, r.height)
        }
        return lines.joined(separator: "\n")
    }

    public static func markdownTextRectangles(_ rects: [TextRectangleResult]) -> String {
        if rects.isEmpty { return "**0 text regions detected**" }
        let header = "**\(rects.count) text region\(rects.count == 1 ? "" : "s")**"
        let bullets = rects.enumerated().map { (i, r) in
            String(format: "- region %d — confidence `%.3f` — bbox=(%.3f,%.3f,%.3f,%.3f)", i + 1, r.confidence, r.x, r.y, r.width, r.height)
        }
        return ([header] + bullets).joined(separator: "\n")
    }

    // MARK: Rectangles (quadrilaterals)

    public static func formatRectangles(_ rects: [RectangleResult]) -> String {
        if rects.isEmpty { return "0 rectangles detected" }
        let lines = rects.enumerated().map { (i, r) in
            String(format: "rect %d: confidence=%.3f tl=(%.3f,%.3f) tr=(%.3f,%.3f) bl=(%.3f,%.3f) br=(%.3f,%.3f)",
                   i + 1, r.confidence,
                   r.topLeft.x, r.topLeft.y,
                   r.topRight.x, r.topRight.y,
                   r.bottomLeft.x, r.bottomLeft.y,
                   r.bottomRight.x, r.bottomRight.y)
        }
        return lines.joined(separator: "\n")
    }

    public static func markdownRectangles(_ rects: [RectangleResult]) -> String {
        if rects.isEmpty { return "**0 rectangles detected**" }
        let header = "**\(rects.count) rectangle\(rects.count == 1 ? "" : "s") detected**"
        let bullets = rects.enumerated().map { (i, r) in
            String(format: "- rect %d — confidence `%.3f` — corners: tl(%.3f,%.3f) tr(%.3f,%.3f) bl(%.3f,%.3f) br(%.3f,%.3f)",
                   i + 1, r.confidence,
                   r.topLeft.x, r.topLeft.y,
                   r.topRight.x, r.topRight.y,
                   r.bottomLeft.x, r.bottomLeft.y,
                   r.bottomRight.x, r.bottomRight.y)
        }
        return ([header] + bullets).joined(separator: "\n")
    }

    // MARK: Horizon

    public static func formatHorizon(_ h: HorizonResult?) -> String {
        guard let h = h else { return "no horizon detected" }
        return String(format: "horizon: %.3f° (%.5f rad)", h.angleDegrees, h.angleRadians)
    }

    public static func markdownHorizon(_ h: HorizonResult?) -> String {
        guard let h = h else { return "**no horizon detected**" }
        return String(format: "**horizon angle**: `%.3f°` (`%.5f` rad)", h.angleDegrees, h.angleRadians)
    }

    // MARK: Animals

    public static func formatAnimals(_ animals: [AnimalResult]) -> String {
        if animals.isEmpty { return "0 animals detected" }
        let lines = animals.enumerated().map { (i, a) in
            String(format: "%d. %@ (%.0f%%) bbox=(%.3f,%.3f,%.3f,%.3f)",
                   i + 1, a.label as NSString, a.confidence * 100, a.x, a.y, a.width, a.height)
        }
        return lines.joined(separator: "\n")
    }

    public static func markdownAnimals(_ animals: [AnimalResult]) -> String {
        if animals.isEmpty { return "**0 animals detected**" }
        let bullets = animals.enumerated().map { (i, a) in
            String(format: "- %d. **%@** — `%.0f%%` — bbox=(%.3f,%.3f,%.3f,%.3f)",
                   i + 1, a.label as NSString, a.confidence * 100, a.x, a.y, a.width, a.height)
        }
        return bullets.joined(separator: "\n")
    }

    // MARK: Animal pose

    public static func formatAnimalPose(_ animals: [AnimalPoseResult]) -> String {
        if animals.isEmpty { return "0 animal poses detected" }
        let lines = animals.enumerated().map { (i, a) in
            "animal \(i + 1): \(a.joints.count) joints — " + a.joints.prefix(8).map { "\($0.name)(\(String(format: "%.2f", $0.confidence)))" }.joined(separator: " ")
        }
        return lines.joined(separator: "\n")
    }

    public static func markdownAnimalPose(_ animals: [AnimalPoseResult]) -> String {
        if animals.isEmpty { return "**0 animal poses detected**" }
        var out: [String] = ["**\(animals.count) animal pose\(animals.count == 1 ? "" : "s")**"]
        for (i, a) in animals.enumerated() {
            out.append("- animal \(i + 1) — `\(a.joints.count)` joints")
        }
        return out.joined(separator: "\n")
    }

    // MARK: Body pose

    public static func formatBodyPose(_ bodies: [BodyPoseResult]) -> String {
        if bodies.isEmpty { return "0 bodies detected" }
        let lines = bodies.enumerated().map { (i, b) in
            "body \(i + 1): \(b.joints.count) joints — " + b.joints.prefix(8).map { "\($0.name)(\(String(format: "%.2f", $0.confidence)))" }.joined(separator: " ")
        }
        return lines.joined(separator: "\n")
    }

    public static func markdownBodyPose(_ bodies: [BodyPoseResult]) -> String {
        if bodies.isEmpty { return "**0 bodies detected**" }
        var out: [String] = ["**\(bodies.count) bod\(bodies.count == 1 ? "y" : "ies")**"]
        for (i, b) in bodies.enumerated() {
            out.append("- body \(i + 1) — `\(b.joints.count)` joints")
        }
        return out.joined(separator: "\n")
    }

    // MARK: Hand pose

    public static func formatHandPose(_ hands: [HandPoseResult]) -> String {
        if hands.isEmpty { return "0 hands detected" }
        let lines = hands.enumerated().map { (i, h) in
            "hand \(i + 1) [\(h.chirality)]: \(h.joints.count) joints"
        }
        return lines.joined(separator: "\n")
    }

    public static func markdownHandPose(_ hands: [HandPoseResult]) -> String {
        if hands.isEmpty { return "**0 hands detected**" }
        var out: [String] = ["**\(hands.count) hand\(hands.count == 1 ? "" : "s")**"]
        for (i, h) in hands.enumerated() {
            out.append("- hand \(i + 1) — `\(h.chirality)` — `\(h.joints.count)` joints")
        }
        return out.joined(separator: "\n")
    }

    // MARK: Saliency

    public static func formatSaliency(_ regions: [SaliencyRegion]) -> String {
        if regions.isEmpty { return "0 salient regions" }
        let lines = regions.enumerated().map { (i, r) in
            String(format: "region %d: confidence=%.3f bbox=(%.3f,%.3f,%.3f,%.3f)", i + 1, r.confidence, r.x, r.y, r.width, r.height)
        }
        return lines.joined(separator: "\n")
    }

    public static func markdownSaliency(_ regions: [SaliencyRegion]) -> String {
        if regions.isEmpty { return "**0 salient regions**" }
        let bullets = regions.enumerated().map { (i, r) in
            String(format: "- region %d — confidence `%.3f` — bbox=(%.3f,%.3f,%.3f,%.3f)", i + 1, r.confidence, r.x, r.y, r.width, r.height)
        }
        return bullets.joined(separator: "\n")
    }

    // MARK: Contours

    public static func formatContours(_ c: ContoursResult) -> String {
        return "contours: \(c.contourCount) total, \(c.topLevelCount) top-level (\(c.paths.count) sampled)"
    }

    public static func markdownContours(_ c: ContoursResult) -> String {
        var out: [String] = [
            "**contours**",
            "- total: `\(c.contourCount)`",
            "- top-level: `\(c.topLevelCount)`",
            "- sampled paths: `\(c.paths.count)`"
        ]
        if !c.paths.isEmpty {
            for (i, p) in c.paths.prefix(5).enumerated() {
                out.append("- path \(i + 1): `\(p.pointCount)` points")
            }
        }
        return out.joined(separator: "\n")
    }

    // MARK: Feature print

    public static func formatFeaturePrint(_ fp: FeaturePrintResult) -> String {
        let preview = fp.vector.prefix(8).map { String(format: "%.4f", $0) }.joined(separator: ", ")
        return "feature-print: \(fp.dimension) \(fp.elementType) — [\(preview), …]"
    }

    public static func markdownFeaturePrint(_ fp: FeaturePrintResult) -> String {
        let preview = fp.vector.prefix(8).map { String(format: "`%.4f`", $0) }.joined(separator: ", ")
        return "**feature-print** — `\(fp.dimension)` × `\(fp.elementType)`\n\nFirst 8: \(preview)"
    }

    // MARK: Compare

    public static func formatCompare(_ c: CompareResult) -> String {
        return String(format: "distance: %.6f  (lower = more similar)", c.distance)
    }

    public static func markdownCompare(_ c: CompareResult) -> String {
        return String(format: "**distance**: `%.6f` _(lower = more similar)_", c.distance)
    }

    // MARK: Aesthetics

    public static func formatAesthetics(_ a: AestheticsResult) -> String {
        let utility = a.isUtility ? "utility" : "memorable"
        return String(format: "aesthetics: %.3f (%@)", a.overall, utility as NSString)
    }

    public static func markdownAesthetics(_ a: AestheticsResult) -> String {
        let utility = a.isUtility ? "utility" : "memorable"
        return String(format: "**aesthetics**: `%.3f` (%@)", a.overall, utility as NSString)
    }

    // MARK: Smudge

    public static func formatSmudge(_ s: SmudgeResult) -> String {
        return String(format: "smudge confidence: %.3f", s.confidence)
    }

    public static func markdownSmudge(_ s: SmudgeResult) -> String {
        return String(format: "**smudge confidence**: `%.3f`", s.confidence)
    }

    // MARK: Document

    public static func formatDocument(_ d: DocumentResult?) -> String {
        guard let d = d else { return "no document detected" }
        return d.text
    }

    public static func markdownDocument(_ d: DocumentResult?) -> String {
        guard let d = d else { return "_(no document detected)_" }
        var out: [String] = []
        for p in d.paragraphs {
            out.append(p.text)
        }
        for (i, list) in d.lists.enumerated() {
            out.append("\n**List \(i + 1):**")
            for item in list.items {
                out.append("- \(item)")
            }
        }
        for (i, table) in d.tables.enumerated() {
            out.append("\n**Table \(i + 1)** (\(table.rowCount)×\(table.columnCount))")
            for row in table.cells {
                out.append("| " + row.joined(separator: " | ") + " |")
            }
        }
        if !d.urls.isEmpty { out.append("\n**URLs:** " + d.urls.joined(separator: ", ")) }
        if !d.emails.isEmpty { out.append("**Emails:** " + d.emails.joined(separator: ", ")) }
        if !d.phones.isEmpty { out.append("**Phones:** " + d.phones.joined(separator: ", ")) }
        return out.joined(separator: "\n\n")
    }

    // MARK: Combined --all output

    public static func formatAll(
        ocrLines: [String]?,
        classifications: [ClassificationResult]?,
        barcodes: [BarcodeResult]?,
        faces: [FaceResult]?
    ) -> String {
        var sections: [String] = []
        if let lines = ocrLines, !lines.isEmpty {
            sections.append("=== OCR ===\n" + formatOCR(lines))
        }
        if let cls = classifications, !cls.isEmpty {
            sections.append("=== CLASSIFY ===\n" + formatClassification(cls))
        }
        if let bcs = barcodes, !bcs.isEmpty {
            sections.append("=== BARCODES ===\n" + formatBarcodes(bcs))
        }
        if let fcs = faces {
            sections.append("=== FACES ===\n" + formatFaces(fcs))
        }
        if sections.isEmpty {
            return "(no results across any mode)"
        }
        return sections.joined(separator: "\n\n")
    }

    public static func markdownAll(
        ocrLines: [String]?,
        classifications: [ClassificationResult]?,
        barcodes: [BarcodeResult]?,
        faces: [FaceResult]?
    ) -> String {
        var sections: [String] = []
        if let lines = ocrLines, !lines.isEmpty {
            sections.append("## OCR\n\n" + markdownOCR(lines))
        }
        if let cls = classifications, !cls.isEmpty {
            sections.append("## Classification\n\n" + markdownClassification(cls))
        }
        if let bcs = barcodes, !bcs.isEmpty {
            sections.append("## Barcodes\n\n" + markdownBarcodes(bcs))
        }
        if let fcs = faces {
            sections.append("## Faces\n\n" + markdownFaces(fcs))
        }
        if sections.isEmpty {
            return "_(no results across any mode)_"
        }
        return sections.joined(separator: "\n\n")
    }
}
