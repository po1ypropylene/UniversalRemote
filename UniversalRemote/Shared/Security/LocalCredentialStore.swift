import Foundation

/// Development fallback. Owner-only files are not encrypted like Keychain items.
struct LocalCredentialStore {
    let root: URL

    init(
        root: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/UniversalRemote/Credentials", isDirectory: true)
    ) {
        self.root = root
    }

    private func file(_ id: UUID) -> URL { root.appendingPathComponent(id.uuidString + ".json") }

    private func prepare() throws {
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let values = try root.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        guard values.isSymbolicLink != true, values.isDirectory == true else {
            throw CocoaError(.fileReadNoPermission)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
    }

    func load(_ id: UUID) throws -> ConnectionCredential? {
        guard FileManager.default.fileExists(atPath: file(id).path) else { return nil }
        try prepare()
        let values = try file(id).resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey])
        guard values.isSymbolicLink != true, values.isRegularFile == true else {
            throw CocoaError(.fileReadNoPermission)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file(id).path)
        return try JSONDecoder().decode(ConnectionCredential.self, from: Data(contentsOf: file(id)))
    }

    func save(_ credential: ConnectionCredential, for id: UUID) throws {
        try prepare()
        // The temporary file is owner-only before secret bytes are written.
        let temporary = root.appendingPathComponent(".\(UUID().uuidString).tmp")
        guard
            FileManager.default.createFile(
                atPath: temporary.path, contents: nil, attributes: [.posixPermissions: 0o600])
        else {
            throw CocoaError(.fileWriteNoPermission)
        }
        defer { try? FileManager.default.removeItem(at: temporary) }
        let handle = try FileHandle(forWritingTo: temporary)
        defer { try? handle.close() }
        try handle.write(contentsOf: JSONEncoder().encode(credential))
        try handle.synchronize()
        // POSIX rename atomically replaces the destination without following a symlink.
        guard rename(temporary.path, file(id).path) == 0 else { throw CocoaError(.fileWriteUnknown) }
    }

    func delete(_ id: UUID) throws {
        if FileManager.default.fileExists(atPath: file(id).path) {
            try prepare()
            try FileManager.default.removeItem(at: file(id))
        }
    }
}
