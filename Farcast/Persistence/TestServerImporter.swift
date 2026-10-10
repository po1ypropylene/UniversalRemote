import Foundation
import SwiftData

/// Imports metadata only. The caller separately offers optional Keychain storage.
@MainActor enum TestServerImporter {
    static func insert(_ document: TestServerDocument, into context: ModelContext) throws -> [TestServerEntry] {
        let existingIDs = Set(try context.fetch(FetchDescriptor<SavedConnection>()).map(\.id))
        let additions = document.enabledServers.filter { !existingIDs.contains($0.id) }
        guard !additions.isEmpty else { return [] }
        let folders = try context.fetch(FetchDescriptor<ConnectionFolder>())
        let folder: ConnectionFolder
        if let existing = folders.first(where: { $0.name == "Test Servers" }) {
            folder = existing
        } else {
            folder = ConnectionFolder(name: "Test Servers", order: (folders.map(\.order).max() ?? -1) + 1)
            context.insert(folder)
        }
        for entry in additions {
            var draft = entry.draft
            draft.folderID = folder.id
            context.insert(SavedConnection(draft: draft))
        }
        do { try context.save() } catch {
            context.rollback()
            throw error
        }
        return additions
    }
}
