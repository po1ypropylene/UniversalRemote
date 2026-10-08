import AppKit
import Combine
import SwiftData
import UniformTypeIdentifiers

@MainActor final class Workspace: ObservableObject {
    @Published var sessions: [RemoteSession] = []
    @Published var selectedSessionID: UUID?
    @Published var prompts: [SessionPrompt] = []
    @Published var error: String?
    @Published var testServerImport: TestServerImportRequest?
    @Published var editor: EditorRequest?
    @Published var showInspector = false
    let trust = TrustStore()
    var selectedSession: RemoteSession? { sessions.first { $0.id == selectedSessionID } }
    func chooseTestServerFile() {
        let panel = NSOpenPanel()
        panel.title = "Import Test Servers"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 1_048_576 else { throw TestServerImportError.invalidDocument }
            let document = try TestServerDocument.read(Data(contentsOf: url))
            guard !document.enabledServers.isEmpty else {
                error =
                    "No enabled test servers. Fill in the local file and set enabled to true for each server you want to import."
                return
            }
            testServerImport = TestServerImportRequest(document: document)
        } catch let problem as TestServerImportError {
            error = problem.localizedDescription
        } catch {
            self.error = "The test-server file could not be read. Check its format and permissions locally."
        }
    }
    func connect(_ draft: ConnectionDraft, credential: ConnectionCredential? = nil, persistent: Bool = true) {
        guard draft.validationMessage == nil else {
            error = draft.validationMessage
            return
        }
        do {
            let stored =
                draft.kind == .ssh && draft.authentication == .interactive
                ? ConnectionCredential() : try credential ?? CredentialStore.load(draft.id)
            let session = RemoteSession(profile: draft, workspace: self, persistent: persistent)
            sessions.append(session)
            select(session.id)
            if let stored { session.start(credential: stored) } else { session.askForCredentials() }
            persistWorkspace()
        } catch { self.error = error.localizedDescription }
    }
    func select(_ id: UUID?) {
        selectedSession?.desktop?.releaseInput()
        selectedSessionID = id
        for session in sessions { session.isSelected = session.id == id }
        DispatchQueue.main.async { [weak self] in self?.selectedSession?.focus() }
    }
    func close(_ session: RemoteSession) {
        let index = sessions.firstIndex { $0.id == session.id } ?? 0
        session.disconnect()
        sessions.removeAll { $0.id == session.id }
        if selectedSessionID == session.id {
            select(sessions.isEmpty ? nil : sessions[min(index, sessions.count - 1)].id)
        }
        persistWorkspace()
    }
    func reconnect(_ session: RemoteSession) {
        let draft = session.profile
        let persistent = session.persistent
        close(session)
        connect(draft, persistent: persistent)
    }
    func enqueue(_ prompt: SessionPrompt) { prompts.append(prompt) }
    func cancelPrompts(sessionID: UUID) {
        prompts.filter { $0.sessionID == sessionID }.forEach { $0.waiter.resolve(nil) }
        prompts.removeAll { $0.sessionID == sessionID }
    }
    func answer(_ prompt: SessionPrompt, value: String?, remember: Bool = false) {
        if remember, prompt.kind == .trust, let session = sessions.first(where: { $0.id == prompt.sessionID }),
            let fingerprint = prompt.fingerprint
        {
            trust.remember(fingerprint, for: session.profile.endpointKey)
        }
        prompt.waiter.resolve(value)
        prompts.removeAll { $0.id == prompt.id }
    }
    func saveCredentials(_ credential: ConnectionCredential, for prompt: SessionPrompt) throws {
        guard let session = sessions.first(where: { $0.id == prompt.sessionID }), session.persistent else { return }
        try CredentialStore.save(credential, for: session.profile.id)
    }
    func reorder(_ source: UUID, before destination: UUID) {
        guard let from = sessions.firstIndex(where: { $0.id == source }),
            let to = sessions.firstIndex(where: { $0.id == destination }), from != to
        else { return }
        let session = sessions.remove(at: from)
        sessions.insert(session, at: to)
        persistWorkspace()
    }
    func persistWorkspace() {
        UserDefaults.standard.set(sessions.map { $0.profile.id.uuidString }, forKey: "workspaceConnections")
    }
    func restoreWorkspace(_ saved: [SavedConnection]) {
        guard sessions.isEmpty, UserDefaults.standard.object(forKey: "restoreWorkspace") as? Bool ?? true else {
            return
        }
        for id in UserDefaults.standard.stringArray(forKey: "workspaceConnections") ?? [] {
            guard let profile = saved.first(where: { $0.id.uuidString == id }) else { continue }
            let session = RemoteSession(profile: ConnectionDraft(profile), workspace: self)
            session.state = .disconnected
            session.message = "Restored · reconnect when ready"
            sessions.append(session)
        }
        select(sessions.first?.id)
    }
    func shutdown() {
        persistWorkspace()
        sessions.forEach { $0.disconnect() }
    }
}
