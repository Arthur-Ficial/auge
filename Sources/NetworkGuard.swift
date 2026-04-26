// ============================================================================
// NetworkGuard.swift — Hard-blocks any HTTP/HTTPS/WS/WSS request inside auge.
// auge is "100% on-device" by promise; this is the runtime enforcement.
// ============================================================================

import Foundation
import AugeCore

enum NetworkGuard {
    /// Register the deny-all URLProtocol. Call once, very early in main.
    static func install() {
        URLProtocol.registerClass(DenyNetworkURLProtocol.self)
    }
}

final class DenyNetworkURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        NetworkScheme.isBlocked(request.url?.scheme)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let urlText = request.url?.absoluteString ?? "<unknown>"
        FileHandle.standardError.write(Data("auge: network call blocked: \(urlText)\n".utf8))
        Darwin.exit(2)
    }

    override func stopLoading() {}
}
