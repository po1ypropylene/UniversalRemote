# Validation and known limits

Validation is evidence for the stated environment and scope, not a production
compatibility guarantee. Repeatable commands and fixture ownership are in
[testing](testing.md); signing requirements are in [packaging](packaging.md).

## Current cleanup, UI and workspace review — 10 October 2026

- README reduced to an introduction, app icon/screenshots, getting started,
  build commands and links. Detailed workflows/maintenance/testing were retained in
  focused docs. Dated crash/user-flow files were removed; reusable signing rules and
  unresolved findings remain in packaging, architecture and this document.
- README image references now use the five supplied screenshots in `docs/images`.
  Icon Composer exported the current Default macOS icon as a 512×512 PNG there,
  displayed at 128×128 in README. The export was visually inspected; image paths,
  PNG dimensions and the export script's syntax passed checks. Regeneration uses
  `scripts/export-icon.sh --readme`. This documentation-only update did not change
  the app icon source or runtime code; app/protocol suites were not repeated.
- Reusable native source/build, Go, Swift package, Python and RDP sample-server caches
  moved to `.dependencies`; installed native products remain in `Vendor/Native`.
  Actual project cleanup removed the old `.build` with accumulated fixture trees,
  private review apps and logs, preserving dependencies, tracked tests and local input.
- Pinned native dependencies and the sample RDP server rebuilt at their new paths.
  Release build passed macOS 27/arm64, six-library closure, signatures, pre-UI loader
  and the sandboxed embedded-helper startup/listener/cleanup probe. Xcode command-line
  package resolution uses `.dependencies/swift-packages`.
- Seventeen core tests passed. Six isolated workspace checks passed bidirectional/
  adjacent drag ordering, reconnect in-place, background selection, saved edit reload,
  credential/validation failure preservation, ad hoc restoration exclusion and stale
  action safety. Credential lookup/preferences were injected; no real credentials,
  networks or user library were used by these checks.
- Thirteen maintenance checks passed, including full `.build` deletion with dependency
  preservation, tracked/redirected target refusal, read-only/link safety, pin rollback,
  and harness cleanup after success/failure with child-process teardown and no children.
- Seven SSH and 67 SFTP checks passed: authentication/trust, byte equality, atomic
  conflicts, recursion/move safety, continued shell operation, cancellation and drop
  providers. The corrected controlled throughput fixture compares actual 32 KiB and
  4 MiB upload windows; both variants' bytes matched. At a simulated 20 ms RTT it
  measured 1.26/37.85 MiB/s (30.1×). This is synthetic, not production throughput.
- Four TLS RDP, five NLA RDP and four protected-file synthetic checks passed, including
  trust rejection, frames, cancellation, bad credentials and Unicode clipboard updates/
  clearing. Mac audio backend and synthetic keyboard/display checks passed.
- Race-enabled WireGuard Go tests, encrypted RDP accept/reject/clipboard checks,
  native identity hook, sandboxed shared-lease lifecycle and disposable SwiftData
  migration/reopening passed. These used generated keys and owned loopback peers.

- Visually reviewed actual tabs, sidebar, file panes and editor in an isolated native
  preview with in-memory SwiftData, stubbed credentials/transports and owned local
  files. A near-edge close click removed only its tab; a near-edge primary action
  saved a synthetic profile. Inspected primary glass buttons, SSH/RDP switching,
  disclosure activation in the blank middle of the row and scrolling to the final
  trust control. The editor retained one scroll area/scrollbar. No physical touchscreen
  or complete VoiceOver workflow was tested; the preview's session pane was stubbed.
- Final Release rebuild/bundle checks, configured Swift formatting, shell syntax,
  repository hygiene, local documentation links and whitespace checks passed.
  All integration run directories were removed on exit; the preview and temporary
  test logs/tooling were discarded after review.
No real-server run was performed for this review. The protected local input, user
clipboard, real remote files, saved profiles/credentials and user database were not
read or changed. No commit or publication was performed.

## Tab, destination and text refinement — 10 October 2026

- Reduced tab capsules from 52 to 44 points and tab-strip vertical padding from 10
  to four points; protocol glyphs are 12 points. Close targets remain full-height
  44×44. Shared button labels use semantic title3 text; current compact background
  and symbol proportions are described below.
- Sidebar and overview destinations append `via` plus the selected WireGuard name.
  Direct connections retain the host alone; missing tunnel references show an
  unavailable WireGuard connection. Tooltip/accessibility text retains full labels.
- Removed the descriptive rows below Server address and Port in the shared editor,
  applying to New, Quick Connect and Edit. Labels/placeholders, protocol defaults,
  validation and the single scrolling Form remain.
- Release build and final bundle/platform/signature/loader/sandboxed-helper checks
  passed. An isolated synthetic preview showed direct, via-profile and missing-profile
  sidebar labels, compact tabs, larger button text and the simplified SSH/RDP new
  forms. A near-lower-edge close click removed only its tab. Saved Edit uses the same
  source form; its menu action could not be completed by UI automation in this pass.
- Configured Swift formatting, repository hygiene and whitespace checks passed.
  No protocol behavior, persistence schema or credential handling changed; protocol
  suites were not repeated. No real servers/private input/user database were accessed.
  Disposable preview artifacts/logs were removed; no commit or publishing occurred.

## File-only SSH and file-pane headers — 10 October 2026

- SSH terminal-channel, PTY and shell refusal now verifies SFTP on the authenticated
  transport and selects Files. Shell EOF also retains SFTP when available. Terminal,
  Split, terminal zoom/search and the observed Find menu action disable when there
  is no shell. A native segmented control supplies per-segment disabled states;
  the SwiftUI macOS picker ignored disabled state on individual items.
- Removed the separate Choose folder action. The plain Local Mac heading opens
  the existing macOS folder picker with a 44-point target; matching header heights
  align local/server navigation dividers.
- Seven SSH and 74 SFTP checks passed, including all four fallback cases,
  rejection of both services, byte equality, asynchronous overwrite prompts and
  upload/download cancellation that keeps file-only access. Normal shell exit
  now checks the terminal-capability callback before the synthetic client disconnects.
- An isolated native preview used the actual RemoteSession, SSH adapter and file
  panes with a loopback server, injected owned local files and disposable trust
  preferences. Starting in Split switched to Files after shell refusal and loaded
  the listing. Accessibility reported Terminal/Split and terminal tools disabled;
  a Terminal click retained Files. Local Mac opened the standard folder picker,
  which was cancelled; visual inspection confirmed plain styling/aligned dividers.
- Release and final bundle/platform/signature/loader/sandboxed-helper checks,
  17 core, six workspace and 13 maintenance checks, configured formatting and
  repository hygiene passed. RDP protocol suites were not repeated for this SSH/UI
  change. No real servers, private input, Keychain, user clipboard or database were
  accessed. Physical touch/complete VoiceOver were not tested. Disposable preview
  processes/files/preferences and test logs were removed; no commit/publication occurred.

## Current button proportions

- Shared secondary actions use 34-point visible backgrounds; icon actions use
  36-point backgrounds with symbols increased from 16 to 20 points. Transparent
  margins retain nonoverlapping 44×44-point minimum targets. Semantic title3 labels
  are laid out directly, removing hidden measuring labels and forced text shrinking.
- Primary actions retain native prominent glass, semantic semibold text and a
  32-point label minimum plus native padding. This removes the oversized combination
  of a 44-point label plus native padding while retaining the primary click target.
- Reviewed actual shared controls, SFTP panes and Quick Connect in a disposable
  native preview with in-memory metadata, synthetic callbacks and owned local files.
  Lower-edge text-button and side-edge icon-button clicks outside the visible
  backgrounds activated exactly one action. Disabling the actions exposed disabled
  accessibility states and blocked activation. The editor kept one scroll area/bar;
  its primary action completed a synthetic connection callback.
- Release and final bundle/platform/signature/loader/sandboxed-helper checks,
  configured Swift formatting, repository hygiene, local documentation links and
  whitespace checks passed. Protocol suites were not repeated for this shared style
  change. No real connections, private input, Keychain, user clipboard or database
  were used. Physical touch/complete VoiceOver remain untested. Disposable preview
  artifacts/preferences/logs were removed; no commit or publication occurred.

## SSH sign-in retry and authorized SFTP probe — 10 October 2026

- Reproduced the original Password implementation's authentication rejection on a
  synthetic keyboard-interactive-only password server. The worker now negotiates
  advertised methods after trusted identity verification, supplies a recognized
  masked password challenge once, and keeps additional/visible prompts interactive.
  Cancellation, unsupported methods and successful none authentication are explicit.
- SSH credential rejection now marks the session for **Retry sign-in**. Reconnect
  requests fresh credentials rather than reloading the rejected saved value. Explicit
  Interactive retries retain server prompts. Stored credentials are not deleted by
  retry; replacement saving remains user-controlled.
- Eighteen SSH, 75 SFTP and nine workspace checks passed. The latter includes the
  production Workspace/RemoteSession/native adapter: wrong saved password → fresh
  credential prompt → keyboard-interactive sign-in → file-only SFTP listing. It used
  synthetic credentials and disposable preferences, without the user's database,
  Keychain or credential files. Earlier UI checks cover the shared button styling;
  this pass did not visually automate the new retry label or a real credential dialog.
- Ten protected-probe synthetic checks passed: SSH/RDP success, selected SFTP access,
  supplied-pin match/mismatch, invalid IDs, missing/non-SSH selections and file-only
  capability after shell refusal/EOF. Empty optional arguments work with macOS's
  bundled Bash. Probe output is restricted to ordinal/protocol and fixed descriptions.
- The explicitly authorized supplied SFTP account authenticated and returned a
  directory listing under Password both before and after this change, with the
  independently supplied public host key. This did not reproduce the reported -18
  rejection; a differing saved username/password remains unconfirmed because user
  profiles/credential stores were not inspected. The real probe sent no shell commands,
  read no file contents, transferred no files and changed no remote data. File-only
  capability was established on synthetic servers; the real probe did not observe
  shell refusal/EOF during its short no-input window.
- Protected JSON bytes and 700/600 directory/file permissions remained unchanged.
  Release/final bundle/platform/signature/loader/sandboxed-helper checks, 17 core,
  13 maintenance checks, formatting and repository hygiene passed. RDP/NLA suites
  were not repeated beyond the protected-probe RDP check. Test processes/directories,
  logs and temporary probe records were removed; no commit or publication occurred.

## Retained evidence

Earlier isolated UI runs exercised the native workspace/editor, private-key/trust
prompts, single-scroller disclosure layout, file browser/actions and overwrite dialogs.
Synthetic sources cover core persistence, credential encoding/local permissions, endpoint
trust, import filtering/idempotence, prompt single-resolution/cancellation, saved display/
audio choices, and pre-feature SwiftData migration. The layered Icon Composer icon and
sidebar glyph were inspected at multiple sizes/appearances. Prior local DMG creation
passed checksum and mounted final-bundle verification; DMG generation was not repeated
for this review. See [branding](branding.md) and [development](development.md).

An explicitly authorized earlier UI run authenticated the two supplied SSH/RDP servers
and exercised saved/edit/relaunch flows, mixed sessions, SSH ANSI/UTF-8 output/search,
RDP Metal frames/mouse/ASCII input/Ctrl–Alt–Delete, reconnect and full screen. It used
isolated data; later session checks used the production local credential implementation
after a development Keychain stall. The protected JSON retained its hash/permissions;
disposable profiles/local credentials were removed, while Keychain absence was not
independently established. This proves those bounded flows on those servers only.
Unicode/IME keyboard and real clipboard/audio were not established by that run.

## Open findings and production checks

- **Keychain UI stalls:** synchronous credential operations can block UI callers when
  a rebuilt ad-hoc app requires macOS authorization. The fallback cannot help while a
  Keychain call is still waiting. Worker-based I/O, prompt/cancellation behavior and a
  stable distribution identity need separate implementation/testing. Workspace lookup
  failure now preserves the old session, but this does not resolve a blocking call.
- **RDP resizing:** the supplied server had no display-control channel, so dynamic
  resizing could not apply. Software bitmap negotiation delivered visible frames;
  verify capability reporting, resolution negotiation, Retina coordinates/cursor shapes
  and behavior on Windows/xrdp/server policies. Match-window mode fixes its initial size.
- **Input/sharing:** real clipboard both directions, audible remote sound, additional
  keyboard layouts and Unicode/IME need verification. Synthetic clipboard exchange,
  keyboard events and silent local audio initialization are narrower evidence.
- **SSH/SFTP:** broad real-server algorithms/key formats, full-screen terminal programs,
  long/high-latency transfers, subsystem policies, large trees, concurrent writers,
  unusual filesystems and interruption during deletion need testing. Atomic upload
  overwrite requires OpenSSH POSIX rename; sources must remain quiescent for moves.
  Partial/completed destinations can remain after cancellation/failure.
- **Drag/file access:** provider/controller tests do not establish actual mouse/Finder
  dragging, sandbox-extension delivery, remote file promises, external-editor access,
  Trash or cross-volume behavior. Home needs explicit permission; server Open is a
  temporary local snapshot without automatic upload.
- **WireGuard:** production peers, internal/IPv6 DNS, endpoint roaming, network changes,
  long sessions and performance remain unverified. The signed-parent helper probe
  closes the sandbox-startup gap, not real peer interoperability.
- **UI/accessibility:** complete VoiceOver/keyboard-only workflows, larger text/display
  settings and actual touch hardware require review. A 44-point custom-control baseline
  does not establish touch-platform support.
- **Release:** Developer ID/hardened-runtime signing, notarization, clean-Mac installation,
  vulnerability/legal review, third-party notices after upgrades and the app source
  license remain pending. The development credential fallback is unencrypted and disclosed.

Concurrent mixed sessions, suspend/resume, changed networks, failed DNS and repeated
reconnect/disconnect under memory/thread diagnostics also need broader coverage.
Disabled protected entries yield SKIP, never a real-server pass.
