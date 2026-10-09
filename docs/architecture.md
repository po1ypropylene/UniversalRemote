# Architecture and implementation decisions

## Platform and dependencies

Universal Remote targets macOS 27+ on Apple silicon only. Xcode's project deployment target is 27.0 and architecture arm64. Package.swift has the same deployment floor; native builds explicitly use arm64/macOS 27 and write a platform stamp. Build.sh rebuilds missing/outdated native dependencies. No compatibility shims, Intel binaries or universal bundle are required.

SwiftUI supplies the workspace, editor, prompts, settings and sidebar. SwiftData stores metadata/folders; Security.framework supplies Keychain storage and RDP certificate chain/hostname evaluation. libssh2 supplies the SSH protocol; SwiftTerm supplies terminal emulation. FreeRDP/WinPR supplies RDP/NLA/channels and GDI pixels. OpenSSL supplies native cryptography; Metal displays BGRA frames. Exact pinned versions/commits are in scripts/prepare-dependencies.sh and ThirdParty/README.md. There are no runtime Homebrew or external client dependencies.

## Source map

| Folder | Responsibility |
|---|---|
| UniversalRemote/App | Scene composition and application lifecycle |
| UniversalRemote/Domain | Nonsecret drafts, protocol/auth types, session state |
| UniversalRemote/Persistence | SwiftData entities and metadata import |
| UniversalRemote/Shared/Security | Credential stores and trusted identities |
| UniversalRemote/Shared/Prompting | Main-thread presentation / worker-thread responses |
| UniversalRemote/Shared/Testing | Bounded, redacted local test-document decoding |
| UniversalRemote/Features/Workspace | Sidebar, overview, tab selection, workspace coordination |
| UniversalRemote/Features/Connections | Profile editor, explicit key picker, test import preview |
| UniversalRemote/Features/Sessions | Session lifecycle, prompts, panes, tabs and diagnostics |
| UniversalRemote/Features/Settings | Appearance and tab restoration preferences |
| UniversalRemote/Protocols/SSH | Persistent terminal view and delegate |
| UniversalRemote/Protocols/RDP | Metal desktop view, input and latest-frame mailbox |
| UniversalRemote/Native/SSH | Independently written libssh2 adapter |
| UniversalRemote/Native/RDP | Independently written FreeRDP adapter |
| Tests/CoreTests | Domain, persistence, credential coding, trust, import and prompts |
| Tests/Integration | Synthetic SSH/RDP harnesses and redacted real-server probe |
| Tests/Fixtures | Blank, disabled test-server schema example |
| scripts | Reproducible builds, packaging and tests |

Xcode's synchronized source group discovers app files automatically. Package.swift compiles only Domain/Persistence/Shared to test core behavior independently of native rendering. SwiftData entity/property names are unchanged by the folder reorganization, so existing saved data stays usable.

## Ownership and threading

Workspace is main-actor observable state and owns live RemoteSession objects. Each session snapshots a ConnectionDraft, owns protocol-specific persistent surfaces and native client, and uses a generation ID to ignore callbacks from an earlier attempt. SwiftUI pane re-creation does not reconnect the transport. Closing a tab disconnects it; selection releases pressed input and restricts RDP clipboard sharing to the selected session.

Each native worker owns its handles; queued input is bounded. SSH performs socket/handshake/host-key validation before authentication, requests a PTY and shell, and delivers output with main-thread backpressure. It does not start SFTP or any local shell/agent. RDP snapshots GDI pixels into a latest-frame mailbox: rendering discards superseded frames instead of accumulating an unbounded queue. Metal draws a fitted desktop; pointer coordinates account for fitted bounds.

Native trust/interactive callbacks wait on PromptWaiter while the main actor presents a sheet. Resolution is single-use and cancellation/timeout unblocks workers. Disconnect resolves pending prompts, interrupts the transport, stops clipboard timers and invalidates callbacks. Never block the main actor waiting for a native worker or a prompt.

## Storage and trust

SavedConnection and ConnectionFolder contain only metadata. CredentialStore stores password/key bytes/passphrase by connection UUID in device-only Keychain items. If Keychain is unavailable (entitlement, authentication/interaction or service availability errors), it uses LocalCredentialStore under ~/Library/Application Support/UniversalRemote/Credentials. The UI explicitly explains that this fallback is not encrypted. Its directory is 700, files are 600, and writes use an owner-only temporary file plus atomic rename. Existing local records remain authoritative, preventing an older Keychain value from superseding an edited local credential. Quick Connect never writes credentials. This user-authorized development fallback is not a distribution security claim. Session-only Quick Connect does not create a profile or restore on launch. Restored saved-profile tabs stay disconnected. Duplicate profiles get new IDs and do not duplicate credentials.

Trust exceptions are scoped by protocol/host/port, stored separately in UserDefaults, and compared against the actual fingerprint. Changed identities require explicit approval. RDP's custom X509 callback uses macOS certificate trust and hostname checks before offering an exception. TLS and NLA are enabled; plaintext legacy RDP is disabled. No accept-all certificate switch is used.

TestServerDocument is temporary secret-bearing input. Parsing is bounded and errors never include its contents. TestServerImporter saves only new metadata in a Test Servers folder; existing IDs are untouched. The UI offers separate credential storage on this Mac, leaves default trust intact, and does not connect automatically. The ignored source file can be removed after import; deletion does not remove saved credentials or metadata.

## Packaging

The packaging phase recursively copies the native library closure into Contents/Frameworks, rewrites dependency paths, signs libraries with the same identity, and includes license notices. Local builds use ad-hoc signing and disabled hardened runtime. build.sh recreates only the generated Release app before each build: the always-running library packaging phase replaces sealed resources, so an incremental build must not reuse a bundle whose final signing can be skipped. Compiler and native dependency caches remain intact. Distribution requires a real Developer ID identity plus hardened runtime and notarization. The packaging phase refuses ad-hoc + hardened runtime; verify-bundle.py checks platform, arm64-only slices, dependency closure, signatures/teams and runs a pre-UI loader probe. See the crash incident document.

Version.xcconfig is the sole version/build source, referenced by both Xcode target configurations. DMG packaging reads the built Info.plist rather than maintaining a separate release-version value. scripts/build-dmg.sh stages only the verified app and an Applications symlink, verifies the mounted read-only image, and emits a version/build-named DMG plus SHA256 checksum under ignored .build/releases. Temporary staging/mounts are cleaned on exit; failed detach leaves the staging directory intact to avoid deleting a mounted volume. This local workflow performs no Git or publishing operation and does not claim notarization.

## Deliberately deferred

SFTP/SCP/WebDAV/file transfer; SSH config/agent/jump hosts/forwarding/certificates/hardware keys; RDP Gateway/RemoteApp/microphone capture/devices/drive redirection/multiple monitors/hardware video; nested folders/cloud sync/updater. The source license is undecided. Production interoperability and distribution are not claimed by synthetic fixture passes.

## Connection editor and desktop negotiation — 8 October 2026

The editor keeps protocol, name, host/port, username/domain, authentication and credentials in one form. Appearance and trust settings use inline disclosure groups. The macOS grouped Form owns scrolling directly within the fixed-height editor body; wrapping it in another ScrollView creates competing scroll layouts when disclosures change height. The connection editor omits organization and notes in all modes, including editing saved connections. Session tabs use SwiftUI GlassEffectContainer and interactive capsule glass, with a tinted selected tab; primary editor actions use the native glass button style. Session ownership, reordering and disconnect semantics are unchanged.

The supplied real RDP server authenticated with graphics-pipeline support enabled but delivered no paint callbacks/visible frames. Disabling SupportGraphicsPipeline delivered visible desktop pixels. Phase 1 therefore negotiates standard software bitmap rendering (RemoteFX/NSCodec remain available), retaining independent dynamic display control. This is a verified workaround for that server, not a complete diagnosis of its GFX interoperability or a claim about all servers. The Metal renderer and latest-frame buffering are unchanged.

## Form interaction, clipboard and playback — 8 October 2026

Disclosure headers use a full-width button with an expanded/collapsed accessibility value. Server address and port have separate labelled rows and protocol-specific default-port guidance. Validation rejects a host combined with a port while retaining IPv6 support.

The RDP worker retains local clipboard updates even before channel attachment and advertises them only after MonitorReady. It advertises text only once a local value exists. The selected session synchronizes pending clipboard changes before paste input as well as on its timer. Command+C/X/V/A translate to Windows Control shortcuts, releasing any previously forwarded Command modifier first. Clipboard sharing remains opt-in and text-only. Reconnecting a saved session reloads its current profile from the workspace model context so edited sharing settings take effect; ad hoc or deleted profiles retain their session snapshot. A failed metadata fetch leaves the existing session open and reports the error.

FreeRDP's pinned Mac audio backend is now built and bundled. The saved audioPlayback Boolean defaults to true, including automatic migration of older profiles; existing entity/property identities stay intact. The adapter requests remote playback and disables microphone capture. FreeRDP owns audio output and its connection lifecycle. No external player is launched. The native feature stamp now includes audio1 so existing checkouts rebuild the previously audio-disabled libraries.


## Embedded WireGuard for RDP — 9 October 2026

SavedWireGuard is a new metadata-only SwiftData entity. SavedConnection gains an
optional wireGuardID; all existing entity/property identities remain unchanged.
The existing CredentialStore gains optional WireGuard key fields, preserving old
credential decoding and its disclosed development fallback. The profile library
supports manual configuration and bounded, single-peer .conf import. Deletion
retains dangling RDP IDs deliberately so it cannot silently enable direct RDP.

Networking/WireGuard builds a bundled Go helper from checksum-pinned wireguard-go
and its compatible gVisor netstack. The app-provided reference checkouts are
read-only; the independently written glue uses upstream libraries, not copied
protocol adapters. No system TUN/VPN/routes/DNS or administrator access is used.
One device/helper per saved profile avoids competing endpoints for simultaneous
RDP tabs. Each tab leases a token-authenticated, loopback-only ephemeral TCP
listener restricted to its chosen destination and peer AllowedIPs. Requests/keys
travel over an anonymous pipe; diagnostics suppress config/keys/hostnames.

The pinned FreeRDP 3.32.1 TCPConnect hook changes socket dialing only. Settings
retain the original ServerHostname/ServerPort for TLS, Security.framework hostname
validation, NLA and existing trust scoping. Endpoint redirection fails closed;
multitransport is explicitly disabled. Rendering, audio, clipboard and main-actor
prompt handling remain intact. The profile registry performs blocking pipe work
on workers; cancellation tears down individual leases, and the final lease closes
the helper. Parent EOF/signals close all devices/listeners. Startup, remote dialing
and socket authentication have bounded waits. Active edited profiles require all
users to disconnect before new settings/keys are applied. See docs/wireguard.md.


## Split-tunnel DNS and startup diagnostics — 9 October 2026

An exported working split-tunnel configuration exposed an overly strict helper
startup check: DNS servers outside peer AllowedIPs were rejected even when RDP
used a literal IP address. That rejection occurred before device creation. DNS
is now routed per explicitly configured server: covered addresses use gVisor/
WireGuard; uncovered addresses use ordinary UDP/TCP sockets, scoped to DNS only.
Go's resolver performs A/AAAA queries with bounded per-server waits and TCP
fallback; it never changes system DNS configuration. Literal addresses need no
DNS. The final RDP addresses remain restricted to AllowedIPs and always use
WireGuard; resolving a public address cannot enable direct RDP fallback.

The helper sends allowlisted startup error codes rather than a generic Boolean.
Swift preserves stage-specific errors without exposing upstream errors/config.
The authenticated bridge reports fixed DNS/destination failure status bytes before
RDP negotiation; the native adapter converts them to actionable, redacted messages.
Unexpected shared-device failures retain cancellation/generation safeguards.


## Sandboxed helper packaging — 9 October 2026

The app uses App Sandbox. An unsandboxed test parent had hidden two missing
packaging requirements: the embedded command-line helper needs exactly
com.apple.security.app-sandbox and com.apple.security.inherit, and its parent
needs both network.client and network.server for the WireGuard UDP socket and
loopback TCP listener. Configuration/WireGuardHelper.entitlements supplies the
child's two inheritance keys during nested signing; both Xcode configurations
supply incoming/outgoing network permissions. App Sandbox remains enabled. The
helper still binds the bridge only to loopback and restricts each token to its
selected destination. No VPN/TUN/system route or filesystem permissions were added.

verify-bundle.py checks the exact child entitlements and parent network rights,
then launches --verify-wireguard-helper from the signed final app. This pre-UI
probe uses synthetic keys and an owned loopback UDP endpoint, starts the actual
WireGuardTransport, checks its listener, and verifies cleanup. It never opens
SwiftData/Keychain, saved profiles or private config files. The existing loader
check remains separate. The lifecycle test parent is now also sandboxed and its
child signed for inheritance, matching the app instead of a command-line-only
execution environment.

Apple references: [sandbox inheritance](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/EnablingAppSandbox.html)
and [UDP/network permissions](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.network.server).


## RDP display modes — 9 October 2026

SavedConnection adds optional rdpDisplayMode metadata, preserving existing entity
and property identities. Missing or unknown values use Fit to window and retain
existing dynamicResolution behavior. New and quick connections expose the same
three-mode picker. Fixed 100% and Match window at connection disable remote resize
requests; the latter waits for a laid-out desktop viewport before starting RDP,
uses that area (bounded to 200–8192), and keeps it fixed until reconnecting.
Cancellation clears pending sizing work and the connection callback checks the
session generation before dialing.

The session still owns its Metal view and latest-frame mailbox. DesktopSurface
places it in a native NSScrollView for clipping and two-axis panning. At 100%, one
remote pixel occupies one Mac point, independent of Retina backing pixels. The
render rectangle also drives input coordinate conversion, including after panning.
Scrollbars and Option-scroll pan locally; ordinary wheel input continues to Windows.
Fit remains aspect-preserving and optionally uses existing dynamic server resizing.
Sizing initially excludes scrollbars so Match window starts without scroll overflow.
If the server negotiates another resolution, its delivered frame determines the
actual desktop bounds.
