// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "AIxcam",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "AIxcam",
            targets: ["AIxcam"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0")
    ],
    targets: [
        .target(
            name: "AIxcam",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk")
            ],
            path: "Sources/AIxcam"
        )
    ]
)
