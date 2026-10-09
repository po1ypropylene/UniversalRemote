# Phase 1 validation

## Incremental Xcode build packaging — 9 October 2026

- Fixed the always-running native-library packaging phase so it replaces the
  generated third-party-notice directory before copying notices. This avoids a
  permission failure when a subsequent build encounters existing read-only
  license files and also prevents removed notices from remaining in the bundle.
- Repeated Xcode builds passed after the fix. No protocol tests or live-server
  connections were needed for this packaging-only correction.

## Connection editor scrollbar — 8 October 2026

- Removed the outer ScrollView around the macOS grouped Form. The Form now owns the single scrolling viewport and scrollbar while the header and action buttons stay fixed.
- Compiled an isolated preview from the actual editor source, using in-memory SwiftData and stubbed credential/trust/network actions. Inspected Display options expansion/collapse, Sharing & server identity expansion and scrolling to its last control. The accessibility hierarchy confirms one scroll area and one vertical scrollbar throughout the inspected states, instead of the previous nested scroll areas.
- Release build, final bundle platform/dependency/signature/loader verification, repository hygiene and diff whitespace checks passed. Swift formatting used the repository configuration. Initial sandbox cache/macro restrictions were resolved by building with the required access.
- This layout-only change did not repeat protocol tests or connect to servers. Visual checks inspected settled UI states; no automated frame-by-frame animation measurement was performed.

## Form, RDP clipboard and audio — 8 October 2026

- Release build passed with the rebuilt pinned Mac audio backend; final bundle platform, native-library closure, signatures and pre-UI loader checks passed.
- An isolated preview used the actual connection editor with in-memory SwiftData and stubbed credential/network actions. Clicking the blank middle of both Display options and Sharing & server identity expanded them. Separate address/port labels, RDP 3389 guidance and SSH 22 switching were inspected. No real credentials or clipboard contents were accessed.
- Twelve core tests passed, including separate address/port validation, IPv6, and saved audio preferences. A disposable database created with the previous SavedConnection schema reopened with the new schema, preserving its synthetic profile, notes and clipboard setting while applying the audio default.
- Seven synthetic SSH tests, four RDP TLS tests, five RDP NLA tests and four protected-file probe fixture checks passed. Both RDP suites now round-trip synthetic Chinese text, emoji, line breaks, subsequent updates and an empty clipboard through the protocol channel.
- The actual Mac audio backend passed registration, output-device initialization, silent PCM playback and shutdown. This is a local backend check, not proof of audible playback from a production RDP server.
- Synthetic keyboard-handler checks passed for Command+C/X/V/A, paste synchronization before key events, Command release, native Control+V, reserved app shortcuts and disconnected input. No system clipboard was read or changed.
- The production Workspace reconnect method passed an isolated in-memory check with stubbed credentials/transports: it reloads saved clipboard/audio edits, preserves ad hoc session settings, and retains a deleted profile's session snapshot. The final Release build and bundle verification passed after this correction.
- Repository hygiene and diff whitespace checks passed. Real-server clipboard integration, audible remote playback and server redirection policies remain unverified for this change. Save sharing changes and reconnect an existing session to apply them.

## Add-connection form — 8 October 2026

The Organization & notes section and its controls are removed from every connection
editor mode: New connection, Quick Connect and Edit connection. Existing folder, favorite and notes data
is preserved. The formatted Swift source passed the Release build, final bundle
and loader verification, repository hygiene and diff whitespace checks. This
form-only change did not repeat protocol tests or live-server connections; visual
UI inspection was not performed.

Checked on 7 October 2026, on the development Apple silicon Mac with Xcode 27.

## Completed

- Debug and Release Xcode builds.
- App launch and visual inspection of the workspace and connection editor.
- Live SSH UI connection, fingerprint comparison, ANSI rendering, PTY resize,
  and keyboard input round trip against a synthetic local server.
- Live RDP UI certificate verification, Metal desktop rendering, and mouse/keyboard
  input against the synthetic sample desktop.
- Core tests: profile validation/IPv6 normalization, endpoint separation,
  SwiftData disk persistence, credential serialization, remembered identity
  management, and prompt cancellation/single resolution.
- Synthetic SSH adapter integrations: password, encrypted RSA and OpenSSH
  Ed25519 keys, two-prompt authentication, wrong password, rejected server trust,
  cancellation, input bytes, and terminal resize.
- Synthetic RDP adapter integrations over TLS and NLA: accepted certificate,
  rejected certificate, desktop framebuffer, cancellation, and incorrect NLA credentials.
- Native library closure bundled and load commands relocated into the app.
- Ad-hoc signature verification of the release bundle.

These synthetic tests prove adapter integration, not complete compatibility with
all production OpenSSH, Windows, or xrdp configurations.

## Still needed before a production release

- Real Windows 10/11, Windows Server, and xrdp sessions, including server policies.
- RDP clipboard both directions, dynamic display control, cursor shapes, Retina
  scaling and pointer coordinates, Unicode/IME, and additional keyboard layouts.
- SSH full-screen programs (`vim`, `tmux`, `top`) and a broad real-server algorithm
  matrix; slow output, large pastes, long sessions, and key-format coverage.
- Concurrent mixed sessions, suspend/resume, changed networks, failed DNS, and
  repeated reconnect/disconnect under memory and thread diagnostics.
- Persistence/edit/folder/drag/drop workflows and Keychain behavior with a stable
  release signing identity; VoiceOver and complete keyboard-only navigation.
- Developer ID signing, notarization, distribution packaging,
  and a chosen license for Universal Remote's own source.

## Follow-up hardening

- App/project/native build targets changed to macOS 27 and arm64 only.
- Sources organized by feature, domain, persistence, security and protocol.
- Protected, ignored local credentials template; explicit import creates visible Test Servers profiles without automatic connections/trust.
- Additional core coverage for import filtering, normalization, invalid/redacted inputs, duplicate IDs, folder placement and idempotence.
- Local signing defaults corrected and packaging rejects ad-hoc + hardened runtime; final bundle verifier exercises the loader.
- Real-server probe reads owner-only local JSON, pins SSH/untrusted RDP identities, suppresses library diagnostics and sends no remote commands/input.

See docs/local-testing.md and docs/crash-2026-10-07.md. No real server was supplied yet; disabled entries produce SKIP, not a production-server pass. Follow-up verification completed: ten core tests, seven SSH checks, three TLS RDP checks, four NLA RDP checks, and four protected-file probe checks (28 total). Debug and Release builds plus packaging/signatures/loader checks passed; every native library reports a macOS 27 deployment minimum. The running updated app showed the Import Test Servers menu and a redacted two-entry preview with password storage off; the preview was cancelled to avoid adding synthetic profiles to the user library. Folder placement and idempotence were verified using an isolated SwiftData store. Repository hygiene and the incompatible-signing rejection guard passed.

## Universal Remote rebrand and icon

All repository-owned file names, source, comments, native adapter prefixes, project/target names, module imports, bundle/Keychain identifiers, fixture environment variables and documentation were renamed. The outer checkout remains user-managed; source paths are relative. No retired product-name references remain in owned source/text/file names, and retired generated products were removed.

The original two-layer app icon is a macOS-only Icon Composer document, compiled into the application with actool. Default, Dark and Mono exports plus 16/32/64/128 previews were visually inspected. A matching template glyph appears in the sidebar. The running Release app shows the new window, menu and sidebar name. The renamed core module's ten tests and the seven SSH, three RDP TLS, four NLA and four protected-file fixture checks passed (28 total). Debug and Release build/signatures/loader verification passed. Rebranding uses a new app container/Keychain namespace; pre-rebrand data is untouched and can be reimported. See docs/branding.md.

## Credential, RDP and UI fixes — 8 October 2026

- Rebuilt pinned dependencies after checkout relocation; stale native absolute load paths had prevented the standalone probes from launching. Final Release build, bundled dependency/signature checks and pre-UI loader check passed.
- Twelve core tests passed, including local credential reopening, replacement, private-key bytes, directory/file permissions, cleanup and symlink-directory rejection.
- A disposable synthetic credential passed save/reload/delete in the actual development environment; that command-line process used Keychain. This does not establish the original app's Keychain failure reason or attribute it to developer-program enrollment.
- An isolated UI review app used an in-memory SwiftData library and synthetic names. Visually inspected the unified form, RDP domain/default-port switch and rounded Liquid Glass tabs; exercised a synthetic UI Save without a displayed error. No real server details or remote desktop screenshots were captured.
- Seven SSH, three RDP TLS, four RDP NLA and four protected-file fixture checks passed. Protected-file probes now require nonblack pixels, not just allocated framebuffer dimensions.
- Authorized live probes selected populated disabled entries without changing the protected JSON. Server 2 (RDP) authenticated but produced no visible frame with GFX enabled; standard software bitmap negotiation produced visible desktop pixels in two subsequent probes. No keyboard, pointer, clipboard or shell commands were sent to real servers. Real Metal/UI input, clipboard, dynamic resizing and long-session behavior remain unverified.
- Server 1 (SSH) was not authenticated by the probe because its independently verified SHA256 fingerprint was absent. This is a blocked identity check, not a real SSH interoperability pass or evidence of an SSH regression.
- Repository hygiene and diff whitespace checks passed. No commit or publication was performed; the user's local test JSON was preserved.

The local credential fallback is owner-only but unencrypted, as requested for this development app. Distribution signing/notarization and broad production-server compatibility remain pending.

## Live user-flow review — 8 October 2026

The subsequent authorized UI run authenticated both supplied servers, verified saved/edit/relaunch workflows, mixed sessions, RDP Metal rendering, mouse/ASCII input, Ctrl–Alt–Delete, disconnect/reconnect and full-screen entry/exit. SSH command execution, ANSI/UTF-8 output, scrolling, font adjustment and search selection passed. The SSH host identity matched the public key independently supplied by the user.

The review found a development-build Keychain authorization stall, reconnect tab reordering and unavailable RDP dynamic resizing on the supplied server. Unicode keyboard entry and clipboard remain unverified. A private build used the production UI/actions with isolated data and in-memory credential filling; later session checks used a private local credential directory after the Keychain stall. See [the full workflow report](user-flow-testing-2026-10-08.md) for evidence, distinctions and remaining coverage. Disposable test profiles/local credential files were removed, sessions disconnected, and the protected server JSON's hash and permissions were unchanged. Keychain cleanup was attempted without interaction; absence was not independently verified.

## Official displayed name — 8 October 2026

All app-authored visible brand text now uses **Universal Remote**, including window/sidebar titles, alerts, key-import/trust text, local-network permission text and loader diagnostics. Debug/Release settings explicitly set the bundle display/name fields and build `Universal Remote.app`; the Swift module, bundle identifier and credential/storage namespaces remain stable. The Release build passed final bundle platform, native dependency, signature and pre-UI loader verification. The built plist confirms the display name, bundle name and executable spelling. Repository hygiene and diff whitespace checks passed. This text-only change did not repeat protocol tests or connect to servers.

## Shared version and DMG packaging — 8 October 2026

- Version.xcconfig supplies version 0.1.0 / build 1 to both Debug and Release; verified resolved Xcode build settings and the built Info.plist. Duplicate target version settings were removed.
- scripts/build-dmg.sh completed end to end using macOS 27 diskutil image creation/attachment and exact temporary-volume ejection. The compressed read-only image contains the app and Applications shortcut; hdiutil checksum verification and mounted app platform/dependency/signature/loader checks passed.
- Repeated cached app builds passed after build.sh was corrected to recreate only the generated app product before Xcode builds/signs it. The first incremental attempt had failed final resource-seal verification after the always-running native packaging phase.
- The output filename derives from built bundle metadata. Version 0.1.0 / build 1 produced Universal-Remote-0.1.0-build-1-arm64.dmg and its SHA256 file; the checksum was independently checked. Generated outputs are Git-ignored and temporary staging was cleaned.
- Shell syntax, project-plist validation and repository hygiene passed. No app UI/session tests or live servers were used for this packaging change. The DMG is ad-hoc signed through its app and unnotarized; Developer ID distribution and testing the installed app on another Mac remain pending. No commit, tag, upload or release was made.


## Embedded WireGuard — 9 October 2026

- Sixteen core tests passed, including bounded/redacted single-peer configuration
  import, unsafe/duplicate fields, key/metadata separation, optional credential
  decoding, persisted selection and fail-closed references after deletion.
- Race-enabled Go tests passed with generated keys and loopback UDP peers:
  encrypted TCP/half-close, bad local token rejection, AllowedIPs/DNS restriction,
  cancelled dialing, parent EOF cleanup, shared-device independent sessions and
  cancellation during an invalid-peer handshake.
- Synthetic RDP over the actual encrypted WireGuard/netstack/loopback/native path
  passed desktop frames, certificate rejection, disconnect and clipboard exchange.
- The actual Swift transport manager passed shared leases, independent cleanup,
  changed-profile refusal and cancellation. A native hook fixture verified that
  TLS/NLA settings retain the real identity, the socket uses token authentication,
  and redirects to a different host/port are refused.
- A disposable pre-feature SwiftData library migrated and reopened with its
  connection/folder/settings preserved; saving and reopening a new tunnel
  selection passed. No user database or protected test input was read/reset.
- Existing seven SSH, four TLS RDP, five NLA RDP, audio backend, keyboard and four
  protected-file synthetic fixture checks passed. No real servers were connected.
- Final Release build passed bundled helper/library signatures, arm64-only and
  macOS 27 deployment checks, relocated dependency checks and the pre-UI loader
  probe. Repository hygiene, script syntax and diff whitespace checks passed.
- An isolated in-memory UI app used synthetic profiles and an in-memory credential
  stub. Visually reviewed the profile manager and RDP selector; loading/editing/
  saving a profile and reflecting its changed name in the selector passed. This
  UI exercise does not verify production Keychain access or a real tunnel.

Real WireGuard/RDP server compatibility, internal DNS/IPv6-only peers, endpoint
roaming, network changes, long sessions and performance remain unverified.
Dependency pins/checksums and bundled notices are present; a comprehensive
vulnerability/legal review, Developer ID/notarization and clean-Mac validation
remain pending. Existing local credential fallback remains unencrypted and
explicitly disclosed. No commit or publication was performed.


## Exported split-tunnel startup fix — 9 October 2026

- Private inspection of the user-selected export confirmed valid key lengths and
  DNS servers outside AllowedIPs. The previous helper treated this as fatal
  before creating the WireGuard device. No export contents, keys, endpoint or
  address values were copied into tracked artifacts/logs.
- Race-enabled Go tests passed configured DNS outside the tunnel using an isolated
  ordinary UDP resolver, private DNS across an encrypted synthetic peer, and an
  encrypted TCP/IP-address connection with out-of-range configured DNS.
- The export's routing/DNS structure initialized with replacement synthetic keys
  and an owned loopback endpoint. The real peer was not contacted and the export
  was unchanged; this is a configuration-structure check, not a live VPN pass.
- Seventeen core tests passed, including specific startup error decoding and
  suppression of arbitrary diagnostic content. The existing encrypted RDP
  accept/reject/disconnect/clipboard and shared-session/cleanup checks passed.
- Native syntax checking passed against the pinned FreeRDP headers. The native
  identity fixture covers redacted DNS/destination status messages as well as
  original TLS/NLA identity, token authentication and redirection refusal.

- The rebuilt Release app passed final helper/library signatures, platform,
  dependency and loader checks; repository hygiene and diff whitespace passed.

Production WireGuard/RDP connectivity remains for a user retry. The app's DNS
policy now matches the explicit split routes and can send hostname queries to
configured public DNS servers; RDP remains fail-closed within AllowedIPs.


## Helper initialization under App Sandbox — 9 October 2026

- Reproduced the reported initialization error with the same synthetic settings
  that passed in an unsandboxed test, after signing the parent with the app's
  original sandbox/network-client permissions. No real settings or keys were used.
- The final app had no sandbox inheritance entitlements on its bundled helper
  and lacked the network-server entitlement needed for UDP reception/local TCP
  listening. Added only the two required child inheritance keys and parent
  incoming-network permission; sandboxing stays enabled.
- The corrected sandboxed synthetic lifecycle passed shared sessions, independent
  cleanup, changed-profile refusal and cancellation. Native identity/trust/bridge
  diagnostic checks passed.
- The rebuilt Release app passed signatures, exact helper inheritance entitlements,
  parent sandbox/network permissions, platform and dependency checks, the pre-UI
  loader, and a new helper startup/listener/cleanup probe executed from the actual
  signed app. Neither pre-UI probe reads saved profiles or credential stores.
- Project/entitlement plist checks, script syntax, repository hygiene and diff
  whitespace checks passed. The user's export and saved credentials were untouched.

This closes a gap in the earlier verification: those protocol fixtures used an
unsandboxed parent and did not establish packaged helper startup. Production
WireGuard/RDP interoperability remains for the user to retry; no real peer was
contacted in this investigation. No commit/publication was performed.
