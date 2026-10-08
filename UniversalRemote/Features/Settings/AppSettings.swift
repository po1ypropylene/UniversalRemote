import AppKit
import SwiftData
import SwiftUI

struct AppSettings: View {
    @AppStorage("appearance") private var appearance = "System"
    @AppStorage("restoreWorkspace") private var restoreWorkspace = true
    var body: some View {
        Form {
            Picker("Appearance", selection: $appearance) {
                Text("System").tag("System")
                Text("Light").tag("Light")
                Text("Dark").tag("Dark")
            }
            Toggle("Restore session tabs at launch", isOn: $restoreWorkspace)
            Text(
                "Restored tabs stay disconnected until you reconnect. Credentials use Keychain when available, with an owner-only local file fallback for development builds. Local files are not encrypted."
            ).font(
                .caption
            ).foregroundStyle(.secondary)
            LabeledContent("Protocols", value: "SSH · RDP")
            LabeledContent("Version", value: "0.1.0")
        }.formStyle(.grouped).frame(width: 440, height: 240).padding(16)
    }
}
