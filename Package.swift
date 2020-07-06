// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "regular-expression",
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "RegularExpression",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        
        .testTarget(
            name: "RegularExpressionTests",
            dependencies: [
                .target(name: "RegularExpression"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
    ]
)
