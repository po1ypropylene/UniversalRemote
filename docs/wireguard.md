# RDP through embedded WireGuard

## Set up

1. Open **File → WireGuard Connections…**, or **Add → WireGuard Connections…**.
   The RDP Add/Edit screen also has **Manage WireGuard Connections…**.
2. Choose **New**. Import your WireGuard `.conf` file, or enter a name, interface
   address/prefix, private key, peer public key, endpoint, and Allowed IPs. Add a
   preshared key if your server requires one. Save.
3. Add or edit an **RDP** connection. Enter the server's private IP address or
   its internal DNS name as **Server address**, with its normal RDP port.
4. Choose the saved profile under **WireGuard connection**, then **Save & Connect**.
   The app establishes the encrypted path automatically before RDP negotiates.
   Verify any RDP certificate prompt against your administrator's fingerprint,
   as with a direct connection.

You can keep several named WireGuard profiles. **None — connect directly** is
an explicit selection; a missing/deleted profile or tunnel failure never selects
it automatically. Deleting a WireGuard profile leaves references in RDP profiles
unresolved so they refuse to connect. Edit those RDP profiles to choose a valid
profile or deliberately select None. Active sessions retain their configuration
until disconnected. Reconnect loads the current RDP and WireGuard settings.

## Configuration details

- One Interface and one Peer per WireGuard profile. Comma-separated IPv4/IPv6
  addresses and AllowedIPs use CIDR prefixes, for example `10.0.0.2/32` and
  `10.0.0.0/24`. An IPv6 peer endpoint uses `[address]:port`.
- DNS is optional and contains IP addresses, not search domains. Internal RDP
  names resolve through the explicitly configured servers. DNS servers covered
  by AllowedIPs use WireGuard; other configured DNS servers use the Mac's normal
  network, matching split routes. This can send hostname queries to a configured
  public resolver. It never changes system DNS settings. Literal RDP IP addresses
  skip DNS entirely. The RDP destination IP must be covered by AllowedIPs, with
  no direct RDP fallback. The public WireGuard peer hostname resolves using the
  Mac's normal resolver before starting the tunnel.
- MTU is 1280–1500 (default 1420). Keepalive is 0–65535 seconds (default 25);
  zero disables persistent keepalives. ListenPort in an import is accepted but
  ignored: the app chooses its own ephemeral UDP port. Scripts, extra settings,
  duplicate fields, and multiple peers are rejected with a redacted error.
- The server must allow outbound UDP to the WireGuard endpoint and route/permit
  the configured peer address to the private RDP server. The app does not change
  the server's routing/firewall. RDP UDP multitransport is disabled on this path;
  the existing desktop, input, clipboard and audio channels continue over TCP.
- Tabs using the same saved profile share one encrypted device with independent
  destination connections. Disconnecting one tab leaves the others connected.
  Disconnect all sessions using a profile before applying edited keys/settings.
  Do not create separate profiles with the same private key for simultaneous use,
  or use that same WireGuard identity concurrently in an external VPN client:
  competing endpoints can disrupt connectivity at the server.

## Privacy and lifecycle

No WireGuard installation, administrator access, NetworkExtension, system TUN,
macOS VPN profile, system routes or system DNS changes are needed. Only the app's
selected RDP sessions use the userspace stack. SSH and other applications retain
their existing networking.

SwiftData stores configuration metadata and profile IDs. Private/preshared keys
use the app's existing Keychain credential store and its disclosed development
fallback (owner-only, unencrypted local files). Imported configuration files
remain untouched and can contain plaintext keys; protect or remove the original
file yourself after saving. Import never executes scripts or connects.

The bundled helper receives keys/configuration through an anonymous input pipe,
never command arguments or temporary configuration files. A separate random
256-bit token protects each loopback-only ephemeral listener. Each token forwards
only its selected host/port; it is not a SOCKS or general proxy. Closing a session
cancels its listener, handshake and sockets. The last session closes the helper;
parent exit/EOF and termination signals also close its device/listeners. Failures
are redacted, with no direct fallback. RDP TLS/NLA use the **original** host/port;
server redirection to a different endpoint is refused on the tunneled path.

## Build and verification

Go 1.27+ is a developer build requirement; the shipped app requires no Go runtime
installation. Normal dependency preparation/build scripts include the helper.
For an Xcode build after source changes, first run scripts/prepare-wireguard.sh.
The helper is nested-signed to inherit the app's sandbox. The app grants incoming
and outgoing socket permissions for WireGuard UDP and the loopback bridge; no
system VPN permission is involved. Final bundle verification checks those rights
and runs a synthetic helper startup/cleanup probe from the signed app, alongside
the arm64/macOS 27 signature/dependency/loader checks.
Licenses and the module inventory ship under Resources/ThirdParty.

```sh
scripts/test-wireguard.sh
scripts/test-wireguard-rdp.sh
scripts/test-wireguard-lifecycle.sh
scripts/test-wireguard-migration.sh
```

Tests use generated disposable keys, loopback UDP peers, userspace IP addresses,
a sample RDP server and isolated storage. They do not use the protected real-server
file, system VPN settings, the user's clipboard or persistent profiles.

Synthetic passes do not prove your production VPN/firewall configuration.
Synthetic private/encrypted and external/split DNS tests pass. Real-server
WireGuard/RDP interoperability, long-session behavior, IPv6-only peers,
production DNS, endpoint roaming/network changes and performance still need live
verification. Endpoint DNS is refreshed on reconnect, not periodically while
connected. Reconnect is manual; no new automatic reconnect policy is introduced.
Developer ID signing, notarization and a clean-Mac distribution test remain pending.


Startup failures now distinguish invalid configuration, unresolved peer endpoint,
missing/unlaunchable helper, initialization failure, listener failure and timeout.
During RDP connection, errors distinguish missing DNS, failed DNS, a destination
outside AllowedIPs and an unreachable private server. These messages contain no
configuration values, keys or server identifiers.
