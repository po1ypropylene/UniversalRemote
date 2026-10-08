import Foundation
import XCTest

@testable import UniversalRemoteCore

final class CredentialStoreTests: XCTestCase {
    func testLocalCredentialsSurviveReopeningAndReplacementWithOwnerOnlyPermissions() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let id = UUID()
        let store = LocalCredentialStore(root: root)
        XCTAssertNil(try store.load(id))
        try store.save(ConnectionCredential(password: "fixture", privateKey: Data([0, 255])), for: id)
        let reopened = LocalCredentialStore(root: root)
        XCTAssertEqual(try reopened.load(id)?.password, "fixture")
        XCTAssertEqual(try reopened.load(id)?.privateKey, Data([0, 255]))
        let file = root.appendingPathComponent(id.uuidString + ".json")
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: root.path)[.posixPermissions] as? Int, 0o700)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? Int, 0o600)
        try store.save(ConnectionCredential(password: "replacement"), for: id)
        XCTAssertEqual(try reopened.load(id)?.password, "replacement")
        XCTAssertNil(try reopened.load(id)?.privateKey)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path).count, 1)
        try store.delete(id)
        try store.delete(id)
        XCTAssertNil(try reopened.load(id))
    }

    func testLocalStoreRejectsSymlinkDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let link = root.appendingPathComponent("link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root)
        XCTAssertThrowsError(
            try LocalCredentialStore(root: link).save(ConnectionCredential(password: "fixture"), for: UUID()))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), ["link"])
    }
}
