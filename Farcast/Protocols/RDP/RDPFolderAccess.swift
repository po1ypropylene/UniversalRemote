import AppKit

// Bookmarks preserve explicitly selected folder access across launches; scopes
// remain acquired by the native device until its last worker/handle is retired.
@MainActor enum RDPFolderPicker {
    static func displayPath(for folder: RDPFolderExport) -> String {
        var stale = false
        guard
            let url = try? URL(
                resolvingBookmarkData: folder.bookmark,
                options: [.withSecurityScope, .withoutUI, .withoutMounting],
                relativeTo: nil, bookmarkDataIsStale: &stale), !stale
        else {
            return "Folder unavailable — choose it again."
        }
        return url.path
    }
    static func pick() throws -> [RDPFolderExport] {
        let panel = NSOpenPanel()
        panel.title = "Redirect local folders"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return [] }
        return try panel.urls.map { url in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            return RDPFolderExport(
                name: String(url.lastPathComponent.prefix(32)),
                bookmark: try url.bookmarkData(
                    options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil))
        }
    }
}
