import SwiftData
import XCTest

@testable import FarcastCore

final class CoreTests: XCTestCase {
    func testValidationAndIPv6Normalization() {
        var profile = ConnectionDraft()
        profile.host = " [2001:db8::1] "
        profile.username = " root "
        profile.normalize()
        XCTAssertNil(profile.validationMessage)
        XCTAssertEqual(profile.host, "2001:db8::1")
        XCTAssertEqual(profile.name, "2001:db8::1")
        XCTAssertEqual(profile.username, "root")
        profile.port = 0
        XCTAssertNotNil(profile.validationMessage)
        profile.port = 65536
        XCTAssertNotNil(profile.validationMessage)
        profile.port = 22
        profile.host = "ssh://example.com"
        XCTAssertNotNil(profile.validationMessage)
        profile.host = "server example.com"
        XCTAssertNotNil(profile.validationMessage)
        for address in ["server.example:3389", "192.0.2.1:3389", "[2001:db8::1]:3389"] {
            profile.host = address
            XCTAssertNotNil(profile.validationMessage)
        }
        profile.host = "2001:db8::1"
        XCTAssertNil(profile.validationMessage)
    }
    func testRedirectedFolderValidation() {
        var draft = ConnectionDraft()
        draft.host = "synthetic.example"
        draft.username = "fixture"
        draft.kind = .rdp
        draft.redirectedFolders = [RDPFolderExport(name: "Documents", bookmark: Data([1]))]
        XCTAssertNil(draft.validationMessage)
        draft.redirectedFolders.append(RDPFolderExport(name: "documents", bookmark: Data([2])))
        XCTAssertNotNil(draft.validationMessage)
        draft.redirectedFolders = [RDPFolderExport(name: "../escape", bookmark: Data([1]))]
        XCTAssertNotNil(draft.validationMessage)
        draft.redirectedFolders = [RDPFolderExport(name: "Files", bookmark: Data())]
        XCTAssertNotNil(draft.validationMessage)
    }
    func testEndpointTrustIsSeparatedByProtocolAndPort() {
        var ssh = ConnectionDraft()
        ssh.host = "SERVER.EXAMPLE"
        ssh.username = "root"
        var rdp = ssh
        rdp.kind = .rdp
        rdp.port = 3389
        XCTAssertNotEqual(ssh.endpointKey, rdp.endpointKey)
        var alternate = ssh
        alternate.port = 2222
        XCTAssertNotEqual(ssh.endpointKey, alternate.endpointKey)
        alternate.port = 22
        alternate.host = "server.example"
        XCTAssertEqual(ssh.endpointKey, alternate.endpointKey)
    }
    @MainActor func testProfileAndFolderPersistenceDoesNotStoreCredentials() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let schema = Schema([SavedConnection.self, ConnectionFolder.self])
        let config = ModelConfiguration(schema: schema, url: root.appendingPathComponent("library.store"))
        let first = try ModelContainer(for: schema, configurations: [config])
        var draft = ConnectionDraft()
        draft.name = "Production"
        draft.host = "server.example"
        draft.username = "operator"
        let folder = ConnectionFolder(name: "Servers")
        draft.folderID = folder.id
        draft.kind = .rdp
        draft.port = 3389
        draft.redirectedFolders = [RDPFolderExport(name: "Mac files", bookmark: Data([1, 2, 3]), readOnly: false)]
        draft.clipboard = true
        draft.audioPlayback = false
        draft.dynamicResolution = false
        draft.displayMode = .matchWindow
        first.mainContext.insert(folder)
        first.mainContext.insert(SavedConnection(draft: draft))
        try first.mainContext.save()
        let reopened = try ModelContainer(for: schema, configurations: [config])
        let profiles = try reopened.mainContext.fetch(FetchDescriptor<SavedConnection>())
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles[0].folderID, folder.id)
        let restored = ConnectionDraft(profiles[0])
        XCTAssertEqual(restored.kind, .rdp)
        XCTAssertEqual(restored.redirectedFolders, draft.redirectedFolders)
        profiles[0].rdpFolderExports = Data([0, 255])
        let damaged = ConnectionDraft(profiles[0])
        XCTAssertTrue(damaged.redirectedFoldersUnavailable)
        XCTAssertNotNil(damaged.validationMessage)
        profiles[0].rdpFolderExports = try JSONEncoder().encode(draft.redirectedFolders)
        XCTAssertTrue(restored.clipboard)
        XCTAssertFalse(restored.audioPlayback)
        XCTAssertFalse(restored.dynamicResolution)
        XCTAssertEqual(restored.displayMode, .matchWindow)
        profiles[0].rdpDisplayMode = nil
        XCTAssertEqual(ConnectionDraft(profiles[0]).displayMode, .fit)
        profiles[0].rdpDisplayMode = "unknown"
        XCTAssertEqual(ConnectionDraft(profiles[0]).displayMode, .fit)
        let fieldNames = schema.entities.first { $0.name == "SavedConnection" }!.properties.map(\.name)
        XCTAssertFalse(fieldNames.contains("password"))
        XCTAssertFalse(fieldNames.contains("privateKey"))
    }
    func testCredentialEncodingPreservesKeyBytesAndPassphrase() throws {
        let secret = ConnectionCredential(
            password: "fixture-passphrase", privateKey: Data([0, 1, 255]), keyName: "fixture.pem")
        let restored = try JSONDecoder().decode(ConnectionCredential.self, from: JSONEncoder().encode(secret))
        XCTAssertEqual(restored.password, secret.password)
        XCTAssertEqual(restored.privateKey, secret.privateKey)
    }
    @MainActor func testTrustStoreRequiresMatchingFingerprintAndCanForget() {
        let name = "Farcast.Tests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let store = TrustStore(defaults: defaults)
        XCTAssertNil(store.fingerprint(for: "SSH|fixture|22"))
        store.remember("SHA256:first", for: "SSH|fixture|22")
        XCTAssertEqual(store.fingerprint(for: "SSH|fixture|22"), "SHA256:first")
        XCTAssertNotEqual(store.fingerprint(for: "SSH|fixture|22"), "SHA256:changed")
        XCTAssertNil(store.fingerprint(for: "RDP|fixture|22"))
        store.forget("SSH|fixture|22")
        XCTAssertNil(store.fingerprint(for: "SSH|fixture|22"))
    }
    func testPromptCancellationAndSingleResolution() {
        let waiter = PromptWaiter()
        waiter.resolve(nil)
        waiter.resolve("late result")
        XCTAssertNil(waiter.wait())
        let accepted = PromptWaiter()
        accepted.resolve("approved")
        accepted.resolve(nil)
        XCTAssertEqual(accepted.wait(), "approved")
    }
}
