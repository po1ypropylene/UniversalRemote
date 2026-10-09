# Universal Remote agent guide

Read README.md, docs/architecture.md, docs/local-testing.md, docs/branding.md and docs/validation.md before changing the app. Read docs/crash-2026-10-07.md when touching packaging/signing.

## Product boundaries

- Native SwiftUI app, macOS 27+, **arm64 only**. No Intel/older-macOS compatibility work.
- SSH console and on-demand SFTP file transfer share one authenticated SSH session; RDP provides desktop access. No SCP/WebDAV, SSH agent requirement or external protocol executable.
- Authentication is in-app password, imported private key, or keyboard-interactive. No agent selection UI.
- Protocol adapters are independently written. Do not copy code or assets from unrelated projects.
- Do not spawn subagents unless the user explicitly asks for delegation.

## Code placement

App contains lifecycle/composition. Domain contains connection drafts, protocol/auth types and session state. Persistence contains SwiftData entities/import operations. Features contains SwiftUI workflows and session/workspace controllers. Shared contains Keychain/trust, prompt coordination, and test-document parsing. Protocols contains persistent terminal/desktop surfaces. Native/SSH and Native/RDP contain Objective-C adapters and their headers. Tests/Integration is separated by protocol; fixtures are not app seed data.

Xcode uses a synchronized source folder. A file under UniversalRemote is automatically included; avoid placing test-only tools or secrets there. The standalone Package.swift builds only Domain/Persistence/Shared for core tests. Preserve SwiftData entity names and property identities during refactoring; do not reset the user's database.

## Credentials and security

- `.local-testing/servers.json` is the user's private input; directory 700/file 600, ignored by Git. Run scripts/setup-local-testing.sh to create it without overwriting existing values.
- Never cat, echo, quote, log or reproduce that file in chat, patches, screenshots, reports, terminal output or test failures. Never pass credentials in process arguments. Read it in memory only for authorized testing.
- Do not copy real host names/passwords/keys/certificates into tracked fixtures. The tracked example has blank values and disabled entries. Do not add secrets to .gitignore itself.
- Use scripts/test-live-servers.sh for redacted real-server probes. Its stdout uses ordinal server numbers only; stderr from protocol libraries is suppressed. SSH requires an independently verified SHA256 fingerprint; untrusted RDP needs a matching pin. Never enable accept-all trust to unblock a test.
- App profiles contain metadata; credentials use Keychain when available, with the user-authorized development fallback in ~/Library/Application Support/UniversalRemote/Credentials (directory 700, files 600, atomic writes). Local files are unencrypted; disclose this in credential-saving UI. Import previews omit passwords. Import does not automatically trust fingerprints or connect. Private-key import requires user-selected file access.
- Do not read the user's clipboard, export Keychain, or alter remote files for testing. A live probe opens/authenticates a shell/desktop and disconnects, sends no shell commands or desktop input. It may create a normal server session/audit record; RDP may resume an existing user session.
- Shell/network escalation can be needed for caches, dependency builds, test listeners and launching the app. Do not misreport sandbox errors as application failures.

## Build and verification

1. scripts/prepare-dependencies.sh (pinned source; ignored .build and Vendor/Native).
2. scripts/build.sh (Release, ad-hoc signing, hardened runtime disabled for local development; bundle verifier and loader check included).
3. swift test --scratch-path .build/core-tests
4. scripts/test-ssh.sh; scripts/test-sftp.sh
5. scripts/prepare-rdp-fixture.sh; scripts/test-rdp.sh; scripts/test-rdp-nla.sh
6. scripts/test-live-fixtures.sh (protected-file probe against synthetic servers)
7. python3 scripts/check-repository-hygiene.py
8. scripts/test-live-servers.sh only when enabled entries are supplied; SKIP is not a real-server pass.

Use a real Developer ID identity and ENABLE_HARDENED_RUNTIME=YES for distribution; notarization remains pending. Never combine ad-hoc signing with hardened runtime: macOS library validation rejects the bundled ad-hoc dylibs before Swift starts. Do not add disable-library-validation as a workaround. Verify final bundles, not just loose library signatures.

Run swift-format using .swift-format for owned Swift sources. Objective-C adapters use clang-format. Do not format vendored upstream code. Keep callbacks on protocol workers, UI updates on the main actor, SSH backpressure and RDP latest-frame buffering intact. Disconnect must cancel outstanding prompts and transport work; reconnections must ignore stale callbacks.

## Documentation and delivery

Update docs/validation.md with verified checks and honest limits; synthetic tests do not prove production-server compatibility. Record material architectural decisions in docs/architecture.md. Do not include raw credentials, server identifiers, terminal contents or original crash logs. Do not modify Codex memory unless directly requested. Do not commit/publish unless requested. Universal Remote's own source license is still undecided; third-party notices must ship in the app.

## Brand assets

The source of truth is UniversalRemote/AppIcon.icon (macOS-only Icon Composer document), not a legacy appiconset. scripts/update-icon-artwork.sh regenerates its original layer PNGs and the matching sidebar template glyph; scripts/export-icon.sh renders macOS 27 previews. Keep effects and appearance variants editable in Icon Composer. Do not reintroduce superseded product names into source, comments, identifiers or file names.
