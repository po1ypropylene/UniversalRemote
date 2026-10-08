import SwiftUI

struct SessionTab: View {
    @ObservedObject var session: RemoteSession
    @ObservedObject var workspace: Workspace
    var body: some View {
        HStack(spacing: 8) {
            Button {
                workspace.select(session.id)
            } label: {
                HStack(spacing: 7) {
                    Circle().fill(session.state.color).frame(width: 6, height: 6)
                    Image(systemName: session.profile.kind.icon)
                    Text(session.profile.name).fontWeight(
                        workspace.selectedSessionID == session.id ? .semibold : .regular
                    )
                    .lineLimit(1).frame(maxWidth: 170)
                }
            }.buttonStyle(.plain)
            Button {
                workspace.close(session)
            } label: {
                Image(systemName: "xmark").font(.system(size: 9, weight: .semibold)).padding(5)
            }.buttonStyle(.plain).help("Close session")
        }.padding(.leading, 12).padding(.trailing, 5).padding(.vertical, 9)
            .glassEffect(
                workspace.selectedSessionID == session.id
                    ? .regular.tint(.accentColor.opacity(0.25)).interactive() : .regular.interactive(),
                in: Capsule()
            )
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(workspace.selectedSessionID == session.id ? .isSelected : [])
            .contextMenu {
                Button("Reconnect") { workspace.reconnect(session) }
                Button("Disconnect") { session.disconnect() }
                Button("Close") { workspace.close(session) }
            }
    }
}
