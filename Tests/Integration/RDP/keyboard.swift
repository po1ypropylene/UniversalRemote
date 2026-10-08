import AppKit
import Foundation

@main struct RDPKeyboardTests {
    @MainActor static func main() {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300), styleMask: [.titled], backing: .buffered,
            defer: false)
        let desktop = RDPDesktopView(frame: window.contentView!.bounds)
        window.contentView = desktop
        precondition(window.makeFirstResponder(desktop))
        desktop.inputEnabled = true
        var events: [String] = []
        desktop.sendKey = { code, down, extended in events.append("\(code):\(down):\(extended)") }
        desktop.preparePaste = { events.append("prepare") }
        func event(_ type: NSEvent.EventType, key: UInt16, flags: NSEvent.ModifierFlags, text: String = "") -> NSEvent {
            NSEvent.keyEvent(
                with: type, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: window.windowNumber,
                context: nil, characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: key)!
        }
        // A real Command press is first forwarded as Windows; the editing shortcut must release it.
        desktop.flagsChanged(with: event(.flagsChanged, key: 55, flags: .command))
        events.removeAll()
        precondition(desktop.performKeyEquivalent(with: event(.keyDown, key: 9, flags: .command, text: "v")))
        precondition(
            events == [
                "91:false:true", "prepare", "29:true:false", "47:true:false", "47:false:false", "29:false:false",
            ])
        events.removeAll()
        desktop.flagsChanged(with: event(.flagsChanged, key: 55, flags: []))
        precondition(events == ["91:false:true"])
        for (key, text, scan) in [(UInt16(8), "c", 46), (7, "x", 45), (0, "a", 30)] {
            events.removeAll()
            precondition(desktop.performKeyEquivalent(with: event(.keyDown, key: key, flags: .command, text: text)))
            precondition(events == ["29:true:false", "\(scan):true:false", "\(scan):false:false", "29:false:false"])
        }
        events.removeAll()
        desktop.keyDown(with: event(.keyDown, key: 9, flags: .control, text: "v"))
        desktop.keyUp(with: event(.keyUp, key: 9, flags: .control, text: "v"))
        precondition(events == ["prepare", "47:true:false", "47:false:false"])
        events.removeAll()
        precondition(!desktop.performKeyEquivalent(with: event(.keyDown, key: 12, flags: .command, text: "q")))
        precondition(events.isEmpty)
        desktop.inputEnabled = false
        precondition(!desktop.performKeyEquivalent(with: event(.keyDown, key: 9, flags: .command, text: "v")))
        precondition(events.isEmpty)
        print(
            "PASS RDP keyboard: editing shortcuts, paste ordering, modifier release, app shortcuts, disconnected input")
    }
}
