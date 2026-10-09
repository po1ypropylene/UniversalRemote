import Foundation
import SwiftData

@Model final class SavedWireGuard {
    @Attribute(.unique) var id: UUID
    var name: String
    // Encoded metadata only. Private/preshared keys use the credential store.
    var configurationData: Data
    var created: Date
    init(id: UUID = UUID(), name: String, configuration: WireGuardConfiguration) throws {
        self.id = id
        self.name = name
        configurationData = try JSONEncoder().encode(configuration)
        created = Date()
    }
    func configuration() throws -> WireGuardConfiguration {
        try JSONDecoder().decode(WireGuardConfiguration.self, from: configurationData)
    }
}
