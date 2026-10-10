import Foundation

struct RDPFolderExport: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var bookmark: Data
    var readOnly = true
    var validationMessage: String? {
        if name.isEmpty || name.count > 32 || name == "." || name == ".."
            || name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
            || name.rangeOfCharacter(from: CharacterSet(charactersIn: "\\/:*?\"<>|")) != nil
            || name.hasSuffix(".") || name.hasSuffix(" ")
        {
            return "Use a drive name of 1–32 characters without slashes or Windows filename symbols."
        }
        if bookmark.isEmpty { return "Choose a local folder to redirect." }
        return nil
    }
}
