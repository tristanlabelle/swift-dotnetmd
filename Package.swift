// swift-tools-version: 5.8

import PackageDescription

// Workaround for SPM library support limitations causing "LNK4217: locally defined symbol imported" spew
let executableLinkerSettings = [ LinkerSetting.unsafeFlags(["-Xlinker", "-ignore:4217"]) ]

let package = Package(
    name: "DotNetMetadata",
    products: [
        .library(
            name: "DotNetMetadata",
            targets: ["DotNetMetadataFormat", "DotNetMetadata", "DotNetXMLDocs", "WindowsMetadata"])
    ],
    targets: [
        .target(
            name: "DotNetMetadataCInterop"),

        .target(
            name: "DotNetMetadataFormat",
            dependencies: [ "DotNetMetadataCInterop" ]),
        .testTarget(
            name: "DotNetMetadataFormatTests",
            dependencies: [ "DotNetMetadataFormat" ],
            path: "Tests/DotNetMetadataFormat",
            linkerSettings: executableLinkerSettings),

        .target(
            name: "DotNetMetadata",
            dependencies: [ "DotNetMetadataFormat" ]),
        .testTarget(
            name: "DotNetMetadataTests",
            dependencies: [ "DotNetMetadata" ],
            path: "Tests/DotNetMetadata",
            linkerSettings: executableLinkerSettings),

        .target(
            name: "WindowsMetadata",
            dependencies: [ "DotNetMetadata" ]),
        .testTarget(
            name: "WindowsMetadataTests",
            dependencies: [ "WindowsMetadata" ],
            path: "Tests/WindowsMetadata",
            linkerSettings: executableLinkerSettings),

        .target(
            name: "DotNetXMLDocs"),
        .testTarget(
            name: "DotNetXMLDocsTests",
            dependencies: [ "DotNetXMLDocs" ],
            path: "Tests/DotNetXMLDocs",
            linkerSettings: executableLinkerSettings),
    ]
)
