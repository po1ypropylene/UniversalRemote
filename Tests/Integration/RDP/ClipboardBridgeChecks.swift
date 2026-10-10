import AppKit

@main struct ClipboardBridgeChecks {
    @MainActor static func main() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let bridge = RDPClipboardBridge(pasteboard: pasteboard)
        let folder = URL(fileURLWithPath: CommandLine.arguments[1])
        let file = folder.appendingPathComponent("clipboard.bin")
        try! Data([0, 255, 1]).write(to: file)
        pasteboard.clearContents()
        pasteboard.writeObjects([file as NSURL])
        var text: String?
        var files: [URL]?
        bridge.synchronize(text: { text = $0 }, files: { files = $0 })
        precondition(files == [file] && text == nil)
        bridge.remoteChanged()
        bridge.receive(files: [file])
        files = nil
        bridge.synchronize(text: { text = $0 }, files: { files = $0 })
        precondition(files == nil && text == nil, "Remote files must not echo back")
        bridge.remoteChanged()
        pasteboard.clearContents()
        pasteboard.setString("new local copy", forType: .string)
        bridge.receive(files: [file])
        precondition(
            pasteboard.string(forType: .string) == "new local copy", "Late files must not overwrite a local copy")
        bridge.synchronize(text: { text = $0 }, files: { files = $0 })
        precondition(text == "new local copy")
        bridge.invalidate()
        precondition(pasteboard.string(forType: .string) == text, "User's replacement survives disconnect")
        bridge.remoteChanged()
        bridge.receive(files: [file])
        bridge.invalidate()
        precondition(pasteboard.pasteboardItems?.isEmpty != false, "Expiring staged URLs are removed")
        bridge.remoteChanged()
        bridge.receive(text: "繁體😀")
        precondition(pasteboard.string(forType: .string) == "繁體😀")
        let stage = folder.appendingPathComponent("provider")
        try! FileManager.default.createDirectory(at: stage, withIntermediateDirectories: true)
        let stagedFile = stage.appendingPathComponent("provided.bin")
        try! Data([1, 2, 3]).write(to: stagedFile)
        bridge.remoteChanged()
        let batch = URRDPClipboardFileBatch(root: stage, files: [stagedFile])!
        bridge.receive(batch: batch)
        bridge.invalidate()
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        precondition(urls == [stagedFile], "Materialized file provider survives session disconnect")
        precondition(FileManager.default.fileExists(atPath: stagedFile.path))
        print("PASS 9 RDP private pasteboard checks")
    }
}
