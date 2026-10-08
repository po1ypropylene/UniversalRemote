import Foundation

enum SSHAuthentication: String, CaseIterable, Identifiable {
    case password, privateKey, interactive
    var id: String { rawValue }
    var title: String {
        switch self {
        case .password: "Password"
        case .privateKey: "Private key"
        case .interactive: "Keyboard-interactive"
        }
    }
}
