import XCTest
@testable import CodexRoute

final class CodexRouteTests: XCTestCase {
    func testRouteModeIdentifiersAreStable() {
        XCTAssertEqual(RouteMode.none.rawValue, "none")
        XCTAssertEqual(RouteMode.local.rawValue, "local")
        XCTAssertEqual(RouteMode.studio.rawValue, "studio")
    }

    func testSelectedOllamaModelsUseTheirOwnCatalogLabels() {
        XCTAssertEqual(RouteService.displayName(for: "hermes3:8b"), "hermes3:8b")
        XCTAssertEqual(RouteService.displayName(for: "llama3.1:70b"), "llama3.1:70b")
        XCTAssertEqual(RouteService.displayName(for: "qwen3.5:35b-a3b-mxfp8"), "qwen3.5:35b-a3b-mxfp8")
        XCTAssertEqual(RouteService.displayName(for: "qwen3.8:27b-mlx"), "qwen3.8:27b-mlx")
        XCTAssertEqual(RouteService.displayName(for: "qwen3.6:35b-a3b-coding-mxfp8"), "Studio Qwen 3.6 Coding (35B)")
    }

    func testOllamaVisionCapabilityEnablesImageInput() throws {
        let capabilities = try RouteService.ollamaModelCapabilities(
            from: Data(#"{"capabilities":["completion","vision","tools"]}"#.utf8)
        )
        XCTAssertEqual(capabilities.inputModalities, ["text", "image"])
    }

    func testOllamaTextOnlyCapabilityExcludesImageInput() throws {
        let capabilities = try RouteService.ollamaModelCapabilities(
            from: Data(#"{"capabilities":["completion","tools"]}"#.utf8)
        )
        XCTAssertEqual(capabilities.inputModalities, ["text"])
    }

    @MainActor
    func testStudioModelAppearsInSelectableModels() {
        let store = RouteStore()
        XCTAssertTrue(store.availableModels.contains { $0.id == "qwen3.6:35b-a3b-coding-mxfp8" })
        XCTAssertEqual(store.availableModels.count, 5)
    }

    @MainActor
    func testStudioTunnelIntegrationWhenExplicitlyEnabled() throws {
        guard ProcessInfo.processInfo.environment["CODEX_ROUTE_STUDIO_INTEGRATION"] == "1" else {
            throw XCTSkip("Studio tunnel integration test is opt-in.")
        }
        let store = RouteStore()
        defer { store.stopTunnel() }
        try store.startTunnelAndVerify()
        XCTAssertNoThrow(try RouteService().checkHTTP(url: URL(string: "http://127.0.0.1:11435/api/version")!))
        XCTAssertNoThrow(try RouteService().checkHTTP(url: URL(string: "http://127.0.0.1:11435/v1/models")!), "The Ollama OpenAI-compatible endpoint used by the launch profile must be reachable through the tunnel")
    }

    @MainActor
    func testStudioSetupThroughPreRestartStageWhenExplicitlyEnabled() throws {
        guard ProcessInfo.processInfo.environment["CODEX_ROUTE_STUDIO_INTEGRATION"] == "1" else {
            throw XCTSkip("Studio setup integration test is opt-in.")
        }
        let store = RouteStore()
        let codexDirectory = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex")
        let activeFiles = ["config.toml", "ollama-launch-models.json", "ollama-launch-codex-routing.json"]
        let original = try Dictionary(uniqueKeysWithValues: activeFiles.map { name in
            (name, try Data(contentsOf: codexDirectory.appendingPathComponent(name)))
        })
        let remoteTarget = "bobkumar@100.111.82.14"
        let remoteRouting = try? commandData("/usr/bin/ssh", ["-o", "BatchMode=yes", remoteTarget, "cat .codex/ollama-launch-codex-routing.json"])
        let remoteCopy = FileManager.default.temporaryDirectory.appendingPathComponent("codex-route-routing-\(UUID().uuidString).json")
        defer {
            try? store.restoreDefaultsOrThrow()
            for (name, data) in original {
                try? data.write(to: codexDirectory.appendingPathComponent(name), options: .atomic)
            }
            if let remoteRouting {
                try? remoteRouting.write(to: remoteCopy, options: .atomic)
                _ = try? commandData("/usr/bin/scp", ["-q", "-o", "BatchMode=yes", remoteCopy.path, "\(remoteTarget):.codex/ollama-launch-codex-routing.json"])
                try? FileManager.default.removeItem(at: remoteCopy)
            }
        }

        store.prepareStudioConnection()
        XCTAssertTrue(store.connectionReady)
        try store.applyOrThrow(.studio)

        let activeConfig = try String(contentsOfFile: NSHomeDirectory() + "/.codex/config.toml", encoding: .utf8)
        XCTAssertTrue(activeConfig.contains("# >>> CodexRoute managed routing"))
        XCTAssertTrue(activeConfig.contains("http://127.0.0.1:11435/api/codex/v1"))
        XCTAssertTrue(activeConfig.contains("model_context_window = 65536"))
        let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: codexDirectory.appendingPathComponent("ollama-launch-models.json"))) as? [String: Any]
        let models = catalog?["models"] as? [[String: Any]]
        let qwen = models?.first { ($0["slug"] as? String) == "qwen3.6:35b-a3b-coding-mxfp8" }
        XCTAssertEqual(qwen?["supported_in_api"] as? Bool, true)
        XCTAssertEqual(qwen?["context_window"] as? Int, 65536)
        XCTAssertEqual(qwen?["input_modalities"] as? [String], ["text", "image"])

        let routing = try JSONSerialization.jsonObject(with: Data(contentsOf: codexDirectory.appendingPathComponent("ollama-launch-codex-routing.json"))) as? [String: Any]
        let routingModels = (routing?["models"] as? [[String: Any]])?.compactMap { $0["slug"] as? String } ?? []
        XCTAssertFalse(routingModels.isEmpty)
        XCTAssertTrue(routingModels.contains(routing?["auto_review_fallback_model"] as? String ?? ""), "Auto-review fallback must remain in the selected Ollama routing catalog")
    }
}

private func commandData(_ executable: String, _ arguments: [String]) throws -> Data {
    let process = Process()
    let output = Pipe()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = output
    process.standardError = output
    try process.run()
    process.waitUntilExit()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    guard process.terminationStatus == 0 else { throw NSError(domain: "CodexRouteTests", code: Int(process.terminationStatus)) }
    return data
}
