// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QingPan", platforms: [.macOS("15.4")],
    products: [.executable(name: "QingPan", targets: ["QingPan"]),
               .executable(name: "QingPanHelper", targets: ["QingPanHelper"])],
    targets: [.target(name: "QingPanCore"),
              .executableTarget(name: "QingPan", dependencies: ["QingPanCore"]),
              .executableTarget(name: "QingPanHelper", dependencies: ["QingPanCore"]),
              .executableTarget(name: "QingPanPolicyTests", dependencies: ["QingPanCore"], path: "Tests/QingPanCoreTests")]
)
