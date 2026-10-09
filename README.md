# Universal Remote

A native macOS 27+ workspace for Apple silicon, with SSH terminals and RDP desktops, built with SwiftUI.
Phase 1 provides SSH console sessions and RDP remote control. SFTP, SCP, WebDAV,
other protocols, and file transfer are reserved for later releases.

## Run the built app

The local release build is at:

```text
.build/Xcode/Build/Products/Release/Universal Remote.app
```

Open it directly, or copy the app to Applications. Its protocol libraries are
bundled: users do not need Homebrew, an SSH agent, FreeRDP, or OpenSSL installed.
This local development build is ad-hoc signed with hardened runtime disabled,
not Developer ID signed or notarized. Enable hardened runtime explicitly when
using a real distribution identity.
A public release still needs signing, notarization, and validation on real servers.
The deployment target is macOS 27 and architecture is arm64. Intel and older macOS
releases are unsupported.

## Connect

1. Choose **SSH Terminal**, **Remote Desktop**, or **Quick Connect**.
2. Enter the protocol, name, server address, port, username and password in the
   connection editor. Server address is just the IP address or host name. Port is
   a separate field, initially 22 for SSH or 3389 for RDP. RDP also has an optional domain. Display and trust options
   expand below the main fields.
3. For SSH, choose password authentication or select an imported private key. Keys
   and their passphrases can be saved on this Mac. Keyboard-interactive SSH
   authentication displays the server's prompts when connecting. There is no
   SSH-agent integration or requirement.
4. Save the connection, or choose **Save & Connect**. Quick Connect uses credentials
   for the session only and does not create a saved profile.
5. Compare an unknown SSH host-key or untrusted RDP certificate fingerprint with
   your administrator's fingerprint before accepting it. Changed remembered
   identities trigger a separate warning. In Advanced, **Forget trusted identity**
   removes the remembered exception.

Double-click a saved connection to connect. Context menus provide editing,
favorites, duplication, and deletion. Create folders from Add, and drag connection
rows into folders. The first release uses one level of folders. Search matches
names, hosts, users, protocols, and notes.

Session tabs can be reordered by dragging. Switching tabs does not reconnect or
terminate their sessions. The toolbar provides reconnect, disconnect, full screen,
and connection details. Closing a session disconnects it. Restored tabs remain
disconnected until you choose Reconnect; ad hoc connections are not restored.

### WireGuard for private RDP servers

Open **File → WireGuard Connections…** to import or create named WireGuard
profiles. In an RDP connection’s Add/Edit screen, choose a profile under
**WireGuard connection** and enter the private RDP server address. The tunnel
starts automatically and closes when its last RDP session disconnects. Multiple
RDP tabs can share a profile. This embedded userspace transport needs no separate
WireGuard app or macOS VPN setup and does not change other applications’ routes.
Keys follow the app’s existing credential storage policy. See
[WireGuard setup and limits](docs/wireguard.md).

### SSH

- Password, encrypted private-key, and keyboard-interactive authentication.
- Embedded SwiftTerm terminal with Unicode, ANSI colors, resizing, terminal
  search, 10,000 scrollback lines, themes, and font zoom.
- Keepalives and explicit cancellation.
- Terminal copy/paste uses the normal macOS commands. Remote escape sequences
  cannot read or replace the local clipboard.
- No local shell process, SFTP subsystem, file browser, or SSH agent is started.
  Normal remote shell commands may of course read/write files on the server.
- `~/.ssh/config`, ProxyCommand, jump hosts, forwarding, SSH certificates, and
  hardware-backed private keys are outside this release's supported configuration.

### RDP

- Embedded FreeRDP desktop, TLS, and Network Level Authentication (NLA).
- Certificate chains and host names evaluated through macOS Security.framework.
  Untrusted certificates require explicit approval; trust exceptions are scoped
  to host, port, and protocol. No accept-all certificate setting is enabled.
- BGRA framebuffer rendered through Metal. In **Display options → Remote desktop**,
  choose **Fit to window**, **100% with scrolling**, or **Match window at connection**.
  Fit scales the entire desktop and optionally requests server resizing. 100% uses
  one remote pixel per Mac point, with your chosen desktop dimensions. Match window
  starts at the available desktop area and keeps that resolution until reconnecting;
  shrinking the window adds scrolling. Use scrollbars or Option-scroll to pan;
  ordinary scrolling goes to Windows. Display changes apply after reconnecting.
- Mouse, keyboard, scrolling, remote cursor, Unicode text input, and
  **Ctrl + Alt + Delete**.
- Optional text clipboard sharing while the session is selected. It defaults off.
  Enable **Share text clipboard** under **Sharing & server identity**, save and
  reconnect. Use Command+C / Command+V or Control+C / Control+V inside Windows.
  Command+C/X/V/A map to Windows Control shortcuts; otherwise Command maps to the Windows key;
  app shortcuts such as Command+W and Command+Q remain local.
- Remote sound plays through this Mac by default. Turn off **Play remote sound on
  this Mac** under **Sharing & server identity** to mute it after reconnecting.
  The server must allow audio playback redirection. Microphone sharing is unavailable.
- US physical scan-code layout plus Unicode text input. Additional physical
  keyboard layouts, advanced IME behavior, multi-monitor support, hardware video
  decoding, microphone capture, RD Gateway, RemoteApp, smart cards, printers, and drive/file
  redirection are not included in this release.

## Shortcuts

| Action | Shortcut |
|---|---|
| New connection | Command+N |
| Quick Connect | Command+K |
| Find in SSH terminal | Command+F |
| Reconnect | Command+Shift+R |
| Close selected session | Command+W |
| Show connection details | Command+Option+I |
| Settings | Command+, |

## Build from source

Requirements: Xcode with the macOS SDK and Metal compiler, Git, CMake, Python 3, and Go 1.27+.
The native dependency script requires internet access on its first run. Build
artifacts and downloaded source are isolated in `.build` and `Vendor/Native`.

```sh
# Install CMake if needed.
brew install cmake

# If Xcode reports that the Metal Toolchain is missing:
xcodebuild -downloadComponent MetalToolchain

# Build the pinned native libraries once.
scripts/prepare-dependencies.sh

# Build a release app, including its native libraries and license notices.
scripts/build.sh
```

Alternatively, run the preparation script, open `UniversalRemote.xcodeproj`, and select
Run. Xcode resolves SwiftTerm at the pinned version; allow its upstream build-info
plugin if Xcode requests plugin approval. The command-line build skips that plugin
validation for the pinned dependency.

Native source revisions are verified by the preparation script. The Xcode build
copies the entire native library dependency closure into Contents/Frameworks,
rewrites load paths, and signs the copied libraries with the build's signing
identity. Builds target arm64 only with a macOS 27 minimum. The platform stamp
forces native dependency rebuilding when the target changes. Native dependency updates require changing the pins, rebuilding, and
rerunning the protocol checks.

## Version and DMG for a release

Edit **[Version.xcconfig](Version.xcconfig)** at the repository root. It is the single
source for the app's version (`MARKETING_VERSION`, such as `0.1.0`) and build number
(`CURRENT_PROJECT_VERSION`, a positive integer). Both Debug and Release in Xcode
read it; do not override these values in the project settings. Increase the build
number for another build of the same version.

To build an app and a DMG for uploading later, run:

```sh
scripts/build-dmg.sh
```

The script builds and verifies the Release app, copies it into a compressed,
read-only DMG alongside an Applications shortcut, mounts the image to verify the
packaged app's signatures/libraries/loader, then ejects it. It writes:

```text
.build/releases/Universal-Remote-<version>-build-<build>-arm64.dmg
.build/releases/Universal-Remote-<version>-build-<build>-arm64.dmg.sha256
```

The filename comes from the built app's version fields. Rebuilding the same
version/build replaces those generated files after verification; earlier versions
remain. Both outputs are ignored by Git. The script does not read test credentials,
connect to servers, make commits/tags, upload files or create GitHub releases.
Upload the DMG as a GitHub release asset when ready; the SHA256 file is optional.
To check a downloaded DMG, place both files together and run
`shasum -a 256 -c <filename>.dmg.sha256` from that directory.

This workflow uses the current **ad-hoc, unnotarized development build**. It does
not provide Developer ID signing or notarization; those remain a separate
production-release task. Users drag Universal Remote into Applications after
opening the DMG. Test the installed copy on another Apple silicon Mac before a
public release. The minimum supported system is macOS 27.

## Data and architecture

- SwiftData stores folders and connection metadata in the application's local
  container. Passwords and private-key bytes are excluded from its schema.
- Keychain stores credentials by connection UUID, with device-only accessibility.
  If unavailable, credentials use owner-only, unencrypted files in
  `~/Library/Application Support/UniversalRemote/Credentials` (directory 700, files 600).
  Deleting a profile also deletes its credential item; duplicating a profile does
  not silently duplicate credentials.
- UserDefaults stores appearance, restored tab IDs, and explicitly trusted server
  fingerprints. Profiles and trust preferences are local and do not sync.
- Live session objects own their native clients and view surfaces independently
  of SwiftUI view creation. Each native client's worker owns its library handles.
- SSH output is delivered with backpressure on the main thread. RDP snapshots
  use a latest-frame mailbox, so the UI cannot accumulate an unbounded frame queue.
- Cancellation resolves outstanding authentication dialogs and interrupts the
  transport. Diagnostics include state transitions, not credentials or terminal
  contents. There is no telemetry, updater, cloud account, or background service.

See [architecture](docs/architecture.md) for the source map, ownership, threading,
storage and scope decisions, and [AGENTS.md](AGENTS.md) for future-agent instructions.

## Local test credentials and sidebar profiles

Use `.local-testing/servers.json` (already created, Git-ignored, permissions 600).
Fill the blank SSH/RDP entries and enable them locally. **File → Import Test Servers…**
adds them to a visible **Test Servers** sidebar folder, with optional credential storage on this Mac.
Earlier Quick Connect fixtures were session-only and intentionally absent from the sidebar.
See [local testing](docs/local-testing.md) for format, fingerprints and redacted probes.

Local builds disable hardened runtime because they use ad-hoc signatures. Distribution
requires a real Developer ID identity, hardened runtime and notarization. The build rejects
the incompatible signing combination and validates the packaged app's loader. See
[the launch-crash investigation](docs/crash-2026-10-07.md).

## Verification

```sh
swift test --scratch-path .build/core-tests

# Test-only Python dependency; it is not bundled in the app.
python3 -m venv .build/test-venv
.build/test-venv/bin/python -m pip install 'paramiko==4.0.0'
scripts/test-ssh.sh

# Build an isolated, loopback-only synthetic RDP server.
scripts/prepare-rdp-fixture.sh
scripts/test-rdp.sh
scripts/test-rdp-nla.sh
scripts/test-rdp-audio.sh
scripts/test-rdp-keyboard.sh
scripts/test-live-fixtures.sh
python3 scripts/check-repository-hygiene.py

# Only after filling and enabling the protected local entries:
scripts/test-live-servers.sh
```

The SSH fixture never executes received shell commands. It checks password,
encrypted RSA and OpenSSH Ed25519 keys, interactive prompts, shell input, PTY
resize, rejected trust, wrong passwords, and cancellation. The RDP fixture uses
an upstream sample desktop, not the user's screen, and checks TLS trust decisions,
framebuffer delivery, and cancellation. It can also enable NLA with a synthetic
SAM file through `UNIVERSALREMOTE_FIXTURE_NLA` and `UNIVERSALREMOTE_FIXTURE_SAM`.
The disposable RDP fixture also echoes synthetic Unicode clipboard text through
the actual clipboard channel, including updates and clearing. The audio test opens
the Mac output device and plays silence; the keyboard test uses synthetic events.
These tests never read the user's clipboard. Audible playback from a real server
still needs verification.
Fixture processes are stopped when their harness exits.

See `docs/validation.md` for completed checks and remaining release validation.
Real Windows/xrdp interoperability, clipboard round trips, all keyboard layouts,
long-running sessions, network recovery and accessibility with VoiceOver require
further validation before a production release. Older macOS and Intel are unsupported.

## App identity

The original layered icon is `UniversalRemote/AppIcon.icon`, editable in Apple Icon Composer.
See [branding](docs/branding.md) for artwork, previews, identifiers and storage implications.
Build scripts use relative paths. After renaming the outer checkout, rebuild generated
caches/native dependencies as described in the branding guide.

## Dependencies and licensing

FreeRDP/WinPR (Apache-2.0), libssh2 (BSD-3-Clause), OpenSSL (Apache-2.0), and
SwiftTerm (MIT). Exact versions, upstream links, and license texts are in
`ThirdParty`. The license for Universal Remote's own source has not been selected yet.
