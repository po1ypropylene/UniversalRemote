import SwiftUI

extension SessionState {
    var color: SwiftUI.Color {
        switch self {
        case .connected: .green
        case .failed: .orange
        case .waiting, .connecting, .verifying, .authenticating: .blue
        case .disconnected: .gray
        }
    }
}
