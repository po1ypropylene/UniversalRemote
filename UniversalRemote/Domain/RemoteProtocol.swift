import Foundation

enum RemoteProtocol: String, Codable, CaseIterable, Identifiable {
    case ssh = "SSH"
    case rdp = "RDP"
    var id: String { rawValue }
    var icon: String { self == .ssh ? "terminal" : "desktopcomputer" }
    var defaultPort: Int { self == .ssh ? 22 : 3389 }
}
