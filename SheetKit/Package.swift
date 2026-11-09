// swift-tools-version: 6.2
import PackageDescription

// SheetKit : modèle de données et logique métier de Character Sheet,
// indépendants de l'interface (testables sur Mac avec `swift test`).
let package = Package(
    name: "SheetKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "SheetKit", targets: ["SheetKit"]),
    ],
    targets: [
        .target(name: "SheetKit"),
        .testTarget(name: "SheetKitTests", dependencies: ["SheetKit"]),
    ]
)
