import Foundation
import SwiftData

@Model final class SavedConnection {
    @Attribute(.unique) var id: UUID
    var name: String
    var host: String
    var port: Int
    var protocolName: String
    var username: String
    var domain: String
    var authentication: String
    var folderID: UUID?
    var favorite: Bool
    var notes: String
    var fontSize: Double
    var terminalTheme: String
    var desktopWidth: Int
    var desktopHeight: Int
    var dynamicResolution: Bool
    var clipboard: Bool
    var audioPlayback: Bool = true
    var lastConnected: Date?
    var created: Date
    init(draft: ConnectionDraft) {
        id = draft.id
        name = draft.name
        host = draft.host
        port = draft.port
        protocolName = draft.kind.rawValue
        username = draft.username
        domain = draft.domain
        authentication = draft.authentication.rawValue
        folderID = draft.folderID
        favorite = draft.favorite
        notes = draft.notes
        fontSize = draft.fontSize
        terminalTheme = draft.terminalTheme
        desktopWidth = draft.desktopWidth
        desktopHeight = draft.desktopHeight
        dynamicResolution = draft.dynamicResolution
        clipboard = draft.clipboard
        audioPlayback = draft.audioPlayback
        created = Date()
    }
    var kind: RemoteProtocol { RemoteProtocol(rawValue: protocolName) ?? .ssh }
    func update(from draft: ConnectionDraft) {
        name = draft.name
        host = draft.host
        port = draft.port
        protocolName = draft.kind.rawValue
        username = draft.username
        domain = draft.domain
        authentication = draft.authentication.rawValue
        folderID = draft.folderID
        favorite = draft.favorite
        notes = draft.notes
        fontSize = draft.fontSize
        terminalTheme = draft.terminalTheme
        desktopWidth = draft.desktopWidth
        desktopHeight = draft.desktopHeight
        dynamicResolution = draft.dynamicResolution
        clipboard = draft.clipboard
        audioPlayback = draft.audioPlayback
    }
}
