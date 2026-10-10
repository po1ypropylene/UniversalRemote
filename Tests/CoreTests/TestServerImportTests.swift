import SwiftData
import XCTest

@testable import FarcastCore

final class TestServerImportTests: XCTestCase {
    private func document(enabled: Bool = true, port: Int = 22) -> Data {
        Data(
            """
            {"schemaVersion":1,"servers":[{
              "id":"58C79947-6D5B-4515-8B76-1729C2D30A61","enabled":\(enabled),
              "name":" Test SSH ","protocol":"SSH","host":" server.example ",
              "port":\(port),"username":" operator ","password":"test-only-secret"
            }]}
            """.utf8)
    }

    func testDisabledEntriesAreNotImportedAndEnabledMetadataIsNormalized() throws {
        XCTAssertTrue(try TestServerDocument.read(document(enabled: false, port: 0)).enabledServers.isEmpty)
        let draft = try TestServerDocument.read(document()).enabledServers[0].draft
        XCTAssertEqual(draft.name, "Test SSH")
        XCTAssertEqual(draft.host, "server.example")
        XCTAssertEqual(draft.username, "operator")
    }

    func testMalformedAndInvalidInputsProduceRedactedErrors() {
        for data in [Data("test-only-secret".utf8), document(port: 65536), Data(repeating: 32, count: 1_048_577)] {
            XCTAssertThrowsError(try TestServerDocument.read(data)) { error in
                XCTAssertFalse(error.localizedDescription.contains("test-only-secret"))
                XCTAssertTrue(error is TestServerImportError)
            }
        }
        let unsupported = Data(
            String(decoding: document(), as: UTF8.self).replacingOccurrences(
                of: "schemaVersion\":1", with: "schemaVersion\":2"
            ).utf8)
        XCTAssertThrowsError(try TestServerDocument.read(unsupported))
    }

    func testDuplicateEnabledIDsAreRejectedBeforeImport() throws {
        let first = try JSONSerialization.jsonObject(with: document()) as! [String: Any]
        let entry = (first["servers"] as! [[String: Any]])[0]
        let duplicated = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "servers": [entry, entry]])
        XCTAssertThrowsError(try TestServerDocument.read(duplicated))
    }

    @MainActor func testImportCreatesVisibleFolderAndDoesNotOverwriteExistingProfiles() throws {
        let schema = Schema([SavedConnection.self, ConnectionFolder.self])
        let container = try ModelContainer(
            for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = container.mainContext
        let input = try TestServerDocument.read(document())
        XCTAssertEqual(try TestServerImporter.insert(input, into: context).count, 1)
        let profiles = try context.fetch(FetchDescriptor<SavedConnection>())
        let folders = try context.fetch(FetchDescriptor<ConnectionFolder>())
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(folders.count, 1)
        XCTAssertEqual(folders[0].name, "Test Servers")
        XCTAssertEqual(profiles[0].folderID, folders[0].id)
        profiles[0].name = "User edited name"
        try context.save()
        XCTAssertTrue(try TestServerImporter.insert(input, into: context).isEmpty)
        XCTAssertEqual(profiles[0].name, "User edited name")
        XCTAssertEqual(try context.fetch(FetchDescriptor<ConnectionFolder>()).count, 1)
    }
}
