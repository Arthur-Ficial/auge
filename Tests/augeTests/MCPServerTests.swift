import Foundation
import AugeCore
import AugeApp

func runMCPServerTests() {
    test("release info includes local framework metadata") {
        let info = makeReleaseInfo()
        try assertFalse(info.version.isEmpty)
        try assertTrue(info.framework.contains("Vision"))
        try assertTrue(info.capabilities.contains { $0.id == "ocr" })
    }

    test("analysis mode tool names use auge prefix") {
        try assertEqual(AnalysisMode.ocr.toolName, "auge_ocr")
        try assertEqual(AnalysisMode.faceLandmarks.toolName, "auge_face_landmarks")
        try assertEqual(AnalysisMode.saliencyObjectness.toolName, "auge_saliency_objectness")
    }

    test("compare execution requires exactly two paths") {
        let report = AugeExecutionEngine.run(.init(
            mode: .compare,
            filePaths: ["/tmp/one.png"],
            options: .init()
        ))

        try assertTrue(report.hasFailures)
        try assertEqual(report.failures.count, 1)
        try assertEqual(report.failures[0].error, .unknown("--compare requires exactly two image paths"))
    }
}
