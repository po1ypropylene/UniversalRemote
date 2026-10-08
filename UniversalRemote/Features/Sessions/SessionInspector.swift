import SwiftUI

struct SessionInspector: View {
    @ObservedObject var session: RemoteSession
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Connection details").font(.headline)
                LabeledContent("Protocol", value: session.profile.kind.rawValue)
                LabeledContent("Host", value: session.profile.host)
                LabeledContent("Port", value: String(session.profile.port))
                LabeledContent("User", value: session.profile.username)
                if !session.profile.domain.isEmpty { LabeledContent("Domain", value: session.profile.domain) }
                if !session.remoteTitle.isEmpty { Text(session.remoteTitle).font(.caption).foregroundStyle(.secondary) }
                if !session.profile.notes.isEmpty {
                    Divider()
                    Text(session.profile.notes).foregroundStyle(.secondary)
                }
                Divider()
                Text("Activity").font(.headline)
                ForEach(session.logs) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(log.time, style: .time).font(.caption2).foregroundStyle(.tertiary)
                        Text(log.message).font(.caption).textSelection(.enabled)
                    }
                }
                Text("Passwords and terminal contents are not recorded here.").font(.caption2).foregroundStyle(
                    .secondary)
            }.padding(20)
        }.background(.background)
    }
}
