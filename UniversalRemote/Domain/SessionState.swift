import Foundation

struct SessionLog: Identifiable {
    let id = UUID()
    let time = Date()
    let message: String
}
enum SessionState: String {
    case waiting, connecting, verifying, authenticating, connected, disconnected, failed
    var title: String { rawValue.capitalized }
    var active: Bool { [.waiting, .connecting, .verifying, .authenticating, .connected].contains(self) }
}
