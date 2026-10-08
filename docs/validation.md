# Phase 1 validation

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
