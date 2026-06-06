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
        // Shared app logic — Vision integration, CLI runtime, MCP runtime
        .target(
            name: "AugeApp",
            dependencies: [
                "AugeCore",
            ],
            path: "Sources",
            exclude: ["Core", "CLIApp", "MCPApp", "main.swift"]
        ),
        // Main executable — thin entrypoint over AugeApp
        .executableTarget(
            name: "auge",
            dependencies: [
                "AugeApp",
            ],
            path: "Sources/CLIApp"
        ),
        // Local MCP stdio server — thin entrypoint over AugeApp
        .executableTarget(
            name: "auge-mcp",
            dependencies: [
                "AugeApp",
            ],
            path: "Sources/MCPApp"
        ),
        // Test runner — pure Swift, no XCTest/Testing (Command Line Tools only)
        .executableTarget(
            name: "auge-tests",
            dependencies: ["AugeCore", "AugeApp"],
            path: "Tests/augeTests"
        ),
    ]
)
