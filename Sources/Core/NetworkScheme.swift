import Foundation

/// Pure-logic helpers for the network-call guard.
/// The URLProtocol that uses this lives in the Vision-target `NetworkGuard.swift`.
public enum NetworkScheme {
    /// Schemes that auge refuses to load. Reflects the project's "100% on-device" promise.
    public static let blocked: Set<String> = ["http", "https", "ws", "wss"]

    /// True if the given URL scheme should be blocked.
    /// Returns false for nil/empty (e.g. file://, data:, custom schemes pass through).
    public static func isBlocked(_ scheme: String?) -> Bool {
        guard let s = scheme?.lowercased(), !s.isEmpty else { return false }
        return blocked.contains(s)
    }
}
