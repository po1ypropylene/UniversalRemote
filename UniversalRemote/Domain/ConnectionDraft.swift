import Foundation

struct ConnectionDraft: Identifiable {
    var id = UUID()
    var name = ""
    var host = ""
    var port = 22
    var kind = RemoteProtocol.ssh
    var username = ""
    var domain = ""
    var authentication = SSHAuthentication.password
    var folderID: UUID?
    var favorite = false
    var notes = ""
    var fontSize = 14.0
    var terminalTheme = "Midnight"
    var desktopWidth = 1440
    var desktopHeight = 900
    var dynamicResolution = true
    var clipboard = false
    init() {}
    init(_ saved: SavedConnection) {
        id = saved.id
        name = saved.name
        host = saved.host
        port = saved.port
        kind = saved.kind
        username = saved.username
        domain = saved.domain
        authentication = SSHAuthentication(rawValue: saved.authentication) ?? .password
        folderID = saved.folderID
        favorite = saved.favorite
        notes = saved.notes
        fontSize = saved.fontSize
        terminalTheme = saved.terminalTheme
        desktopWidth = saved.desktopWidth
        desktopHeight = saved.desktopHeight
        dynamicResolution = saved.dynamicResolution
        clipboard = saved.clipboard
    }
    var validationMessage: String? {
        let cleanHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHost.isEmpty { return "Enter a host name or IP address." }
        if cleanHost.contains("://") || cleanHost.contains(where: { $0.isWhitespace }) || cleanHost.contains("/") {
            return "Enter only the host name or IP address, without a URL or port."
        }
        if !(1...65535).contains(port) { return "Port must be between 1 and 65535." }
        if username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Enter a username." }
        if !(200...8192).contains(desktopWidth) || !(200...8192).contains(desktopHeight) {
            return "Desktop dimensions must be between 200 and 8192 pixels."
        }
        return nil
    }
    mutating func normalize() {
        host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.hasPrefix("[") && host.hasSuffix("]") { host = String(host.dropFirst().dropLast()) }
        username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { name = host }
    }
    var endpointKey: String { "\(kind.rawValue)|\(host.lowercased())|\(port)" }
}
