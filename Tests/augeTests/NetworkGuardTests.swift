import Foundation
import AugeCore

func runNetworkGuardTests() {
    test("http is blocked") {
        try assertTrue(NetworkScheme.isBlocked("http"))
    }
    test("https is blocked") {
        try assertTrue(NetworkScheme.isBlocked("https"))
    }
    test("ws is blocked") {
        try assertTrue(NetworkScheme.isBlocked("ws"))
    }
    test("wss is blocked") {
        try assertTrue(NetworkScheme.isBlocked("wss"))
    }
    test("uppercase HTTPS is blocked (case-insensitive)") {
        try assertTrue(NetworkScheme.isBlocked("HTTPS"))
    }
    test("mixed-case Http is blocked") {
        try assertTrue(NetworkScheme.isBlocked("Http"))
    }
    test("file is allowed") {
        try assertFalse(NetworkScheme.isBlocked("file"))
    }
    test("data scheme is allowed") {
        try assertFalse(NetworkScheme.isBlocked("data"))
    }
    test("custom scheme is allowed") {
        try assertFalse(NetworkScheme.isBlocked("auge"))
    }
    test("nil scheme is allowed") {
        try assertFalse(NetworkScheme.isBlocked(nil))
    }
    test("empty scheme is allowed") {
        try assertFalse(NetworkScheme.isBlocked(""))
    }
    test("blocked set contains exactly the four protocols") {
        try assertEqual(NetworkScheme.blocked, ["http", "https", "ws", "wss"])
    }
}
