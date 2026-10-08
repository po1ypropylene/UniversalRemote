import Foundation

struct SessionPrompt: Identifiable {
    enum Kind { case trust, interactive, credentials }
    let id = UUID()
    let sessionID: UUID
    let kind: Kind
    let title: String
    let details: String
    var fingerprint: String?
    var previousFingerprint: String?
    var echo = false
    let waiter: PromptWaiter
}
