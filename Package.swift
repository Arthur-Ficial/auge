// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "auge",
    platforms: [.macOS(.v26)],
    dependencies: [
        // auge consumes lesbar for its Vision OCR + PDFKit file->text stack, so the
        // extractor is maintained once (also consumed by apfel -f).
        .package(url: "https://github.com/Arthur-Ficial/lesbar.git", from: "0.2.1"),
    ],
    targets: [
        // Pure-logic library — no Vision, testable. Depends on LesbarCore for the
        // shared pure OCR types/policies (aliased in LesbarAliases.swift).
        .target(
            name: "AugeCore",
            dependencies: [
                .product(name: "LesbarCore", package: "lesbar"),
            ],
            path: "Sources/Core"
        ),
        // Main executable — AugeCore + Vision framework + lesbar's OCR/PDF extractor.
        .executableTarget(
            name: "auge",
            dependencies: [
                "AugeCore",
                .product(name: "Lesbar", package: "lesbar"),
                .product(name: "LesbarCore", package: "lesbar"),
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
