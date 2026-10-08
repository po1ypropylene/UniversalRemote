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

The editor keeps protocol, name, host/port, username/domain, authentication and credentials in one form. Appearance and trust settings use inline disclosure groups. The connection editor omits organization and notes in all modes, including editing saved connections. Session tabs use SwiftUI GlassEffectContainer and interactive capsule glass, with a tinted selected tab; primary editor actions use the native glass button style. Session ownership, reordering and disconnect semantics are unchanged.

The supplied real RDP server authenticated with graphics-pipeline support enabled but delivered no paint callbacks/visible frames. Disabling SupportGraphicsPipeline delivered visible desktop pixels. Phase 1 therefore negotiates standard software bitmap rendering (RemoteFX/NSCodec remain available), retaining independent dynamic display control. This is a verified workaround for that server, not a complete diagnosis of its GFX interoperability or a claim about all servers. The Metal renderer and latest-frame buffering are unchanged.

## Form interaction, clipboard and playback — 8 October 2026

Disclosure headers use a full-width button with an expanded/collapsed accessibility value. Server address and port have separate labelled rows and protocol-specific default-port guidance. Validation rejects a host combined with a port while retaining IPv6 support.

The RDP worker retains local clipboard updates even before channel attachment and advertises them only after MonitorReady. It advertises text only once a local value exists. The selected session synchronizes pending clipboard changes before paste input as well as on its timer. Command+C/X/V/A translate to Windows Control shortcuts, releasing any previously forwarded Command modifier first. Clipboard sharing remains opt-in and text-only. Reconnecting a saved session reloads its current profile from the workspace model context so edited sharing settings take effect; ad hoc or deleted profiles retain their session snapshot. A failed metadata fetch leaves the existing session open and reports the error.

FreeRDP's pinned Mac audio backend is now built and bundled. The saved audioPlayback Boolean defaults to true, including automatic migration of older profiles; existing entity/property identities stay intact. The adapter requests remote playback and disables microphone capture. FreeRDP owns audio output and its connection lifecycle. No external player is launched. The native feature stamp now includes audio1 so existing checkouts rebuild the previously audio-disabled libraries.
