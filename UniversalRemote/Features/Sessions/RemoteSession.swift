import AppKit
import Combine
import Foundation
import SwiftData
import SwiftTerm

@MainActor final class RemoteSession: ObservableObject, Identifiable {
    let id = UUID()
    let profile: ConnectionDraft
    let persistent: Bool
    @Published var state = SessionState.waiting
    @Published var message = "Waiting for credentials"
    @Published var remoteTitle = ""
    @Published var logs: [SessionLog] = []
    @Published var sshMode = SSHWorkspaceMode.terminal
    let files = SFTPController()
    let terminal: TerminalController?
    let desktop: RDPDesktopView?
    private var ssh: URSSHClient?
    private var rdp: URRDPClient?
    private var tunnel: WireGuardTransport?
    private var tunnelTask: Task<Void, Never>?
    private var pendingWaiters: [PromptWaiter] = []
    private var generation = UUID()
    private var clipboardTimer: Timer?
    private var clipboardChange = -1
    var isSelected = false
    weak var workspace: Workspace?

    init(profile: ConnectionDraft, workspace: Workspace, persistent: Bool = true) {
        self.profile = profile
        self.workspace = workspace
        self.persistent = persistent
        if profile.kind == .ssh {
            terminal = TerminalController(profile: profile)
            desktop = nil
        } else {
            terminal = nil
            let view = RDPDesktopView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
            view.displayMode = profile.displayMode
            view.setDesktopSize(CGSize(width: profile.desktopWidth, height: profile.desktopHeight))
            desktop = view
        }
    }
    func start(credential: ConnectionCredential) {
        guard profile.kind == .rdp, let tunnelID = profile.wireGuardID else {
            startProtocol(credential: credential)
            return
        }
        generation = UUID()
        let attempt = generation
        state = .connecting
        message = "Starting WireGuard…"
        do {
            guard let context = workspace?.modelContext else { throw WireGuardError.unavailable }
            var query = FetchDescriptor<SavedWireGuard>(predicate: #Predicate { $0.id == tunnelID })
            query.fetchLimit = 1
            guard let saved = try context.fetch(query).first else { throw WireGuardError.unavailable }
            let configuration = try saved.configuration()
            guard let keys = try CredentialStore.load(tunnelID) else { throw WireGuardError.missingKeys }
            let transport = WireGuardTransport()
            tunnel = transport
            let host = profile.host
            let port = profile.port
            let reference = WeakRemoteSession(self)
            let onExit: @Sendable () -> Void = {
                Task { @MainActor in
                    guard let self = reference.value, self.generation == attempt, self.state.active else { return }
                    self.rdp?.disconnect()
                    self.update("failed", message: WireGuardError.transport.localizedDescription, attempt: attempt)
                    self.generation = UUID()
                }
            }
            tunnelTask = Task { [weak self] in
                do {
                    let endpoint = try await Task.detached(priority: .userInitiated) {
                        try transport.start(
                            id: tunnelID, configuration: configuration, credential: keys, host: host, port: port,
                            onExit: onExit)
                    }.value
                    guard let self, self.generation == attempt, !Task.isCancelled else {
                        transport.stop()
                        return
                    }
                    self.startProtocol(
                        credential: credential, attempt: attempt, tunnelPort: endpoint.port, tunnelToken: endpoint.token
                    )
                } catch {
                    guard let self, self.generation == attempt, !Task.isCancelled else {
                        transport.stop()
                        return
                    }
                    self.update(
                        "failed",
                        message: (error as? WireGuardError)?.localizedDescription
                            ?? WireGuardError.transport.localizedDescription, attempt: attempt)
                }
            }
        } catch {
            update(
                "failed",
                message: (error as? WireGuardError)?.localizedDescription
                    ?? WireGuardError.unavailable.localizedDescription, attempt: attempt)
        }
    }
    private func startProtocol(
        credential: ConnectionCredential, attempt previousAttempt: UUID? = nil,
        tunnelPort: Int = 0, tunnelToken: String? = nil
    ) {
        generation = previousAttempt ?? UUID()
        let attempt = generation
        state = .connecting
        message = "Connecting…"
        if let terminal {
            let client = URSSHClient()
            ssh = client
            files.attach(client)
            let fileController = files
            client.onFiles = { [weak self, fileController] id, result, error in
                DispatchQueue.main.async {
                    guard let self, self.generation == attempt else { return }
                    fileController.receive(id: id, result: result, error: error)
                }
            }
            client.onFileProgress = { [weak self, fileController] id, bytes, total in
                DispatchQueue.main.async {
                    guard let self, self.generation == attempt else { return }
                    fileController.receiveProgress(id: id, bytes: bytes, total: total)
                }
            }
            terminal.sendBytes = { [weak client] in client?.send($0) }
            terminal.resize = { [weak client] cols, rows in client?.resizeColumns(cols, rows: rows) }
            terminal.updateTitle = { [weak self] title in self?.remoteTitle = title }
            client.onStatus = { [weak self] status, message in
                DispatchQueue.main.async { self?.update(status, message: message, attempt: attempt) }
            }
            client.onData = { [weak self] data in
                DispatchQueue.main.sync {
                    guard let self, self.generation == attempt else { return }
                    self.terminal?.view.feed(byteArray: Array(data)[...])
                }
            }
            client.onTrust = trustCallback(attempt: attempt)
            client.onPrompt = { [weak self] prompt, echo in
                let waiter = PromptWaiter()
                DispatchQueue.main.async {
                    guard let self, self.generation == attempt, self.state.active else {
                        waiter.resolve(nil)
                        return
                    }
                    self.pendingWaiters.append(waiter)
                    self.workspace?.enqueue(
                        SessionPrompt(
                            sessionID: self.id, kind: .interactive, title: "SSH authentication", details: prompt,
                            echo: echo, waiter: waiter))
                }
                return waiter.wait()
            }
            client.connectHost(
                profile.host, port: profile.port, username: profile.username, password: credential.password,
                privateKey: credential.privateKey, authentication: profile.authentication.rawValue)
        } else if let desktop {
            let client = URRDPClient()
            rdp = client
            client.tunnelPort = tunnelPort
            client.tunnelToken = tunnelToken
            client.onStatus = { [weak self] status, message in
                DispatchQueue.main.async { self?.update(status, message: message, attempt: attempt) }
            }
            client.onTrust = trustCallback(attempt: attempt)
            client.onFrame = { [weak desktop] data, width, height, stride in
                desktop?.submit(data, width: width, height: height, stride: stride)
            }
            client.onCursor = { [weak desktop] data, width, height, x, y in
                DispatchQueue.main.async {
                    desktop?.setRemoteCursor(data, width: width, height: height, hotX: x, hotY: y)
                }
            }
            client.onClipboard = { [weak self] text in
                DispatchQueue.main.async {
                    guard let self, self.generation == attempt, self.state == .connected, self.profile.clipboard,
                        self.isSelected
                    else { return }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    self.clipboardChange = NSPasteboard.general.changeCount
                }
            }
            desktop.sendKey = { [weak client] code, down, extended in
                client?.sendScanCode(code, pressed: down, extended: extended)
            }
            desktop.sendUnicode = { [weak client] code, down in client?.sendUnicode(code, pressed: down) }
            desktop.preparePaste = { [weak self] in self?.syncClipboard() }
            desktop.sendPointer = { [weak client] flags, x, y in client?.sendPointerFlags(flags, x: x, y: y) }
            desktop.resizeRemote = { [weak self, weak client] width, height, scale in
                guard let self, self.profile.displayMode == .fit, self.profile.dynamicResolution else { return }
                client?.resizeWidth(width, height: height, scale: scale)
            }
            desktop.withInitialSize(width: profile.desktopWidth, height: profile.desktopHeight) {
                [weak self, weak client] size in
                guard let self, self.generation == attempt, self.state.active else { return }
                client?.connectHost(
                    self.profile.host, port: self.profile.port, username: self.profile.username,
                    domain: self.profile.domain,
                    password: credential.password, width: Int(size.width), height: Int(size.height), scale: 100,
                    clipboard: self.profile.clipboard, audioPlayback: self.profile.audioPlayback)
            }
        }
    }
    private func trustCallback(attempt: UUID) -> (String, String) -> Bool {
        { [weak self] fingerprint, details in
            let waiter = PromptWaiter()
            DispatchQueue.main.async {
                guard let self, self.generation == attempt, self.state.active, let workspace = self.workspace else {
                    waiter.resolve(nil)
                    return
                }
                let previous = workspace.trust.fingerprint(for: self.profile.endpointKey)
                if previous == fingerprint {
                    waiter.resolve("trusted")
                    return
                }
                self.pendingWaiters.append(waiter)
                workspace.enqueue(
                    SessionPrompt(
                        sessionID: self.id, kind: .trust,
                        title: previous == nil ? "Verify server identity" : "Server identity has changed",
                        details: details, fingerprint: fingerprint, previousFingerprint: previous, waiter: waiter))
            }
            return waiter.wait() == "trusted"
        }
    }
    private func update(_ status: String, message: String, attempt: UUID) {
        guard generation == attempt else { return }
        state = SessionState(rawValue: status) ?? .failed
        self.message = message
        logs.append(SessionLog(message: message))
        if logs.count > 200 { logs.removeFirst(logs.count - 200) }
        if state == .connected {
            if profile.kind == .ssh && sshMode != .terminal { files.showFiles() }
            desktop?.inputEnabled = true
            desktop?.requestResize()
            startClipboardTimer()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self, self.isSelected else { return }
                self.focus()
            }
        }
        if !state.active {
            files.disconnected()
            tunnelTask?.cancel()
            tunnel?.stop()
            tunnel = nil
            cancelPrompts()
            stopClipboard()
            desktop?.cancelPendingDisplayWork()
            desktop?.releaseInput()
            desktop?.inputEnabled = false
        }
    }
    func askForCredentials() {
        let waiter = PromptWaiter()
        pendingWaiters.append(waiter)
        workspace?.enqueue(
            SessionPrompt(
                sessionID: id, kind: .credentials, title: "Connect to \(profile.name)",
                details: "\(profile.username)@\(profile.host):\(profile.port)", waiter: waiter))
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = waiter.wait()
            DispatchQueue.main.async {
                guard let self, self.state == .waiting else { return }
                guard let result, let data = result.data(using: .utf8),
                    let credential = try? JSONDecoder().decode(ConnectionCredential.self, from: data)
                else {
                    self.disconnect()
                    return
                }
                self.start(credential: credential)
            }
        }
    }
    func disconnect() {
        generation = UUID()
        tunnelTask?.cancel()
        tunnelTask = nil
        tunnel?.stop()
        tunnel = nil
        cancelPrompts()
        stopClipboard()
        desktop?.cancelPendingDisplayWork()
        desktop?.releaseInput()
        desktop?.inputEnabled = false
        files.disconnected()
        ssh?.disconnect()
        rdp?.disconnect()
        generation = UUID()
        state = .disconnected
        message = "Disconnected"
        logs.append(SessionLog(message: message))
    }
    private func cancelPrompts() {
        pendingWaiters.forEach { $0.resolve(nil) }
        pendingWaiters.removeAll()
        workspace?.cancelPrompts(sessionID: id)
    }
    private func startClipboardTimer() {
        guard profile.kind == .rdp, profile.clipboard else { return }
        stopClipboard()
        clipboardChange = -1
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.syncClipboard()
            }
        }
    }
    private func syncClipboard() {
        guard profile.clipboard, isSelected, state == .connected else { return }
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != clipboardChange else { return }
        clipboardChange = pasteboard.changeCount
        rdp?.setClipboardText(pasteboard.string(forType: .string) ?? "")
    }
    private func stopClipboard() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
    }
    func controlAltDelete() { if state == .connected { rdp?.sendControlAltDelete() } }
    func focus() {
        guard profile.kind != .ssh || sshMode != .files else { return }
        if let view = terminal?.view ?? desktop { view.window?.makeFirstResponder(view) }
    }
}

@MainActor private final class WeakRemoteSession {
    weak var value: RemoteSession?
    init(_ value: RemoteSession) { self.value = value }
}
