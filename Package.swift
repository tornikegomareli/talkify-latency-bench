// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "LatencyBench",
  platforms: [
    .macOS(.v15)
  ],
  products: [
    .executable(name: "LatencyBench", targets: ["LatencyBench"]),
    .executable(name: "BenchmarkStimulus", targets: ["BenchmarkStimulus"])
  ],
  targets: [
    .executableTarget(
      name: "LatencyBench",
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .executableTarget(name: "BenchmarkStimulus"),
    .testTarget(
      name: "LatencyBenchTests",
      dependencies: ["LatencyBench"]
    )
  ]
)
