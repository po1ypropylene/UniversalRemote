import AppKit
import Combine
import SwiftData

// Transport doubles keep coordination tests away from networks, Keychain and UI prompts.
@MainActor final class RemoteSession: ObservableObject, Identifiable {
    let id = UUID()
    let profile: ConnectionDraft
    let persistent: Bool
    var state: SessionState = .disconnected
    var message = ""
    var isSelected = false
    var credentialsRejected = false
    var desktop: DesktopDouble? { nil }
    init(profile: ConnectionDraft, workspace: Workspace, persistent: Bool = true) {
        self.profile = profile
        self.persistent = persistent
    }
    func start(credential: ConnectionCredential) { state = .connected }
    func askForCredentials() { state = .authenticating }
    func disconnect() { state = .disconnected }
    func focus() {}
}
@MainActor final class DesktopDouble { func releaseInput() {} }
struct TestServerImportRequest {
    let document: TestServerDocument
}

@main struct WorkspaceChecks {
    @MainActor static func main() throws {
        let suite = "com.peterpo.UniversalRemote.WorkspaceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var refuseCredentials = false
        let workspace = Workspace(
            loadCredential: { _ in
                if refuseCredentials { throw CocoaError(.fileReadNoPermission) }
                return ConnectionCredential()
            }, defaults: defaults)
        let container = try ModelContainer(
            for: SavedConnection.self, ConnectionFolder.self, SavedWireGuard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        workspace.modelContext = container.mainContext
        func draft(_ name: String) -> ConnectionDraft {
            var draft = ConnectionDraft()
            draft.name = name
            draft.host = "fixture.invalid"
            draft.username = "fixture"
            return draft
        }
        for name in ["First", "Second", "Third"] { workspace.connect(draft(name)) }
        let first = workspace.sessions[0]
        let second = workspace.sessions[1]
        let third = workspace.sessions[2]
        workspace.reorder(first.id, before: second.id)
        precondition(workspace.sessions.map(\.id) == [first.id, second.id, third.id])
        workspace.reorder(first.id, before: third.id)
        precondition(workspace.sessions.map(\.id) == [second.id, first.id, third.id])
        workspace.reorder(third.id, before: second.id)
        precondition(workspace.sessions.map(\.id) == [third.id, second.id, first.id])
        print("PASS tab reordering in both directions and adjacent drop")

        workspace.select(third.id)
        workspace.reconnect(second)
        let replaced = workspace.sessions[1]
        precondition(replaced.id != second.id && replaced.profile.id == second.profile.id)
        precondition(workspace.selectedSessionID == third.id && second.state == .disconnected)
        print("PASS background reconnect retains position and selected tab")

        var edited = first.profile
        edited.name = "Edited"
        edited.clipboard = true
        let saved = SavedConnection(draft: edited)
        container.mainContext.insert(saved)
        try container.mainContext.save()
        workspace.select(first.id)
        workspace.reconnect(first)
        let selected = workspace.sessions[2]
        precondition(selected.profile.name == "Edited" && selected.profile.clipboard)
        precondition(workspace.selectedSessionID == selected.id && selected.isSelected)
        print("PASS selected reconnect reloads saved edits in place")

        refuseCredentials = true
        workspace.reconnect(selected)
        precondition(workspace.sessions[2] === selected && selected.state == .connected)
        precondition(workspace.selectedSessionID == selected.id && workspace.error != nil)
        refuseCredentials = false
        saved.port = 0
        workspace.reconnect(selected)
        precondition(workspace.sessions[2] === selected && selected.state == .connected)
        saved.port = 22
        print("PASS credential and validation failures preserve existing session")

        workspace.connect(draft("Temporary"), persistent: false)
        let temporary = workspace.sessions.last!
        let restored = defaults.stringArray(forKey: "workspaceConnections")!
        precondition(!restored.contains(temporary.profile.id.uuidString))
        container.mainContext.insert(SavedConnection(draft: temporary.profile))
        workspace.reconnect(temporary)
        precondition(workspace.sessions.last?.persistent == false)
        print("PASS ad hoc reconnect and restoration exclusion")

        let count = workspace.sessions.count
        workspace.close(first)
        workspace.reconnect(first)
        precondition(workspace.sessions.count == count)
        workspace.close(workspace.sessions.last!)
        precondition(workspace.selectedSessionID == selected.id)
        print("PASS stale actions and close selection")

        selected.credentialsRejected = true
        refuseCredentials = true
        workspace.reconnect(selected)
        let retry = workspace.selectedSession!
        precondition(retry.id != selected.id && retry.state == .authenticating)
        precondition(retry.profile.id == selected.profile.id && retry.persistent)
        precondition(workspace.sessions[2] === retry && selected.state == .disconnected)
        print("PASS rejected SSH credentials prompt afresh without reloading saved credentials")

        var interactive = draft("Interactive retry")
        interactive.authentication = .interactive
        workspace.connect(interactive)
        let interactiveSession = workspace.sessions.last!
        interactiveSession.credentialsRejected = true
        workspace.reconnect(interactiveSession)
        precondition(workspace.sessions.last!.state == .connected)
        precondition(workspace.sessions.last!.profile.authentication == .interactive)
        print("PASS interactive retry uses server prompts without saved credential lookup")
    }
}
