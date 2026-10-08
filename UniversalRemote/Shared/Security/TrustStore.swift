import Foundation

@MainActor final class TrustStore {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    func fingerprint(for endpoint: String) -> String? { identities[endpoint] }
    private var identities: [String: String] {
        defaults.dictionary(forKey: "trustedServerIdentities") as? [String: String] ?? [:]
    }
    func remember(_ fingerprint: String, for endpoint: String) {
        var saved = identities
        saved[endpoint] = fingerprint
        defaults.set(saved, forKey: "trustedServerIdentities")
    }
    func forget(_ endpoint: String) {
        var saved = identities
        saved.removeValue(forKey: endpoint)
        defaults.set(saved, forKey: "trustedServerIdentities")
    }
}
