// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TransmissionRemoteMac",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "TransmissionRPC",
            targets: ["TransmissionRPC"]
        ),
        .executable(
            name: "TransmissionRemoteMac",
            targets: ["TransmissionRemoteMac"]
        )
    ],
    targets: [
        .target(
            name: "TransmissionRPC"
        ),
        .executableTarget(
            name: "TransmissionRemoteMac",
            dependencies: ["TransmissionRPC"],
            linkerSettings: [
                .linkedFramework("Security")
            ]
        ),
        .testTarget(
            name: "TransmissionRPCTests",
            dependencies: ["TransmissionRPC"]
        )
    ]
)
