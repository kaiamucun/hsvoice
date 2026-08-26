// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "HSVoice",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "HSVoice", targets: ["HSVoice"])
  ],
  targets: [
    .executableTarget(
      name: "HSVoice",
      path: "Sources/HSVoice"
    ),
    .testTarget(
      name: "HSVoiceTests",
      dependencies: ["HSVoice"],
      path: "Tests/HSVoiceTests"
    ),
  ],
  swiftLanguageVersions: [.v5]
)
