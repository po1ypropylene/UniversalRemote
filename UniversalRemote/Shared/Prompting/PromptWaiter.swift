import Foundation

// Native callbacks wait on their worker thread. The main thread only presents and resolves a prompt.
final class PromptWaiter: @unchecked Sendable {
    private let condition = NSCondition()
    private var response: String?
    private var finished = false
    func resolve(_ value: String?) {
        condition.lock()
        guard !finished else {
            condition.unlock()
            return
        }
        response = value
        finished = true
        condition.broadcast()
        condition.unlock()
    }
    func wait() -> String? {
        condition.lock()
        defer { condition.unlock() }
        let deadline = Date().addingTimeInterval(120)
        while !finished {
            if !condition.wait(until: deadline) {
                finished = true
                break
            }
        }
        let result = response
        response = nil
        return result
    }
}
