import AppKit

// Only the selected, opted-in session calls this bridge. Tests inject a private
// named pasteboard so they never inspect or replace the user's clipboard.
@MainActor final class RDPClipboardBridge {
    private let pasteboard: NSPasteboard
    private var observedChange = -1
    private var remoteChange = -1
    private var ownedFilesChange: Int?

    init(pasteboard: NSPasteboard = .general) { self.pasteboard = pasteboard }

    func remoteChanged() {
        remoteChange = pasteboard.changeCount
        observedChange = remoteChange
    }

    func receive(text: String) {
        guard pasteboard.changeCount == remoteChange else { return }
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        observedChange = pasteboard.changeCount
        ownedFilesChange = nil
    }

    func receive(files: [URL]) {
        guard pasteboard.changeCount == remoteChange, !files.isEmpty else { return }
        pasteboard.clearContents()
        pasteboard.writeObjects(files as [NSURL])
        observedChange = pasteboard.changeCount
        ownedFilesChange = observedChange
    }

    func receive(batch: URRDPClipboardFileBatch) {
        guard pasteboard.changeCount == remoteChange else { return }
        let items = batch.files.map { url in
            let item = NSPasteboardItem()
            let provider = RDPClipboardFileProvider(batch: batch, url: url)
            item.setDataProvider(provider, forTypes: [.fileURL])
            return item
        }
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
        observedChange = pasteboard.changeCount
        // Completed files belong to the pasteboard provider, beyond disconnect.
        ownedFilesChange = nil
    }

    func synchronize(text: (String) -> Void, files: ([URL]) -> Void) {
        guard pasteboard.changeCount != observedChange else { return }
        observedChange = pasteboard.changeCount
        ownedFilesChange = nil
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
            as? [URL], !urls.isEmpty
        {
            files(urls)
        } else {
            text(pasteboard.string(forType: .string) ?? "")
        }
    }

    func reset() { observedChange = -1 }

    func invalidate() {
        // Legacy session-owned URLs expire on disconnect. Provider-owned batches
        // remain available; a subsequent local copy always belongs to the user.
        if let ownedFilesChange, pasteboard.changeCount == ownedFilesChange { pasteboard.clearContents() }
        ownedFilesChange = nil
        remoteChange = -1
        observedChange = -1
    }
}

private final class RDPClipboardFileProvider: NSObject, NSPasteboardItemDataProvider {
    private let batch: URRDPClipboardFileBatch
    private let url: URL
    init(batch: URRDPClipboardFileBatch, url: URL) {
        self.batch = batch
        self.url = url
    }
    func pasteboard(
        _ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType
    ) {
        // Materialization is already complete. AppKit fulfillment never waits for
        // network work or dispatches back to the main actor.
        item.setString(url.absoluteString, forType: type)
    }
}
