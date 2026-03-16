// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MakeMyMacFastAgain",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "CSystemKit",
            path: "Sources/CSystemKit",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("proc", .when(platforms: [.macOS]))
            ]
        ),
        .executableTarget(
            name: "MakeMyMacFastAgain",
            dependencies: ["CSystemKit"],
            path: "Sources/MakeMyMacFastAgain",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("IOKit"),
                .linkedFramework("UserNotifications")
            ]
        ),
        .testTarget(
            name: "MakeMyMacFastAgainTests",
            dependencies: ["MakeMyMacFastAgain"],
            path: "Tests",
            swiftSettings: [
                .unsafeFlags(["-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"])
            ],
            linkerSettings: [
                .unsafeFlags(["-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                              "-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"])
            ]
        )
    ]
)
