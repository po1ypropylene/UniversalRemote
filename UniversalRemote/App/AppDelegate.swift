import AppKit
import SwiftData
import SwiftUI

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var workspace: Workspace?
    private var terminationPending = false
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let workspace else { return .terminateNow }
        guard !terminationPending else { return .terminateLater }
        terminationPending = true
        workspace.shutdown { sender.reply(toApplicationShouldTerminate: true) }
        return .terminateLater
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
