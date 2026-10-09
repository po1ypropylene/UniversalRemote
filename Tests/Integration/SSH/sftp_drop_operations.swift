import AppKit
import Foundation
import UniformTypeIdentifiers

@main struct DropOperations {
    @MainActor static func main() async {
        let root = URL(fileURLWithPath: CommandLine.arguments[2]).appendingPathComponent("drag-data")
        let files = FileManager.default
        try? files.removeItem(at: root)
        let source = root.appendingPathComponent("source")
        let destination = root.appendingPathComponent("destination")
        try! files.createDirectory(
            at: source.appendingPathComponent("drop-tree/nested"), withIntermediateDirectories: true)
        try! files.createDirectory(at: destination, withIntermediateDirectories: true)
        let data = Data([0, 128, 255, 17])
        try! data.write(to: source.appendingPathComponent("drop-tree/nested/data.bin"))
        try! data.write(to: source.appendingPathComponent("drop-file.bin"))
        let pin = try! String(contentsOfFile: CommandLine.arguments[3], encoding: .utf8)
        let controller = SFTPController(homeURL: source, requiresAccess: false)
        let client = URSSHClient()
        var connected = false
        var stopped = false
        var failures = 0
        client.onTrust = { fingerprint, _ in fingerprint == pin }
        client.onStatus = { status, _ in
            DispatchQueue.main.async {
                if status == "connected" { connected = true }
                if status == "disconnected" || status == "failed" { stopped = true }
            }
        }
        client.onFiles = { id, reply, error in
            DispatchQueue.main.async { controller.receive(id: id, result: reply, error: error) }
        }
        client.onFileProgress = { id, bytes, total in
            DispatchQueue.main.async { controller.receiveProgress(id: id, bytes: bytes, total: total) }
        }
        controller.attach(client)
        client.connectHost(
            "127.0.0.1", port: Int(CommandLine.arguments[1])!, username: "fixture", password: "fixture-password",
            privateKey: nil, authentication: "password")
        func wait(_ condition: () -> Bool) async {
            for _ in 0..<800 {
                if condition() { return }
                try? await Task.sleep(for: .milliseconds(25))
            }
        }
        func check(_ pass: Bool, _ label: String) {
            print("\(pass ? "PASS" : "FAIL") SFTP drop \(label)")
            if !pass { failures += 1 }
        }
        await wait { connected || stopped }
        controller.refreshRemote()
        await wait { !controller.busy }
        let tree = TransferFile(name: "drop-tree", directory: true, regular: false, size: 0)
        let file = TransferFile(name: "drop-file.bin", directory: false, regular: true, size: 4)
        let uploadProvider = controller.dragProvider([tree, file], local: true)
        check(controller.acceptDrop([uploadProvider], local: false), "accept-multi-upload")
        await wait {
            controller.remoteFiles.contains(where: { $0.name == "drop-file.bin" }) && !controller.busy
                || controller.error != nil
        }
        check(
            controller.error == nil && controller.remoteFiles.contains(where: { $0.name == "drop-tree" }),
            "recursive-multi-upload")
        controller.localURL = destination
        let downloadProvider = controller.dragProvider([tree, file], local: false)
        check(controller.acceptDrop([downloadProvider], local: true), "accept-multi-download")
        await wait {
            files.fileExists(atPath: destination.appendingPathComponent("drop-file.bin").path) && !controller.busy
                || controller.error != nil
        }
        check(
            controller.error == nil
                && (try? Data(contentsOf: destination.appendingPathComponent("drop-tree/nested/data.bin"))) == data
                && (try? Data(contentsOf: destination.appendingPathComponent("drop-file.bin"))) == data,
            "recursive-multi-download-bytes")
        let external = source.appendingPathComponent("finder-file.bin")
        try! data.write(to: external)
        let finderProvider = NSItemProvider(object: external as NSURL)
        check(controller.acceptDrop([finderProvider], local: false), "accept-file-url-provider")
        await wait {
            controller.remoteFiles.contains(where: { $0.name == "finder-file.bin" }) && !controller.busy
                || controller.error != nil
        }
        check(
            controller.error == nil && controller.remoteFiles.contains(where: { $0.name == "finder-file.bin" }),
            "file-url-provider-upload")
        let invalid = NSItemProvider()
        invalid.registerDataRepresentation(forTypeIdentifier: SFTPController.dragType, visibility: .all) { completion in
            completion(Data([255]), nil)
            return nil
        }
        _ = controller.acceptDrop([invalid], local: true)
        try? await Task.sleep(for: .milliseconds(100))
        check(controller.error == nil && !controller.busy, "invalid-token-does-not-reuse-old-selection")
        client.disconnect()
        await wait { stopped }
        if failures > 0 { exit(1) }
    }
}
