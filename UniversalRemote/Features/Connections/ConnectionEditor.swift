import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ConnectionEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ConnectionFolder.order) private var folders: [ConnectionFolder]
    @Query private var saved: [SavedConnection]
    @ObservedObject var workspace: Workspace
    let request: EditorRequest
    @State private var draft: ConnectionDraft
    @State private var credential = ConnectionCredential()
    @State private var remember = true
    @State private var error: String?
    init(workspace: Workspace, request: EditorRequest) {
        self.workspace = workspace
        self.request = request
        _draft = State(initialValue: request.draft)
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: draft.kind.icon).font(.title2).foregroundStyle(.tint).frame(width: 44, height: 44)
                    .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        request.mode == .quick
                            ? "Quick Connect" : request.mode == .edit ? "Edit connection" : "New connection"
                    ).font(.title3.weight(.semibold))
                    Text("A secure connection, in your workspace.").foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(24)
            Divider()
            ScrollView {
                Form {
                    Section("Connection") {
                        TextField("Name", text: $draft.name, prompt: Text("Defaults to host name"))
                        Picker("Protocol", selection: $draft.kind) {
                            ForEach(RemoteProtocol.allCases) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.segmented)
                        HStack(spacing: 20) {
                            TextField("Host", text: $draft.host, prompt: Text("Host name or IP address"))
                            TextField("Port", value: $draft.port, format: .number.grouping(.never))
                                .frame(width: 140)
                        }
                        TextField("Username", text: $draft.username)
                        if draft.kind == .rdp {
                            TextField("Domain", text: $draft.domain, prompt: Text("Optional"))
                        }
                        if draft.kind == .ssh {
                            Picker("Authentication", selection: $draft.authentication) {
                                ForEach(SSHAuthentication.allCases) { Text($0.title).tag($0) }
                            }
                        }
                        credentialFields
                    }
                    DisclosureGroup("Organization & notes") { organization }
                    DisclosureGroup(draft.kind == .ssh ? "Terminal options" : "Display options") { appearance }
                    DisclosureGroup("Sharing & server identity") { advanced }
                }.formStyle(.grouped).padding(.vertical, 8)
            }.frame(height: 530)
            Divider()
            HStack {
                if let error {
                    Text(error).font(.caption).foregroundStyle(.red).lineLimit(3)
                } else if let message = draft.validationMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                if request.mode != .quick {
                    Button("Save") { commit(connect: false) }.disabled(draft.validationMessage != nil)
                }
                Button(request.mode == .quick ? "Connect" : "Save & Connect") { commit(connect: true) }.buttonStyle(
                    .glassProminent
                ).keyboardShortcut(.defaultAction).disabled(draft.validationMessage != nil)
            }.padding(18)
        }.frame(width: 760)
            .onAppear {
                do { if let stored = try CredentialStore.load(draft.id) { credential = stored } } catch {
                    self.error = error.localizedDescription
                }
            }
            .onChange(of: draft.kind) { old, new in
                if draft.port == old.defaultPort { draft.port = new.defaultPort }
                credential = ConnectionCredential()
                if new == .rdp { draft.authentication = .password }
            }
            .onChange(of: draft.authentication) { _, _ in credential = ConnectionCredential() }
    }
    private var organization: some View {
        Group {
            Section("Connection") {
                Picker("Folder", selection: $draft.folderID) {
                    Text("Unfiled").tag(UUID?.none)
                    ForEach(folders) { Text($0.name).tag(Optional($0.id)) }
                }
                Toggle("Favorite", isOn: $draft.favorite)
            }
            Section("Notes") { TextEditor(text: $draft.notes).frame(height: 90).font(.body) }
        }
    }
    @ViewBuilder private var credentialFields: some View {
        if draft.kind == .rdp || draft.authentication == .password {
            SecureField("Password", text: $credential.password)
        }
        if draft.kind == .ssh && draft.authentication == .privateKey {
            HStack {
                Text(credential.keyName ?? "No private key selected").foregroundStyle(.secondary)
                Spacer()
                Button("Choose Key…") { importKey() }
            }
            SecureField("Key passphrase", text: $credential.password)
            Text(
                "The imported key is saved on this Mac with your credentials. The original file stays unchanged."
            ).font(.caption).foregroundStyle(.secondary)
        }
        if draft.kind == .ssh && draft.authentication == .interactive {
            Text("The server’s authentication questions will appear when you connect.").foregroundStyle(
                .secondary)
        }
        if request.mode != .quick {
            Toggle("Save credentials on this Mac", isOn: $remember)
            Text(
                "Uses Keychain when available, otherwise owner-only files in your Library/Application Support folder. Local files are not encrypted. Turn off to enter credentials each time."
            ).font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("Credentials are used for this session only.").font(.caption).foregroundStyle(.secondary)
        }
    }
    private var appearance: some View {
        Group {
            if draft.kind == .ssh {
                Section("Terminal") {
                    Picker("Theme", selection: $draft.terminalTheme) {
                        ForEach(["Midnight", "Solarized", "Paper"], id: \.self) { Text($0) }
                    }
                    Stepper("Font size: \(Int(draft.fontSize)) pt", value: $draft.fontSize, in: 9...32)
                    Text("10,000 lines of scrollback. Use ⌘F to find text in a session.").font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Remote desktop") {
                    Toggle("Match desktop size to window", isOn: $draft.dynamicResolution)
                    TextField("Initial width", value: $draft.desktopWidth, format: .number.grouping(.never))
                    TextField("Initial height", value: $draft.desktopHeight, format: .number.grouping(.never))
                    Text(
                        "Retina scaling is applied after the session connects. Servers without dynamic resize remain fitted to the window."
                    ).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
    private var advanced: some View {
        Group {
            if draft.kind == .rdp {
                Section("Sharing") {
                    Toggle("Share text clipboard", isOn: $draft.clipboard)
                    Text(
                        "While this session is selected, copied text can pass between your Mac and the remote desktop. File sharing is not enabled."
                    ).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Server identity") {
                Text("Universal Remote verifies SSH host keys and RDP TLS certificates before sending credentials.")
                    .foregroundStyle(.secondary)
                Button("Forget trusted identity for this server") { workspace.trust.forget(draft.endpointKey) }
            }
        }
    }
    private func importKey() {
        do {
            if let imported = try PrivateKeyPicker.pick() {
                credential.privateKey = imported.data
                credential.keyName = imported.name
            }
        } catch { self.error = error.localizedDescription }
    }
    private func commit(connect: Bool) {
        draft.normalize()
        guard draft.validationMessage == nil else {
            error = draft.validationMessage
            return
        }
        if draft.kind == .ssh && draft.authentication == .privateKey && credential.privateKey == nil {
            error = "Choose a private key first."
            return
        }
        let hasCredential =
            draft.authentication == .privateKey ? credential.privateKey != nil : !credential.password.isEmpty
        do {
            if request.mode != .quick {
                if remember && hasCredential && draft.authentication != .interactive {
                    try CredentialStore.save(credential, for: draft.id)
                } else {
                    try CredentialStore.delete(draft.id)
                }
                if let existing = saved.first(where: { $0.id == draft.id }) {
                    existing.update(from: draft)
                } else {
                    context.insert(SavedConnection(draft: draft))
                }
                try context.save()
            }
            let snapshot = draft
            let secret = credential
            dismiss()
            if connect {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    workspace.connect(
                        snapshot, credential: hasCredential ? secret : nil, persistent: request.mode != .quick)
                }
            }
        } catch { self.error = error.localizedDescription }
    }
}
