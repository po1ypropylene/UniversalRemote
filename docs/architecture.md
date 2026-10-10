# Architecture

## Platform and dependencies

Universal Remote is a native SwiftUI app for macOS 27+ and arm64 only. Xcode,
Package.swift and native builds share that minimum. SwiftData stores metadata;
Security.framework provides Keychain and certificate trust. SwiftTerm handles
terminal emulation, libssh2 SSH/SFTP, FreeRDP/WinPR RDP/NLA/channels, OpenSSL native
cryptography, Metal desktop frames, and wireguard-go/gVisor private RDP transport.
Pins, checksums and licenses live in the build scripts, Go manifests and ThirdParty.
No runtime Homebrew, external protocol client or SSH agent is required.

## Source map

| Folder | Responsibility |
| --- | --- |
| App | Scene composition and lifecycle |
| Domain | Drafts, protocols, authentication, display choices, session state |
| Persistence | SwiftData models and metadata import |
| Shared/Security | Credential stores and endpoint trust |
| Shared/Prompting | UI presentation and worker responses |
| Shared/Testing | Bounded, redacted test-document decoding |
| Features/Workspace | Sidebar, overview, tabs, coordination and shared controls |
| Features/Connections | Profile editor, explicit key picker, import preview |
| Features/Sessions | Lifecycle, prompts, panes, diagnostics and SFTP controller |
| Features/Settings | Appearance and tab restoration |
| Features/WireGuard | Profile library, transport leases and packaged helper probe |
| Protocols/SSH | Persistent terminal view/delegate |
| Protocols/RDP | Metal view, scrolling, input and latest-frame mailbox |
| Native/SSH, Native/RDP | Independently written Objective-C protocol adapters |
| Networking/WireGuard | Independently written Go helper using pinned upstream modules |
| Tests/CoreTests, Integration, Maintenance | Core, protocol/UI coordination and disposable script checks |
| Tests/Fixtures | Blank disabled server-document example required by setup/import |

App source folders are under UniversalRemote. Xcode's synchronized group includes
files there automatically; keep test-only tools/secrets outside it. Package.swift
builds only Domain/Persistence/Shared. Preserve existing SwiftData entity/property
identities and module/storage names; never reset the user's database during refactoring.

## Session ownership and cancellation

Workspace is main-actor observable state and owns RemoteSession objects. A session
snapshots its ConnectionDraft and owns persistent native clients/surfaces. SwiftUI
pane recreation never reconnects. Generation IDs reject callbacks from earlier attempts.
Closing disconnects; selection releases pressed desktop input and limits clipboard
sharing to the selected RDP session. Reconnect reloads saved metadata, resolves
credential/validation failures before replacing the old session, and replaces the tab
at its existing index. Background reconnect retains the selected tab. Ad hoc/deleted
profiles retain their snapshot. Only persistent tabs enter restoration preferences;
restored tabs remain disconnected. Dragging inserts a tab before its destination.

Each native worker owns its handles and bounded input/work queues. SSH sends output
with main-thread backpressure. RDP uses a latest-frame mailbox, dropping superseded
frames instead of building an unbounded UI queue. Trust/interactive callbacks wait on
single-use PromptWaiter responses while the main actor presents sheets. Cancellation
resolves pending prompts, interrupts transport work, invalidates callbacks and stops
clipboard timers. Never wait for workers/prompts on the main actor.

CredentialStore currently exposes synchronous Keychain operations used by UI callers.
Development signing changes can trigger authorization stalls; worker-based credential
I/O with explicit prompt/cancellation policy remains an open improvement. Injected
credential lookup and preferences let workspace tests avoid real Keychain/user defaults.

## Storage and trust

SavedConnection/ConnectionFolder/SavedWireGuard contain metadata, not secrets. Optional
wireGuardID and rdpDisplayMode preserve existing schema identities; absent/unknown
modes use Fit. audioPlayback defaults true for older profiles. Credential coding retains
compatibility when adding optional tunnel fields. Device-only Keychain stores secrets by
UUID. When unavailable, owner-only unencrypted files under Library/Application Support/
UniversalRemote/Credentials provide the disclosed development fallback (directory 700,
files 600, atomic writes). Existing local records remain authoritative. Quick Connect
never saves secrets/profiles; duplication does not copy credentials; profile deletion
removes its credential item. No automatic Keychain export is used.

Trust preferences are separate and scoped to protocol/host/port. SSH verifies a host
key before authentication; RDP evaluates certificate chain and original hostname with
Security.framework. Unknown/changed identities require explicit approval. TLS/NLA stay
on, plaintext legacy RDP and accept-all trust stay off.

Test documents are bounded temporary secret-bearing input with redacted errors.
Import creates new metadata in Test Servers, skips existing UUIDs, offers separate
credential saving, and never connects or trusts imported fingerprints automatically.
See [local testing](local-testing.md) for protected-input rules.

## UI and desktop presentation

The grouped connection Form is the editor's only scrolling owner, with fixed header
and actions. It omits organization/notes controls in all modes while preserving existing
data. Full-width disclosure rows announce their state. Server address and port are
separate; validation rejects combined host:port while preserving IPv6. Tabs use capsule
Liquid Glass, with a 44-point capsule and full-height close target; the strip adds
only four points above/below. Shared secondary actions use 34-point visible
backgrounds and icon actions use 36-point backgrounds with 20-point symbols;
transparent margins retain 44-point hit regions. Primary actions retain native
glass styling with compact semantic labels instead of a 44-point label plus
native padding. Sidebar RDP hosts append the selected
WireGuard profile name from the live metadata query; missing references explicitly
show an unavailable tunnel. Long destination labels expose the full text in a tooltip. See [UI guidelines](ui-guidelines.md).

RDP negotiates software bitmap rendering: enabling the graphics pipeline authenticated
but delivered no visible paint callbacks on a supplied server. This is a bounded
interoperability workaround, not a diagnosis for every server. Metal/BGRA/latest-frame
ownership stays intact. Fit scales the desktop and optionally requests server resize;
100% maps one remote pixel to one Mac point; Match window waits for a laid-out viewport
and fixes that initial size (200–8192) until reconnect. Delivered server dimensions
remain authoritative. Fixed modes disable resize requests. Native NSScrollView clips
and pans, with pointer coordinates derived from the same render rectangle. Scrollbars
and Option-scroll pan locally; ordinary scrolling reaches Windows.

The worker retains clipboard updates before channel attachment and advertises after
MonitorReady. The selected session synchronizes before paste and on its timer.
Command+C/X/V/A map to Windows Control shortcuts after releasing forwarded Command;
app shortcuts remain local. Text sharing is opt-in. FreeRDP's Mac audio backend is
bundled, playback defaults on, and microphone capture stays off. Changes apply after
reconnect; real-server clipboard/audio policies still need broader verification.

## Shared SSH and SFTP

After host-key verification, the SSH worker queries the server's allowed sign-in
methods with bounded nonblocking retries. Password prefers SSH password and can
fall back once to advertised keyboard-interactive. It supplies the selected password
once to a recognized masked password prompt; codes, visible/unrecognized prompts
and all explicit Interactive prompts use the existing cancellable UI coordinator.
Cancelling a challenge disconnects; the temporary password reference clears after
sign-in and on every cleanup path. Private-key selection never falls back to another
credential type. A NULL method list is accepted only when libssh2 confirms successful
none authentication. See [libssh2 authentication](https://libssh2.org/libssh2_userauth_list.html).

Credential rejection has a worker callback guarded by the session generation.
Reconnect then replaces the tab in place and requests fresh credentials, bypassing
the saved lookup for that retry. Explicit Interactive retries ask the server again
without a separate password dialog. Stored credentials are changed only through the
existing user-controlled saving flow; transport/identity failures retain normal
reconnect behavior. No persistent model identity changes are involved.

A session owns one SSH login and an SFTPController. Terminal/Files/Split only changes
presentation; SFTP opens lazily on the existing libssh2 session. Terminal channel,
PTY or shell refusal closes only that channel, then verifies SFTP on the same
authenticated transport before reporting a file-only connection. Shell EOF also
checks SFTP rather than ending usable file access. Transport errors, authentication
and trust failures still fail the connection; neither service available is an error.
Worker capability callbacks use the session's generation guard, select Files and
disable Terminal/Split and terminal tools. Reconnect checks capabilities anew.
Subsystem refusal with a usable shell leaves the terminal available. The worker
services terminal I/O/resize between file
chunks and socket waits. Callbacks check generation and operation IDs. Listings are
bounded to 20,000 UTF-8 entries; trees to 20,000 items/64 levels. Symlinks/special files
are displayed but refused by recursive preflight. Directory/list/handle/no-progress
waits are bounded. Genuine transport/cleanup failure can disconnect shared SSH.
Without a shell, file waits skip terminal pumping; idle extended-stream reads on
the SFTP channel drain SSH control/keepalive packets and detect transport closure.
Standard-stream bytes remain exclusively owned by SFTP. See
[libssh2 channel streams](https://libssh2.org/libssh2_channel_read_ex.html).
The session accepts an injected file controller for isolated UI/transport checks.

Home comes from getpwuid, since NSHomeDirectory names the sandbox container. Explicit
NSOpenPanel read/write permission gates access; a Home security-scoped bookmark is
remembered/refreshed, while other folder scopes stay session-owned. The plain Local
Mac heading opens the same folder picker with a 44-point hit region; both file-pane
headings and navigation rows use matching minimum heights. Local operations run on
workers with O_NOFOLLOW, cancellation and retained scopes. No broad filesystem
entitlement is used. Multi-selection jobs run sequentially and stop on the first error.
File buffers capture session-local paths/scopes; Paste never reads system clipboard.
Copy Path alone writes requested paths. Disconnect clears buffers and late drop callbacks.

Regular-file transfer conflicts ask Stop/Overwrite/Overwrite All; the last is scoped to
one batch. Real folders merge; links/type mismatches fail. Downloads fsync sibling
staging then atomically publish; exclusive new files use hard links. Overwrite uploads
stage exclusively then use posix-rename@openssh.com; unsupported servers preserve the
original and fail, with no truncate/delete fallback. Same-side local copy/move and
rename retain no-overwrite behavior. Cancellation attempts staging cleanup; interruption
can leave uploaded partial files, completed tree leaves or remote staging.

Uploads use a refilled bounded 4 MiB window (refill after at least 256 KiB acknowledged);
downloads use 256 KiB. EAGAIN retries preserve unacknowledged bytes/buffer lengths under
[libssh2's write-ahead contract](https://libssh2.org/libssh2_sftp_write.html). TCP_NODELAY
and captured SFTP readiness directions avoid terminal pumping changing pending wait
requirements. Cancel stops refilling, drains submitted work and closes its handle,
retaining the authenticated terminal and idle SFTP channel. It can finish the current
4 MiB window. Terminal pumping/backpressure and throttled progress stay intact.

Moves copy then recheck metadata before deleting sources; same-side moves prefer
exclusive rename. Metadata checks require quiescent sources and cannot guarantee a
transactional snapshot or detect every concurrent same-size change. Server-to-server
copies stream through temporary local trees. Completed work remains after later failure.
Remote Delete is confirmed/permanent; local deletion uses Trash. Remote Open downloads
a temporary snapshot for a local application with no automatic upload; the OS owns its
later cleanup. Local publication needs filesystem hard-link support.

List itemProvider/onInsert plus folder/background drop handlers support internal
session tokens and Finder file URLs with retained scopes/provider lifetime. Text is
never treated as paths. Drops copy and reuse recursive/conflict rules. Finder download
promises and actual production drag/sandbox interoperability remain deferred/unverified.

## Embedded WireGuard

Saved profiles hold bounded single-peer metadata; keys use existing credential storage.
Dangling RDP profile references fail closed instead of silently connecting directly.
One userspace helper/device per profile serves token-authenticated loopback TCP leases,
each restricted to its destination/AllowedIPs. Requests/keys use anonymous pipes;
diagnostics use allowlisted codes, never upstream config/keys/hosts. Blocking pipe work
runs off the main actor. Leases stop independently; the last closes the helper. Parent
EOF/signals close devices/listeners. Startup/dial/auth waits are bounded; edited profiles
require all leases to disconnect before new settings apply.

FreeRDP TCPConnect changes dialing only. Original host/port remain in TLS/NLA/trust;
endpoint redirects fail closed and multitransport is disabled. RDP destination IPs must
be within AllowedIPs. Configured DNS covered by those routes uses gVisor/WireGuard;
uncovered DNS uses ordinary UDP/TCP scoped to DNS only, with bounded A/AAAA queries
and TCP fallback. Literal destinations need no DNS. Resolving public addresses never
permits direct RDP fallback. No system VPN/TUN/routes/DNS/admin changes occur.
See [WireGuard](wireguard.md) and [packaging](packaging.md) for lifecycle/sandbox rules.

## Build and maintenance

`.dependencies` retains native source/build trees, Go caches, Xcode package downloads,
test Python and the reproducible RDP sample server. `Vendor/Native` holds installed
headers/libraries/helper. `.build` is entirely disposable. Test runs under `.build/tests`
are unique, owner-only and removed on exit with their processes/logs/data. Keep source
fixtures that exercise distinct regressions; discard one-off generated review artifacts.

The updater compares numeric stable bare/v/V tags, refuses downgrades, pins exact
native/Swift/Go revisions, rolls back manifests on resolution failure and invalidates
outdated native/sample-server products. Successfully resolved pins remain after a build
failure; upstream notice changes still need review. Project cleanup preserves dependencies
and protected input, rejects tracked/redirected generated targets and never follows
external links. User-data reset is a separate explicit destructive action scoped to
current-bundle Library/preferences/credential service, using SecItemDelete without
reading secrets; it refuses a running app/helper, sudo and redirected paths.

Packaging relocates the native closure and ships notices. Local ad-hoc builds disable
hardened runtime and recreate the generated app before final signing. Distribution
requires Developer ID/hardened runtime/notarization. Version.xcconfig is the single
version source; DMGs use built metadata. Final bundle/loader/sandboxed-helper checks
are required. See [development](development.md), [packaging](packaging.md) and
[testing](testing.md) for procedures.

Deferred: SCP/WebDAV, SFTP resume/Finder download promises, SSH
config/agent/jump hosts/forwarding/certificates/hardware keys, RDP Gateway/RemoteApp/
microphone/devices/drives/multiple monitors/hardware video, nested folders/cloud sync/
updater. The source license is undecided; synthetic passes do not establish production
interoperability or distribution readiness.
