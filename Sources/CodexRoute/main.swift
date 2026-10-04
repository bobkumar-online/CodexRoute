import AppKit
import Foundation
import SwiftUI

private extension Notification.Name {
    static let codexRoutePopoverResize = Notification.Name("codexRoutePopoverResize")
}

@main
struct CodexRouteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            RouteSettingsWindow(store: appDelegate.store)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = RouteStore()
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var resizeObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "point.3.connected.trianglepath.dotted", accessibilityDescription: "Codex Routes")
        item.button?.image?.isTemplate = true
        item.button?.toolTip = "Codex Routes"
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        statusItem = item

        popover.behavior = .transient
        resizePopover()
        popover.contentViewController = NSHostingController(rootView: TrayPopover(store: store))
        resizeObserver = NotificationCenter.default.addObserver(forName: .codexRoutePopoverResize, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.resizePopover()
            }
        }
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button else { return }
        resizePopover()
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func resizePopover() {
        popover.contentSize = NSSize(width: 385, height: store.integrationEnabled ? 700 : 158)
    }
}

private struct TrayPopover: View {
    @ObservedObject var store: RouteStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "message")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ChatGPT").font(.headline)
                    Text("Use Ollama models in ChatGPT")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: store.integrationBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)

            if store.integrationEnabled {
                Divider()
                HStack {
                    Text("Model host").font(.subheadline)
                    Spacer()
                    Picker("Model host", selection: store.routeBinding) {
                        Text("Local").tag(RouteMode.local)
                        Text("Studio").tag(RouteMode.studio)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .tint(.blue)
                    .frame(width: 150)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)

                HStack {
                    Label("Ollama connection", systemImage: store.connectionStatus.symbol)
                        .font(.caption)
                        .foregroundStyle(store.connectionStatus.color)
                    Spacer()
                    Text(store.connectionStatus.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Check") { store.checkSelectedConnection() }
                        .buttonStyle(.borderless)
                        .disabled(store.isBusy)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

                Divider()
                VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("1. Choose models visible in ChatGPT")
                            .font(.subheadline.weight(.semibold))
                            Spacer()
                            Menu {
                                ForEach(store.availableModels) { model in
                                    Toggle(model.displayName, isOn: store.binding(for: model.id))
                                        .disabled(!store.connectionReady || !store.isSelectable(model.id))
                                }
                            } label: {
                                Label("Select models", systemImage: "chevron.right")
                            }
                            .disabled(!store.connectionReady)
                        }
                        ForEach(store.selectedModelNames, id: \.self) { name in
                            Text("• \(name)").font(.caption)
                        }
                        Text("Native ChatGPT subscription models remain available and do not count toward this limit.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider()
                        Text("2. Apply and restart")
                            .font(.subheadline.weight(.semibold))
                        HStack {
                            Button(store.selectedMode == .studio ? "Apply Studio setup" : "Apply Local setup") {
                                store.applySelectedMode()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(store.isBusy || store.selectedModels.isEmpty || !store.connectionReady)
                            statusLabel(store.configurationStatus)
                        }
                        Button("Restart ChatGPT/Codex now…") { store.confirmRestart() }
                            .disabled(store.isBusy || store.activeMode != store.selectedMode)

                        Divider()
                        Text("Need to undo this?")
                            .font(.subheadline.weight(.semibold))
                        HStack {
                            Button("Restore native defaults") { store.restoreDefaults() }
                                .disabled(store.isBusy || store.activeMode == .none)
                            Button("Open backups") { store.openBackups() }
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }

            Divider()
            VStack(alignment: .leading, spacing: 0) {
                Button("Settings") { openSettings() }
                Divider().padding(.vertical, 5)
                Button("Quit Codex Routes") { NSApp.terminate(nil) }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .frame(width: 385)
        .onChange(of: store.integrationEnabled) { _, _ in
            NotificationCenter.default.post(name: .codexRoutePopoverResize, object: nil)
        }
        .alert("Turn off Ollama integration?", isPresented: $store.disableConfirmationVisible) {
            Button("Cancel", role: .cancel) { store.cancelDisable() }
            Button("Restore native defaults", role: .destructive) { store.restoreDefaults() }
        } message: {
            Text("This restores normal ChatGPT/Codex routing and removes the app-managed Studio route.")
        }
    }

    private func statusLabel(_ status: RouteStore.Status) -> some View {
        Label(status.message, systemImage: status.symbol)
            .font(.caption)
            .foregroundStyle(status.color)
    }
}

private struct RouteSettingsWindow: View {
    @ObservedObject var store: RouteStore

    var body: some View {
        Form {
            Section("Studio connection") {
                TextField("SSH host", text: $store.studioHost)
                TextField("SSH user", text: $store.studioUser)
                TextField("Local tunnel port", value: $store.studioLocalPort, format: .number)
                TextField("Studio Ollama port", value: $store.studioRemotePort, format: .number)
                Button("Check Studio connection") { store.prepareStudioConnection() }
            }
            Section("Studio runtime") {
                TextField("Context window", value: $store.studioContextWindow, format: .number)
                Text("Codex Routes advertises at most 64K to match the project safety limit. Studio reports a model maximum of \(store.studioModelMaximumContext.formatted()).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Keep alive", text: $store.studioKeepAlive)
                HStack {
                    Button("Refresh Studio runtime") { store.refreshStudioRuntime() }
                    Button("Apply Studio runtime settings…") { store.confirmApplyStudioRuntime() }
                        .disabled(store.isBusy)
                    Spacer()
                    Label(store.studioRuntimeStatus.message, systemImage: store.studioRuntimeStatus.symbol)
                        .font(.caption)
                        .foregroundStyle(store.studioRuntimeStatus.color)
                }
                Text("Applying changes persists the Studio launch-agent environment and restarts Ollama on the Studio. This affects all Studio Ollama models, not ChatGPT/Codex itself.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Safety") {
                Text("Every applied route is backed up. Restore native defaults returns the Codex and Studio routing files managed by this app to their original state.")
                Button("Open backups folder") { store.openBackups() }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

enum RouteMode: String, CaseIterable, Identifiable, Codable {
    case none, local, studio
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct SelectableModel: Identifiable, Hashable {
    let id: String
    let displayName: String
}

@MainActor
final class RouteStore: ObservableObject {
    struct Status {
        let message: String
        let symbol: String
        let color: Color
        static let ready = Status(message: "Ready", symbol: "checkmark.circle.fill", color: .green)
        static let connected = Status(message: "Connected", symbol: "checkmark.circle.fill", color: .green)
        static let inactive = Status(message: "Inactive", symbol: "minus.circle", color: .secondary)
        static func issue(_ text: String) -> Status { Status(message: text, symbol: "exclamationmark.triangle.fill", color: .orange) }
    }

    @Published var integrationEnabled = false
    @Published var selectedMode: RouteMode = .local
    @Published var activeMode: RouteMode = .none
    @Published var selectedModels: Set<String> = []
    @Published var configurationStatus: Status = .ready
    @Published var tunnelStatus: Status = .inactive
    @Published var isBusy = false
    @Published var disableConfirmationVisible = false
    @Published var studioHost = "100.111.82.14"
    @Published var studioUser = NSUserName()
    @Published var studioLocalPort = 11435
    @Published var studioRemotePort = 11434
    @Published var studioContextWindow = 65536
    @Published var studioKeepAlive = "60m"
    @Published var studioModelMaximumContext = 65536
    @Published var studioRuntimeStatus: Status = .inactive

    @Published var availableModels = [
        SelectableModel(id: "qwen3.6:35b-a3b-coding-mxfp8", displayName: "Studio Qwen 3.6 Coding (35B)"),
        SelectableModel(id: "glm-5.3:cloud", displayName: "GLM 5.3 Cloud"),
        SelectableModel(id: "gemma4:31b:cloud", displayName: "Gemma 4 31B Cloud"),
        SelectableModel(id: "qwen2.5-coder:14b-base-q5_K_M", displayName: "Qwen 2.5 Coder 14B"),
        SelectableModel(id: "qwen3.5:9b-mlx", displayName: "Qwen 3.5 9B MLX")
    ]

    private let service = RouteService()
    private var tunnel: Process?

    init() {
        selectedModels = Set(availableModels.map(\.id))
        loadState()
        let detectedMode = service.detectActiveMode()
        activeMode = detectedMode
        integrationEnabled = detectedMode != .none
        selectedMode = detectedMode == .none ? .local : detectedMode
        configurationStatus = detectedMode == .none ? .inactive : .ready
        if detectedMode == .studio {
            tunnelStatus = .issue("Apply Studio route to reconnect")
        }
    }

    var statusSymbol: String {
        switch activeMode { case .none: "circle"; case .local: "l.circle.fill"; case .studio: "s.circle.fill" }
    }

    var studioConnected: Bool { tunnel?.isRunning == true && tunnelStatus.message == "Connected" }
    var connectionStatus: Status { tunnelStatus }
    var connectionReady: Bool { tunnelStatus.message == "Connected" }
    var selectedModelNames: [String] {
        availableModels.filter { selectedModels.contains($0.id) }.map(\.displayName)
    }

    var routeBinding: Binding<RouteMode> {
        Binding(
            get: { self.selectedMode },
            set: { self.chooseRoute($0) }
        )
    }

    var integrationBinding: Binding<Bool> {
        Binding(
            get: { self.integrationEnabled },
            set: { enabled in
                if enabled {
                    self.enableSetup()
                } else if self.activeMode == .none {
                    self.integrationEnabled = false
                } else {
                    self.disableConfirmationVisible = true
                }
            }
        )
    }

    func enableSetup() {
        integrationEnabled = true
        if selectedMode == .none { selectedMode = .local }
        checkSelectedConnection()
    }

    func chooseRoute(_ mode: RouteMode) {
        guard selectedMode != mode else { return }
        selectedMode = mode
        if mode == .studio {
            prepareStudioConnection()
        } else {
            stopTunnel()
            prepareLocalConnection()
        }
    }

    func cancelDisable() {
        integrationEnabled = activeMode != .none
    }

    func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { self.selectedModels.contains(id) },
            set: { newValue in
                if newValue { guard self.selectedModels.count < 5 else { return }; self.selectedModels.insert(id) }
                else { self.selectedModels.remove(id) }
            }
        )
    }

    func isSelectable(_ id: String) -> Bool {
        selectedModels.contains(id) || selectedModels.count < 5
    }

    func select(_ mode: RouteMode) {
        integrationEnabled = mode != .none
        selectedMode = mode == .none ? .local : mode
        apply(mode)
    }

    func applySelectedMode() { apply(selectedMode) }

    func checkSelectedConnection() {
        if selectedMode == .studio { prepareStudioConnection() }
        else { prepareLocalConnection() }
    }

    func prepareLocalConnection() {
        isBusy = true
        defer { isBusy = false }
        do {
            try service.checkHTTP(url: URL(string: "http://127.0.0.1:11434/api/version")!)
            tunnelStatus = .connected
        } catch { tunnelStatus = .issue("Local Ollama unavailable") }
    }

    func prepareStudioConnection() {
        isBusy = true
        defer { isBusy = false }
        do {
            try prepareStudioConnectionOrThrow()
            let studioModels = try service.fetchOllamaModels(port: studioLocalPort)
            availableModels = studioModels.map { name in
                SelectableModel(id: name, displayName: name == "qwen3.6:35b-a3b-coding-mxfp8" ? "Studio Qwen 3.6 Coding (35B)" : name)
            }
            selectedModels = selectedModels.intersection(Set(studioModels))
            if selectedModels.isEmpty, studioModels.contains("qwen3.6:35b-a3b-coding-mxfp8") {
                selectedModels.insert("qwen3.6:35b-a3b-coding-mxfp8")
            }
            tunnelStatus = .connected
        } catch {
            tunnelStatus = .issue(error.localizedDescription)
        }
    }

    func prepareStudioConnectionOrThrow() throws {
        // Do not preflight Studio with URLSession over clear-text Tailnet HTTP.
        // macOS can block that request before SSH starts. The loopback probe below
        // validates the actual route Codex will use.
        try startTunnelAndVerify()
    }

    func apply(_ mode: RouteMode) {
        isBusy = true
        defer { isBusy = false }
        do {
            try applyOrThrow(mode)
        } catch {
            configurationStatus = .issue(error.localizedDescription)
            if mode == .studio { tunnelStatus = .issue(error.localizedDescription) }
        }
    }

    func applyOrThrow(_ mode: RouteMode) throws {
        if mode == .studio {
            try startTunnelAndVerify()
        } else {
            stopTunnel()
            try service.restoreStudioRoutingIfManaged()
        }
        let ollamaPort = mode == .studio ? studioLocalPort : 11434
        let capabilities = try service.fetchOllamaModelCapabilities(port: ollamaPort, models: selectedModels)
        if mode == .studio {
            try service.provisionStudioRouting(host: studioHost, user: studioUser, selectedModels: selectedModels)
        }
        try service.apply(mode: mode, selectedModels: selectedModels, modelCapabilities: capabilities, localPort: studioLocalPort, contextWindow: studioContextWindow)
        activeMode = mode
        selectedMode = mode == .none ? .local : mode
        integrationEnabled = mode != .none
        configurationStatus = .ready
        tunnelStatus = mode == .studio ? .connected : .inactive
        saveState()
    }

    func restoreDefaults() {
        isBusy = true
        defer { isBusy = false }
        do {
            try restoreDefaultsOrThrow()
        } catch { configurationStatus = .issue(error.localizedDescription) }
    }

    func restoreDefaultsOrThrow() throws {
        try service.restoreStudioRoutingIfManaged()
        stopTunnel()
        try service.restoreBaseline()
        activeMode = .none
        integrationEnabled = false
        configurationStatus = .ready
        tunnelStatus = .inactive
        saveState()
    }

    func checkStudio() {
        isBusy = true
        defer { isBusy = false }
        do {
            try service.checkHTTP(url: URL(string: "http://\(studioHost):\(studioRemotePort)/api/tags")!)
            tunnelStatus = Status(message: "Studio reachable", symbol: "checkmark.circle.fill", color: .green)
        } catch { tunnelStatus = .issue("Studio unavailable") }
    }

    func refreshStudioRuntime() {
        isBusy = true
        defer { isBusy = false }
        do {
            try prepareStudioConnectionOrThrow()
            let runtime = try service.readStudioRuntime(host: studioHost, user: studioUser)
            studioContextWindow = runtime.contextWindow
            studioKeepAlive = runtime.keepAlive
            studioModelMaximumContext = runtime.modelMaximumContext
            studioRuntimeStatus = .ready
        } catch { studioRuntimeStatus = .issue(error.localizedDescription) }
    }

    func confirmApplyStudioRuntime() {
        let alert = NSAlert()
        alert.messageText = "Apply Studio Ollama runtime settings?"
        alert.informativeText = "This will persist the Studio context window and keep-alive values, then restart Ollama on the Studio. It will not restart ChatGPT/Codex."
        alert.addButton(withTitle: "Apply and restart Studio Ollama")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try service.applyStudioRuntime(host: studioHost, user: studioUser, contextWindow: studioContextWindow, keepAlive: studioKeepAlive)
            studioRuntimeStatus = .ready
        } catch { studioRuntimeStatus = .issue(error.localizedDescription) }
    }

    func restartCodex() {
        let apps = NSWorkspace.shared.runningApplications.filter { app in
            let id = app.bundleIdentifier?.lowercased() ?? ""
            return id.contains("openai") || id.contains("chatgpt")
        }
        apps.forEach { $0.terminate() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/Applications/ChatGPT.app"), configuration: .init()) { _, _ in }
        }
    }

    func confirmRestart() {
        let alert = NSAlert()
        alert.messageText = "Restart ChatGPT/Codex?"
        alert.informativeText = "This can interrupt an active Codex task. Configuration changes take effect after restart."
        alert.addButton(withTitle: "Restart")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { restartCodex() }
    }

    func openBackups() { NSWorkspace.shared.open(service.backupsURL) }

    func startTunnelAndVerify() throws {
        if tunnel?.isRunning == true { return }
        let process = Process()
        let diagnostics = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
            "-N", "-L", "127.0.0.1:\(studioLocalPort):127.0.0.1:\(studioRemotePort)",
            "-o", "BatchMode=yes", "-o", "ExitOnForwardFailure=yes", "-o", "ConnectTimeout=10", "-o", "ServerAliveInterval=30",
            "-o", "ServerAliveCountMax=3", "\(studioUser)@\(studioHost)"
        ]
        process.standardOutput = diagnostics
        process.standardError = diagnostics
        try process.run()
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if !process.isRunning {
                let detail = String(data: diagnostics.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "no SSH diagnostic available"
                throw RouteError.tunnelFailedDetail(detail)
            }
            if (try? service.checkHTTP(url: URL(string: "http://127.0.0.1:\(studioLocalPort)/api/version")!)) != nil {
                tunnel = process
                return
            }
            Thread.sleep(forTimeInterval: 0.25)
        }
        process.terminate()
        process.waitUntilExit()
        let detail = String(data: diagnostics.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "endpoint did not become ready within 10 seconds"
        throw RouteError.tunnelFailedDetail(detail)
    }

    func stopTunnel() { tunnel?.terminate(); tunnel = nil }
    private func saveState() {
        UserDefaults.standard.set(activeMode.rawValue, forKey: "activeMode")
        UserDefaults.standard.set(Array(selectedModels), forKey: "selectedModels")
    }
    private func loadState() {
        if let raw = UserDefaults.standard.string(forKey: "activeMode"), let mode = RouteMode(rawValue: raw) { activeMode = mode; integrationEnabled = mode != .none }
        if let values = UserDefaults.standard.stringArray(forKey: "selectedModels") { selectedModels = Set(values) }
    }
}

enum RouteError: LocalizedError {
    case missingFile(String), invalidCatalog, modelCapabilityUnavailable(String), tunnelFailed, tunnelFailedDetail(String), conflictingConfiguration, invalidStudioTarget, commandFailed(String)
    var errorDescription: String? {
        switch self {
        case .missingFile(let path): return "Missing required file: \(path)"
        case .invalidCatalog: return "Could not validate the model catalog"
        case .modelCapabilityUnavailable(let model): return "Could not determine Ollama capabilities for \(model); routing was not changed"
        case .tunnelFailed: return "SSH tunnel did not start"
        case .tunnelFailedDetail(let detail):
            let compact = detail.trimmingCharacters(in: .whitespacesAndNewlines)
            return compact.isEmpty ? "SSH tunnel did not become ready within 10 seconds" : "SSH tunnel did not start: \(compact.prefix(240))"
        case .conflictingConfiguration: return "Existing unmanaged routing overrides require Restore defaults first"
        case .invalidStudioTarget: return "Studio SSH host or user contains unsupported characters"
        case .commandFailed(let message): return "Studio setup failed: \(message)"
        }
    }
}

struct RouteService {
    private let fm = FileManager.default
    private let codexURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex")
    let rootURL: URL

    init() { rootURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex/codex-route") }
    var backupsURL: URL { rootURL.appendingPathComponent("backups") }
    private var configURL: URL { codexURL.appendingPathComponent("config.toml") }
    private var catalogURL: URL { codexURL.appendingPathComponent("ollama-launch-models.json") }
    private var routingURL: URL { codexURL.appendingPathComponent("ollama-launch-codex-routing.json") }
    private var studioStateURL: URL { rootURL.appendingPathComponent("studio-routing-state.json") }

    /// The catalog is rendered by Codex using `display_name`, not `slug`.
    /// Never inherit that field from an unrelated template entry: Ollama's
    /// generated catalog can retain a previously selected cloud-model label.
    static func displayName(for slug: String) -> String {
        slug == "qwen3.6:35b-a3b-coding-mxfp8" ? "Studio Qwen 3.6 Coding (35B)" : slug
    }

    private struct StudioRoutingState: Codable {
        let host: String
        let user: String
        let originalExisted: Bool
        let baselineRemotePath: String?
    }

    struct StudioRuntime {
        let contextWindow: Int
        let keepAlive: String
        let modelMaximumContext: Int
    }

    struct OllamaModelCapabilities: Equatable {
        let supportsVision: Bool

        var inputModalities: [String] {
            supportsVision ? ["text", "image"] : ["text"]
        }
    }

    func detectActiveMode() -> RouteMode {
        guard let config = try? String(contentsOf: configURL, encoding: .utf8),
              config.contains("# >>> CodexRoute managed routing") else { return .none }
        return config.contains("127.0.0.1:11435/api/codex/v1") ? .studio : .local
    }

    func apply(mode: RouteMode, selectedModels: Set<String>, modelCapabilities: [String: OllamaModelCapabilities], localPort: Int, contextWindow: Int) throws {
        try bootstrapIfNeeded()
        try snapshotCurrent()
        switch mode {
        case .none: try restoreBaseline()
        case .local:
            let catalog = try makeCatalog(mode: .local, selectedModels: selectedModels, modelCapabilities: modelCapabilities, contextWindow: contextWindow)
            let routing = try makeRouting(selectedModels: selectedModels)
            try writeJSON(catalog, to: catalogURL)
            try writeJSON(routing, to: routingURL)
            try writeManagedCodexConfig(model: selectedModels.sorted().first ?? "gpt-5.6-luna", baseURL: "http://127.0.0.1:11434/api/codex/v1", contextWindow: contextWindow)
        case .studio:
            let catalog = try makeCatalog(mode: .studio, selectedModels: selectedModels, modelCapabilities: modelCapabilities, contextWindow: contextWindow)
            let routing = try makeRouting(selectedModels: selectedModels)
            try writeJSON(catalog, to: catalogURL)
            try writeJSON(routing, to: routingURL)
            let defaultModel = selectedModels.contains("qwen3.6:35b-a3b-coding-mxfp8") ? "qwen3.6:35b-a3b-coding-mxfp8" : (selectedModels.sorted().first ?? "gpt-5.6-luna")
            try writeManagedCodexConfig(model: defaultModel, baseURL: "http://127.0.0.1:\(localPort)/api/codex/v1", contextWindow: contextWindow)
        }
    }

    func restoreBaseline() throws {
        try bootstrapIfNeeded()
        try snapshotCurrent()
        try replace(configURL, with: adjacentBackup(for: configURL))
        try replace(catalogURL, with: adjacentBackup(for: catalogURL))
        try replace(routingURL, with: adjacentBackup(for: routingURL))
    }

    func provisionStudioRouting(host: String, user: String, selectedModels: Set<String>) throws {
        let target = try studioTarget(host: host, user: user)
        let routing = try makeRouting(selectedModels: selectedModels)
        let temporaryRouting = rootURL.appendingPathComponent("studio-routing-upload.json")
        try writeJSON(routing, to: temporaryRouting)

        if !fm.fileExists(atPath: studioStateURL.path) {
            let originalExisted = try remoteFileExists(target: target, path: ".codex/ollama-launch-codex-routing.json")
            var baselineRemotePath: String?
            if originalExisted {
                let backupDirectory = ".codex/codex-route-backups/codexroute-initial-\(UUID().uuidString)"
                try execute("/usr/bin/ssh", ["-o", "BatchMode=yes", target, "mkdir -p \(backupDirectory) && cp .codex/ollama-launch-codex-routing.json \(backupDirectory)/ollama-launch-codex-routing.json"])
                baselineRemotePath = "\(backupDirectory)/ollama-launch-codex-routing.json"
            }
            let state = StudioRoutingState(host: host, user: user, originalExisted: originalExisted, baselineRemotePath: baselineRemotePath)
            let data = try JSONEncoder().encode(state)
            try atomicWrite(data, to: studioStateURL)
        }

        let backupDirectory = ".codex/codex-route-backups/codexroute-\(UUID().uuidString)"
        try execute("/usr/bin/ssh", ["-o", "BatchMode=yes", target, "mkdir -p .codex \(backupDirectory); if [ -f .codex/ollama-launch-codex-routing.json ]; then cp .codex/ollama-launch-codex-routing.json \(backupDirectory)/ollama-launch-codex-routing.json; fi"])
        try execute("/usr/bin/scp", ["-q", "-o", "BatchMode=yes", temporaryRouting.path, "\(target):.codex/ollama-launch-codex-routing.json"])
        guard try remoteFileExists(target: target, path: ".codex/ollama-launch-codex-routing.json") else { throw RouteError.tunnelFailed }
    }

    func restoreStudioRoutingIfManaged() throws {
        guard fm.fileExists(atPath: studioStateURL.path) else { return }
        let state = try JSONDecoder().decode(StudioRoutingState.self, from: Data(contentsOf: studioStateURL))
        let target = try studioTarget(host: state.host, user: state.user)
        if state.originalExisted, let baseline = state.baselineRemotePath {
            try execute("/usr/bin/ssh", ["-o", "BatchMode=yes", target, "test -f \(baseline) && cp \(baseline) .codex/ollama-launch-codex-routing.json"])
        } else {
            try execute("/usr/bin/ssh", ["-o", "BatchMode=yes", target, "rm -f .codex/ollama-launch-codex-routing.json"])
        }
        try fm.removeItem(at: studioStateURL)
    }

    func checkHTTP(url: URL) throws {
        let semaphore = DispatchSemaphore(value: 0)
        let result = HTTPCheckResult()
        URLSession.shared.dataTask(with: url) { _, response, _ in
            result.success = (response as? HTTPURLResponse)?.statusCode == 200
            semaphore.signal()
        }.resume()
        guard semaphore.wait(timeout: .now() + 10) == .success, result.success else { throw RouteError.tunnelFailed }
    }

    func fetchOllamaModels(port: Int) throws -> [String] {
        let semaphore = DispatchSemaphore(value: 0)
        let result = HTTPDataResult()
        URLSession.shared.dataTask(with: URL(string: "http://127.0.0.1:\(port)/api/tags")!) { data, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 { result.data = data }
            semaphore.signal()
        }.resume()
        guard semaphore.wait(timeout: .now() + 10) == .success,
              let data = result.data,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = root["models"] as? [[String: Any]] else { throw RouteError.tunnelFailed }
        return models.compactMap { $0["name"] as? String }.sorted { lhs, rhs in
            if lhs == "qwen3.6:35b-a3b-coding-mxfp8" { return true }
            if rhs == "qwen3.6:35b-a3b-coding-mxfp8" { return false }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    func fetchOllamaModelCapabilities(port: Int, models: Set<String>) throws -> [String: OllamaModelCapabilities] {
        var capabilities: [String: OllamaModelCapabilities] = [:]
        for model in models {
            var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/api/show")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["model": model])

            let semaphore = DispatchSemaphore(value: 0)
            let result = HTTPDataResult()
            URLSession.shared.dataTask(with: request) { data, response, _ in
                if let http = response as? HTTPURLResponse, http.statusCode == 200 { result.data = data }
                semaphore.signal()
            }.resume()
            guard semaphore.wait(timeout: .now() + 10) == .success, let data = result.data else {
                throw RouteError.modelCapabilityUnavailable(model)
            }
            capabilities[model] = try Self.ollamaModelCapabilities(from: data, model: model)
        }
        return capabilities
    }

    static func ollamaModelCapabilities(from data: Data, model: String = "selected model") throws -> OllamaModelCapabilities {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let values = root["capabilities"] as? [String] else {
            throw RouteError.modelCapabilityUnavailable(model)
        }
        return OllamaModelCapabilities(supportsVision: values.contains("vision"))
    }

    func readStudioRuntime(host: String, user: String) throws -> StudioRuntime {
        let target = try studioTarget(host: host, user: user)
        let environment = try execute("/usr/bin/ssh", ["-o", "BatchMode=yes", target, "ps eww -ax | grep '[o]llama serve'"])
        let context = Int(environment.firstMatch(#"OLLAMA_CONTEXT_LENGTH=([0-9]+)"#) ?? "65536") ?? 65536
        let keepAlive = environment.firstMatch(#"OLLAMA_KEEP_ALIVE=([^ ]+)"#) ?? "60m"
        let shown = try execute("/usr/bin/ssh", ["-o", "BatchMode=yes", target, "/Applications/Ollama.app/Contents/Resources/ollama show qwen3.6:35b-a3b-coding-mxfp8"])
        let maximum = Int(shown.firstMatch(#"context length\s+([0-9]+)"#) ?? "65536") ?? 65536
        return StudioRuntime(contextWindow: context, keepAlive: keepAlive, modelMaximumContext: maximum)
    }

    func applyStudioRuntime(host: String, user: String, contextWindow: Int, keepAlive: String) throws {
        guard (1024...65536).contains(contextWindow) else { throw RouteError.commandFailed("Context window must be between 1024 and 65536") }
        guard keepAlive.range(of: #"^[0-9]+[smhd]$"#, options: .regularExpression) != nil else {
            throw RouteError.commandFailed("Keep alive must look like 60m, 1h, or 30m")
        }
        let target = try studioTarget(host: host, user: user)
        let runtimeAgent = rootURL.appendingPathComponent("com.bobkumar.ollama-runtime.plist")
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
          <key>Label</key><string>com.bobkumar.ollama-runtime</string>
          <key>ProgramArguments</key><array><string>/bin/sh</string><string>-c</string><string>/bin/launchctl setenv OLLAMA_CONTEXT_LENGTH \(contextWindow); /bin/launchctl setenv OLLAMA_KEEP_ALIVE \(keepAlive)</string></array>
          <key>RunAtLoad</key><true/>
        </dict></plist>
        """
        try atomicWrite(plist, to: runtimeAgent)
        let remoteAgent = "Library/LaunchAgents/com.bobkumar.ollama-runtime.plist"
        let remoteBackup = "Library/LaunchAgents/com.bobkumar.ollama-runtime.plist.codexroute.bak"
        let backupCommand = "mkdir -p Library/LaunchAgents; if [ -f \(remoteAgent) ] && [ ! -f \(remoteBackup) ]; then cp \(remoteAgent) \(remoteBackup); fi"
        _ = try execute("/usr/bin/ssh", ["-o", "BatchMode=yes", target, backupCommand])
        _ = try execute("/usr/bin/scp", ["-q", "-o", "BatchMode=yes", runtimeAgent.path, "\(target):\(remoteAgent)"])
        let command = "launchctl setenv OLLAMA_CONTEXT_LENGTH \(contextWindow); launchctl setenv OLLAMA_KEEP_ALIVE \(keepAlive); osascript -e 'tell application \"Ollama\" to quit'; sleep 2; open -a Ollama"
        _ = try execute("/usr/bin/ssh", ["-o", "BatchMode=yes", target, command])
    }

    private func bootstrapIfNeeded() throws {
        try fm.createDirectory(at: backupsURL, withIntermediateDirectories: true)
        guard fm.fileExists(atPath: configURL.path) else { throw RouteError.missingFile(configURL.path) }
        for source in [configURL, catalogURL, routingURL] {
            let backup = adjacentBackup(for: source)
            if !fm.fileExists(atPath: backup.path), fm.fileExists(atPath: source.path) {
                try fm.copyItem(at: source, to: backup)
            }
            guard fm.fileExists(atPath: backup.path) else { throw RouteError.missingFile(backup.path) }
        }
    }

    private func snapshotCurrent() throws {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTime]
        let name = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-") + "-" + String(UUID().uuidString.prefix(8))
        let folder = backupsURL.appendingPathComponent(name)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        for file in ["config.toml", "ollama-launch-codex-routing.json", "ollama-launch-models.json"] {
            let source = codexURL.appendingPathComponent(file)
            if fm.fileExists(atPath: source.path) { try fm.copyItem(at: source, to: folder.appendingPathComponent(file)) }
        }
    }

    private func makeCatalog(mode: RouteMode, selectedModels: Set<String>, modelCapabilities: [String: OllamaModelCapabilities], contextWindow: Int) throws -> [String: Any] {
        let source = adjacentBackup(for: catalogURL)
        guard let data = try? Data(contentsOf: source),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sourceModels = root["models"] as? [[String: Any]] else { throw RouteError.invalidCatalog }
        let nativeModels = sourceModels.filter { ($0["description"] as? String) != "Ollama model" }
        let template = sourceModels.first(where: { ($0["description"] as? String) == "Ollama model" && ($0["supported_in_api"] as? Bool) == true })
            ?? sourceModels.first(where: { ($0["slug"] as? String) == "hermes3:8b" })
        guard let template else { throw RouteError.invalidCatalog }
        var selected: [[String: Any]] = []
        for slug in selectedModels.sorted() {
            guard let capabilities = modelCapabilities[slug] else { throw RouteError.modelCapabilityUnavailable(slug) }
            var model = sourceModels.first(where: { ($0["slug"] as? String) == slug }) ?? template
            model["slug"] = slug
            model["display_name"] = Self.displayName(for: slug)
            model["description"] = "Ollama model"
            model["supported_in_api"] = true
            model["visibility"] = "list"
            model["input_modalities"] = capabilities.inputModalities
            if mode == .studio {
                model["context_window"] = contextWindow
                model["max_context_window"] = contextWindow
            }
            selected.append(model)
        }
        root["models"] = selected + nativeModels
        return root
    }

    private func makeRouting(selectedModels: Set<String>) throws -> [String: Any] {
        let source = adjacentBackup(for: routingURL)
        guard let data = try? Data(contentsOf: source),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var models = root["models"] as? [[String: Any]] else { throw RouteError.invalidCatalog }
        models = models.filter { model in
            guard let slug = model["slug"] as? String else { return false }
            return selectedModels.contains(slug)
        }
        for slug in selectedModels.sorted() where !models.contains(where: { ($0["slug"] as? String) == slug }) {
            models.append(["slug": slug, "thinking": ["supported": false]])
        }
        // Ollama validates the auto-review fallback against this catalog before
        // handling every request.  The baseline file may point at a model that
        // the user just deselected, which makes the whole route return 503.
        // Keep the fallback inside the selected catalog (the UI never applies
        // an empty selection).
        guard let fallback = selectedModels.sorted().first else { throw RouteError.invalidCatalog }
        root["auto_review_fallback_model"] = fallback
        root["models"] = models
        return root
    }

    private func writeManagedCodexConfig(model: String, baseURL: String, contextWindow: Int) throws {
        let original = try String(contentsOf: configURL, encoding: .utf8)
        let managedKeys = ["model =", "model_reasoning_effort =", "model_catalog_json =", "openai_base_url =", "model_context_window ="]
        let stripped = original
            .components(separatedBy: .newlines)
            .filter { line in
                !managedKeys.contains(where: { line.trimmingCharacters(in: .whitespaces).hasPrefix($0) }) &&
                !line.contains("CodexRoute managed routing")
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let block = """
        # >>> CodexRoute managed routing (do not edit)
        model = "\(model)"
        model_reasoning_effort = "none"
        model_catalog_json = "\(catalogURL.path)"
        openai_base_url = "\(baseURL)"
        model_context_window = \(contextWindow)
        # <<< CodexRoute managed routing

        """
        try atomicWrite(block + (stripped.isEmpty ? "" : stripped + "\n"), to: configURL)
    }

    private func adjacentBackup(for url: URL) -> URL {
        URL(fileURLWithPath: url.path + ".bak")
    }

    private func studioTarget(host: String, user: String) throws -> String {
        let permitted = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_:")
        guard !host.isEmpty, !user.isEmpty,
              host.unicodeScalars.allSatisfy({ permitted.contains($0) }),
              user.unicodeScalars.allSatisfy({ permitted.contains($0) }) else { throw RouteError.invalidStudioTarget }
        return "\(user)@\(host)"
    }

    private func remoteFileExists(target: String, path: String) throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = ["-o", "BatchMode=yes", target, "test -f \(path)"]
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    @discardableResult
    private func execute(_ executable: String, _ arguments: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        let message = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "command failed"
        guard process.terminationStatus == 0 else {
            throw RouteError.commandFailed(String(message.prefix(300)).trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return message
    }

    private func writeJSON(_ object: Any, to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try atomicWrite(data, to: url)
    }
    private func atomicWrite(_ string: String, to url: URL) throws { try atomicWrite(Data(string.utf8), to: url) }
    private func atomicWrite(_ data: Data, to url: URL) throws {
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
    private func replace(_ destination: URL, with source: URL) throws {
        guard fm.fileExists(atPath: source.path) else { throw RouteError.missingFile(source.path) }
        let data = try Data(contentsOf: source)
        try atomicWrite(data, to: destination)
    }
}

private extension String {
    func firstMatch(_ pattern: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: self, range: NSRange(startIndex..., in: self)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: self) else { return nil }
        return String(self[range])
    }
}

private final class HTTPCheckResult: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    var success: Bool {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }
}

private final class HTTPDataResult: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Data?
    var data: Data? {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }
}
