import Darwin
import Foundation

/// Pre-UI bundle check using disposable keys and an owned loopback peer only.
/// Never opens SwiftData, Keychain, saved profiles or user-provided configuration.
enum WireGuardBundleProbe {
    static func run() -> Bool {
        let peer = socket(AF_INET, SOCK_DGRAM, 0)
        guard peer >= 0 else { return false }
        defer { close(peer) }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(peer, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }
        guard bound else { return false }
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        guard
            withUnsafeMutablePointer(
                to: &address,
                { pointer in
                    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(peer, $0, &length) == 0 }
                })
        else { return false }
        var configuration = WireGuardConfiguration()
        configuration.addresses = "10.111.0.2/32"
        configuration.publicKey = Data(repeating: 9, count: 32).base64EncodedString()
        configuration.endpoint = "127.0.0.1:\(UInt16(bigEndian: address.sin_port))"
        configuration.allowedIPs = "10.111.0.1/32"
        configuration.keepalive = 0
        let credential = ConnectionCredential(wireGuardPrivateKey: Data(repeating: 7, count: 32).base64EncodedString())
        let transport = WireGuardTransport()
        defer { transport.stop() }
        do {
            let endpoint = try transport.start(
                id: UUID(), configuration: configuration, credential: credential, host: "10.111.0.1", port: 3389,
                onExit: {})
            guard listening(endpoint.port) else { return false }
            transport.stop()
            for _ in 0..<100 {
                if !listening(endpoint.port) {
                    print("Farcast sandboxed WireGuard helper check passed")
                    return true
                }
                Thread.sleep(forTimeInterval: 0.02)
            }
        } catch {
            print("Farcast sandboxed WireGuard helper check failed")
        }
        return false
    }
    private static func listening(_ port: Int) -> Bool {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        address.sin_port = UInt16(port).bigEndian
        return withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }
    }
}
