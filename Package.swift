// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "auge",
    platforms: [.macOS(.v26)],
    targets: [
        // Pure-logic library — no Vision, testable
        .target(
            name: "AugeCore",
            dependencies: [],
            path: "Sources/Core"
        ),
        // Main executable — depends on AugeCore + Vision framework
        .executableTarget(
            name: "auge",
            dependencies: [
                "AugeCore",
            ],
            path: "Sources",
            exclude: ["Core"]
        ),
        // Test runner — pure Swift, no XCTest/Testing (Command Line Tools only)
        .executableTarget(
            name: "auge-tests",
            dependencies: ["AugeCore"],
            path: "Tests/augeTests"
        ),
    ]
)
