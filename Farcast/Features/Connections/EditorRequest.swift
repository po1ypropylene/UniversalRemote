import Foundation

struct EditorRequest: Identifiable {
    enum Mode { case create, edit, quick }
    let id = UUID()
    var draft: ConnectionDraft
    var mode: Mode
}
