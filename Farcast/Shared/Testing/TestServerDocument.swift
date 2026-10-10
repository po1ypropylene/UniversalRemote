import Foundation

/// Local-only input. Never persist or log the document itself: it can contain passwords.
struct TestServerDocument: Decodable {
    let schemaVersion: Int
    let servers: [TestServerEntry]

    static func read(_ data: Data) throws -> TestServerDocument {
        guard data.count <= 1_048_576 else { throw TestServerImportError.invalidDocument }
        let document: TestServerDocument
        do { document = try JSONDecoder().decode(Self.self, from: data) } catch {
            throw TestServerImportError.invalidDocument
        }
        guard document.schemaVersion == 1, document.servers.count <= 100 else {
            throw TestServerImportError.invalidDocument
        }
        let enabled = document.servers.filter(\.enabled)
        guard Set(enabled.map(\.id)).count == enabled.count else { throw TestServerImportError.duplicateID }
        for entry in enabled {
            guard entry.draft.validationMessage == nil else { throw TestServerImportError.invalidConnection }
        }
        return document
    }

    var enabledServers: [TestServerEntry] { servers.filter(\.enabled) }
}

struct TestServerEntry: Decodable, Identifiable {
    let id: UUID
    let enabled: Bool
    let name: String
    let protocolName: RemoteProtocol
    let host: String
    let port: Int
    let username: String
    let domain: String?
    let password: String?
    /// Automation only. UI connections always ask the user about unknown server identities.
    let expectedFingerprint: String?

    enum CodingKeys: String, CodingKey {
        case id, enabled, name, host, port, username, domain, password, expectedFingerprint
        case protocolName = "protocol"
    }

    var draft: ConnectionDraft {
        var draft = ConnectionDraft()
        draft.id = id
        draft.name = name
        draft.kind = protocolName
        draft.host = host
        draft.port = port
        draft.username = username
        draft.domain = domain ?? ""
        draft.normalize()
        return draft
    }
}

enum TestServerImportError: LocalizedError {
    case invalidDocument, invalidConnection, duplicateID
    var errorDescription: String? {
        switch self {
        case .invalidDocument: "Choose a version 1 test-server JSON document (at most 100 entries and 1 MB)."
        case .invalidConnection: "An enabled entry has an invalid host, port, or username. Check the file locally."
        case .duplicateID: "Enabled entries must have different connection IDs."
        }
    }
}
