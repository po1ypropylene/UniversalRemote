import Foundation
import SwiftData

@main struct LibraryRenameChecks {
    @MainActor static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let schema = Schema([SavedConnection.self, ConnectionFolder.self, SavedWireGuard.self])
        let profileID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let folderID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let tunnelID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        #if PREVIOUS_LIBRARY
            let support = root.appendingPathComponent("Application Support")
            try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            let container = try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, url: support.appendingPathComponent("default.store"))
            )
            let folder = ConnectionFolder(name: "Synthetic folder", order: 7)
            folder.id = folderID
            var draft = ConnectionDraft()
            draft.id = profileID
            draft.name = "Synthetic saved desktop"
            draft.host = "fixture.example"
            draft.kind = .rdp
            draft.port = 3389
            draft.username = "fixture"
            draft.folderID = folderID
            draft.wireGuardID = tunnelID
            draft.favorite = true
            draft.notes = "Synthetic retained notes"
            draft.redirectedFolders = [
                RDPFolderExport(name: "Fixture files", bookmark: Data([1, 2, 3]), readOnly: true)
            ]
            let profile = SavedConnection(draft: draft)
            profile.created = Date(timeIntervalSince1970: 123)
            profile.lastConnected = Date(timeIntervalSince1970: 456)
            let tunnel = try SavedWireGuard(
                id: tunnelID, name: "Synthetic tunnel", configuration: WireGuardConfiguration())
            container.mainContext.insert(folder)
            container.mainContext.insert(profile)
            container.mainContext.insert(tunnel)
            try container.mainContext.save()
            let credentials = LocalCredentialStore(root: support.appendingPathComponent("UniversalRemote/Credentials"))
            try credentials.save(ConnectionCredential(password: "fixture", privateKey: Data([0, 255])), for: profileID)
            try credentials.save(ConnectionCredential(wireGuardPrivateKey: "fixture-key"), for: tunnelID)
            let preferences = root.appendingPathComponent("Preferences")
            try FileManager.default.createDirectory(at: preferences, withIntermediateDirectories: true)
            let settings: [String: Any] = [
                "appearance": "Dark", "restoreWorkspace": true, "workspaceConnections": [profileID.uuidString],
                "trustedServerIdentities": ["SSH:fixture.example:22": "SHA256:synthetic"],
                "sftpHomeAccess": Data([8]), "unrelatedPreference": "exclude",
            ]
            try PropertyListSerialization.data(fromPropertyList: settings, format: .binary, options: 0)
                .write(to: preferences.appendingPathComponent("com.peterpo.UniversalRemote.plist"))
            print("PASS disposable previous-module library seeded")
        #else
            let destinationURL = root.deletingLastPathComponent().appendingPathComponent("farcast.store")
            let configuration = ModelConfiguration(schema: schema, url: destinationURL)
            let container = try ModelContainer(for: schema, configurations: configuration)
            let credentials = LocalCredentialStore(
                root: root.deletingLastPathComponent().appendingPathComponent("Credentials"))
            let suite = "com.peterpo.farcast.MigrationTests.\(UUID())"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let before = try snapshot(root)
            guard
                try ExistingLibraryImporter.importLibrary(
                    from: root, into: container, includeLocalCredentials: true, credentials: credentials,
                    defaults: defaults) == 1
            else { throw ExistingLibraryImportError.invalidSource }
            let reopened = try ModelContainer(for: schema, configurations: configuration)
            let profiles = try reopened.mainContext.fetch(FetchDescriptor<SavedConnection>())
            let folders = try reopened.mainContext.fetch(FetchDescriptor<ConnectionFolder>())
            let tunnels = try reopened.mainContext.fetch(FetchDescriptor<SavedWireGuard>())
            guard profiles.count == 1, folders.count == 1, tunnels.count == 1,
                let profile = profiles.first, profile.id == profileID, profile.folderID == folderID,
                profile.wireGuardID == tunnelID, profile.favorite, profile.notes == "Synthetic retained notes",
                profile.created == Date(timeIntervalSince1970: 123),
                profile.lastConnected == Date(timeIntervalSince1970: 456),
                ConnectionDraft(profile).redirectedFolders.first?.bookmark == Data([1, 2, 3]),
                folders.first?.order == 7, tunnels.first?.id == tunnelID,
                try credentials.load(profileID)?.password == "fixture",
                try credentials.load(profileID)?.privateKey == Data([0, 255]),
                try credentials.load(tunnelID)?.wireGuardPrivateKey == "fixture-key",
                defaults.string(forKey: "appearance") == "Dark",
                defaults.stringArray(forKey: "workspaceConnections") == [profileID.uuidString],
                defaults.dictionary(forKey: "trustedServerIdentities") as? [String: String] == [
                    "SSH:fixture.example:22": "SHA256:synthetic"
                ],
                defaults.object(forKey: "sftpHomeAccess") == nil, defaults.object(forKey: "unrelatedPreference") == nil,
                try snapshot(root) == before
            else { throw ExistingLibraryImportError.invalidSource }
            print(
                "PASS renamed-module library import/reopen preserves identities, metadata, credentials and settings; source bytes unchanged"
            )
        #endif
    }
    static func snapshot(_ root: URL) throws -> [String: Data] {
        var result: [String: Data] = [:]
        let items = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])!
        for case let file as URL in items
        where try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            result[file.path] = try Data(contentsOf: file)
        }
        return result
    }
}
