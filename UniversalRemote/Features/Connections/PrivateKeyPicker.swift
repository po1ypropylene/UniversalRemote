import AppKit

struct ImportedKey {
    let data: Data
    let name: String
}
struct PrivateKeyPicker {
    static func pick() throws -> ImportedKey? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose your SSH private key. Universal Remote imports it securely; your file is not modified."
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        guard data.count <= 1024 * 1024, let text = String(data: data, encoding: .utf8), text.contains("PRIVATE KEY")
        else { throw CocoaError(.fileReadCorruptFile) }
        return ImportedKey(data: data, name: url.lastPathComponent)
    }
}
