import Foundation
import AugeCore

func runImageSizePolicyTests() {
    test("normal-sized image with no enhance: no resize") {
        try assertNil(ImageSizePolicy.target(width: 1500, height: 1000, enhance: false))
    }
    test("oversized image always downscaled (no enhance flag)") {
        let t = ImageSizePolicy.target(width: 5000, height: 4000, enhance: false)
        try assertNotNil(t)
        try assertEqual(t!.width, 2400)
        try assertEqual(t!.height, 1920) // 2400 / 5000 = 0.48; 4000 * 0.48 = 1920
    }
    test("oversized landscape downscaled, long edge becomes 2400") {
        let t = ImageSizePolicy.target(width: 6000, height: 1000, enhance: false)
        try assertNotNil(t)
        try assertEqual(t!.width, 2400)
    }
    test("oversized portrait downscaled, long edge becomes 2400") {
        let t = ImageSizePolicy.target(width: 1000, height: 6000, enhance: false)
        try assertNotNil(t)
        try assertEqual(t!.height, 2400)
    }
    test("tiny image without enhance: no resize") {
        try assertNil(ImageSizePolicy.target(width: 600, height: 400, enhance: false))
    }
    test("tiny image with enhance: upscaled") {
        let t = ImageSizePolicy.target(width: 600, height: 400, enhance: true)
        try assertNotNil(t)
        // 1600 / 600 = 2.667 → capped to 2.0
        try assertEqual(t!.width, 1200)
        try assertEqual(t!.height, 800)
    }
    test("enhance upscale capped at 2x") {
        let t = ImageSizePolicy.target(width: 100, height: 100, enhance: true)
        try assertNotNil(t)
        try assertEqual(t!.width, 200)
        try assertEqual(t!.height, 200)
    }
    test("enhance does not affect images at the boundary") {
        try assertNil(ImageSizePolicy.target(width: 1200, height: 800, enhance: true))
    }
    test("enhance does not affect oversized images (downscale path wins)") {
        let t = ImageSizePolicy.target(width: 5000, height: 5000, enhance: true)
        try assertNotNil(t)
        try assertEqual(t!.width, 2400)
        try assertEqual(t!.height, 2400)
    }
    test("zero-by-zero image returns nil") {
        try assertNil(ImageSizePolicy.target(width: 0, height: 0, enhance: false))
        try assertNil(ImageSizePolicy.target(width: 0, height: 0, enhance: true))
    }
    test("constants reflect the policy thresholds") {
        try assertEqual(ImageSizePolicy.maxLongEdge, 2400)
        try assertEqual(ImageSizePolicy.tinyLongEdge, 1200)
        try assertEqual(ImageSizePolicy.enhancedLongEdge, 1600)
    }
    test("just-under tiny threshold with enhance does upscale") {
        let t = ImageSizePolicy.target(width: 1199, height: 800, enhance: true)
        try assertNotNil(t)
    }
    test("just-over tiny threshold with enhance does not upscale") {
        try assertNil(ImageSizePolicy.target(width: 1201, height: 800, enhance: true))
    }
}
