import SwiftTerm
import SwiftUI

struct SessionPane: View {
    @ObservedObject var session: RemoteSession
    @ObservedObject var workspace: Workspace
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if let terminal = session.terminal {
                    TerminalSurface(controller: terminal).padding(8).background(
                        SwiftUI.Color(nsColor: terminal.view.nativeBackgroundColor))
                } else if let desktop = session.desktop {
                    DesktopSurface(view: desktop)
                }
                if session.state != .connected {
                    VStack(spacing: 16) {
                        if session.state.active {
                            ProgressView().controlSize(.large)
                        } else {
                            Image(systemName: session.state == .failed ? "exclamationmark.triangle" : "network").font(
                                .system(size: 36)
                            ).foregroundStyle(session.state.color)
                        }
                        Text(session.state.title).font(.title2.weight(.semibold))
                        Text(session.message).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(
                            maxWidth: 460
                        ).textSelection(.enabled)
                        if session.state.active {
                            Button("Cancel connection") { session.disconnect() }
                        } else {
                            HStack {
                                Button("Close") { workspace.close(session) }
                                Button("Reconnect") { workspace.reconnect(session) }.buttonStyle(.glassProminent)
                            }
                        }
                    }.padding(32).glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24)).padding(32)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack(spacing: 9) {
                Circle().fill(session.state.color).frame(width: 6, height: 6)
                Text(session.state.title)
                Text("·").foregroundStyle(.tertiary)
                Text("\(session.profile.username)@\(session.profile.host):\(String(session.profile.port))").lineLimit(1)
                    .textSelection(.enabled)
                Spacer()
                if session.profile.kind == .rdp {
                    Button("Ctrl + Alt + Delete") { session.controlAltDelete() }.disabled(session.state != .connected)
                } else {
                    Button {
                        session.terminal?.zoom(-1)
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    Button {
                        session.terminal?.zoom(1)
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    Button {
                        session.terminal?.find()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }.help("Find in terminal")
                }
                Text(session.profile.kind.rawValue).fontWeight(.semibold)
            }.buttonStyle(.borderless).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 14).padding(
                .vertical, 8
            ).background(.bar)
        }
    }
}
