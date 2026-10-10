import AppKit
import SwiftData
import SwiftUI

@main struct UniversalRemoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var workspace = Workspace()
    @AppStorage("appearance") private var appearance = "System"
    private let container: ModelContainer?
    private let startupError: String?
    init() {
        if ProcessInfo.processInfo.arguments.contains("--verify-bundle-launch") {
            print("Universal Remote loader check passed")
            exit(EXIT_SUCCESS)
        }
        if ProcessInfo.processInfo.arguments.contains("--verify-wireguard-helper") {
            exit(WireGuardBundleProbe.run() ? EXIT_SUCCESS : EXIT_FAILURE)
        }
        do {
            container = try ModelContainer(for: SavedConnection.self, ConnectionFolder.self, SavedWireGuard.self)
            startupError = nil
        } catch {
            container = nil
            startupError = error.localizedDescription
        }
    }
    var body: some Scene {
        Window("Universal Remote", id: "workspace") {
            Group {
                if let container {
                    WorkspaceView(workspace: workspace).modelContainer(container).onAppear {
                        delegate.workspace = workspace
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle)
                        Text("Connection library could not be opened").font(.title2)
                        Text(startupError ?? "Unknown storage error").textSelection(.enabled)
                        Button("Quit") { NSApp.terminate(nil) }
                    }.padding(40).frame(width: 600)
                }
            }.preferredColorScheme(appearance == "Dark" ? .dark : appearance == "Light" ? .light : nil)
        }.defaultSize(width: 1280, height: 820)
            .commands {
                CommandGroup(replacing: .newItem) {
                    Button("New Connection…") {
                        workspace.editor = EditorRequest(draft: ConnectionDraft(), mode: .create)
                    }.keyboardShortcut("n")
                    Button("Quick Connect…") {
                        workspace.editor = EditorRequest(draft: ConnectionDraft(), mode: .quick)
                    }.keyboardShortcut("k")
                }
                CommandGroup(replacing: .saveItem) {
                    Button("WireGuard Connections…") { workspace.showWireGuard = true }
                    Button("Import Test Servers…") { workspace.chooseTestServerFile() }
                }
                CommandGroup(replacing: .textEditing) {
                    if let session = workspace.selectedSession {
                        FindInTerminalCommandButton(session: session)
                    } else {
                        Button("Find in Terminal…") {}.keyboardShortcut("f").disabled(true)
                    }
                }
                CommandMenu("Session") {
                    Button("Reconnect") { if let session = workspace.selectedSession { workspace.reconnect(session) } }
                        .keyboardShortcut("r", modifiers: [.command, .shift]).disabled(workspace.selectedSession == nil)
                    Button("Disconnect") { workspace.selectedSession?.disconnect() }.disabled(
                        workspace.selectedSession?.state.active != true)
                    Button("Close Session") { if let session = workspace.selectedSession { workspace.close(session) } }
                        .keyboardShortcut("w").disabled(workspace.selectedSession == nil)
                    Divider()
                    Button("Send Ctrl+Alt+Delete") { workspace.selectedSession?.controlAltDelete() }.disabled(
                        workspace.selectedSession?.profile.kind != .rdp
                            || workspace.selectedSession?.state != .connected)
                    Button("Connection Details") { workspace.showInspector.toggle() }.keyboardShortcut(
                        "i", modifiers: [.command, .option])
                }
            }
        Settings { AppSettings() }
    }
}

private struct FindInTerminalCommandButton: View {
    @ObservedObject var session: RemoteSession
    var body: some View {
        Button("Find in Terminal…") {
            guard session.terminalAvailable else { return }
            session.terminal?.find()
        }.keyboardShortcut("f").disabled(session.terminal == nil || !session.terminalAvailable)
    }
}
