# Live user-flow review — 8 October 2026

The supplied SSH and Windows RDP servers were exercised through the app's connection editor and session controls. Both protocols authenticated and carried real interactive input/output. The RDP desktop rendered through Metal using the software bitmap negotiation introduced in the preceding fix.

## Method

A private review build compiled the current production screens, workspace actions and protocol adapters, with an isolated durable SwiftData library. A test-only editor button populated credentials from the protected JSON in memory. Names, port, dimensions and organization were exercised through the UI. Private instrumentation recorded booleans, dimensions and counts only. This is a UI workflow test, but not literal manual typing of every credential into the unchanged Release binary.

The populated disabled JSON entries were selected for this authorized run without editing the file. The user supplied an independently verified SSH public host key; its SHA256 fingerprint matched the presented identity before trust was remembered. RDP certificate validation succeeded without an accept-all override. Remote-surface covers were removed after the user's explicit authorization, and the disposable machines were controlled directly. No passwords, endpoint identities or terminal contents are included in this report.

## Verified flows

| Flow | Result |
| --- | --- |
| New RDP → Save → reopen Edit | Profile and saved password reopened |
| Edit initial RDP size → Save & Connect | Visible 1280×720 desktop; no credential re-entry |
| New SSH → Save & Connect → verify host identity | Authenticated shell |
| Quit/relaunch | Saved profiles, credentials, favorite and folder persisted; restored tabs disconnected |
| Invalid port | Validation appeared; save actions disabled |
| Duplicate/edit/delete | Copy created without a copied password; disposable copy removed through confirmation |
| Favorites, sidebar filtering, folder assignment | UI changes and persistence verified |
| Mixed SSH/RDP tabs and selection | Both sessions usable; input switched to selected surface |
| RDP pointer and typing | Start menu and Notepad opened; ASCII text and Return reached the correct remote controls |
| RDP Ctrl–Alt–Delete | Windows security screen displayed; Cancel returned to desktop |
| RDP disconnect/reconnect | Disabled input/actions while disconnected; fresh visible desktop on reconnect |
| Connection Details | Inspector opened and closed |
| Full-screen button | Entry and exit verified for both protocols |
| SSH commands | Harmless printf, stty size and 60-line output completed |
| SSH output | ANSI color, generated accented/CJK UTF-8, scrollback and output markers verified |
| SSH Find | Next selected the generated marker in terminal output |
| SSH font controls | Font size changed from 14 to 15 points |

The SSH command run disabled shell history recording for that shell and did not intentionally write remote files. The unsaved Notepad test was closed with Don't Save. No logout, reboot, password change or clipboard access was performed.

## Findings requiring follow-up

1. **P1 — Keychain authorization can stall the window in rebuilt development apps.** Initial credential save/reload and relaunch succeeded. After repeated ad-hoc rebuilds, a diagnostic call to the production CredentialStore.load blocked the main thread inside SecItemCopyMatching and SecurityServer; a subsequent ordinary saved-profile reconnect also timed out. Workspace.connect and editor credential loading call this synchronous API on the main actor. Changing the signed binary can require macOS authorization, but the exact authorization reason was not visible. This is not evidence that paid developer enrollment is required. The local fallback only helps after Keychain returns an unavailable status; it cannot resolve a call still waiting. Follow up by keeping credential I/O off the UI thread and defining an explicit prompt/cancellation or noninteractive lookup policy. A stable signing identity needs a separate test.
2. **P2 — Reconnect moves a tab to the end.** With tabs ordered RDP, SSH, reconnecting RDP produced SSH, RDP. Workspace.reconnect closes the old session and connect appends its replacement. Preserve the original insertion position when replacing a session; verify both successful and failed reconnects.
3. **P2 — Match-window RDP resolution silently remains fixed on this server.** Initial dimensions worked, but resizing/full-screen transitions retained a 1280×720 texture. Native instrumentation showed resize requests dropped because no display-control channel was available. This is confirmed for the supplied server with the current software bitmap negotiation, not every RDP server. Surface that capability/limitation and investigate channel negotiation or a deliberate reconnect-resize fallback.

## Limits and testing distinctions

After the Keychain stall, the remaining session checks used the same local credential-store implementation with a private test directory, populated from the JSON. That verifies local retrieval and transport, not a newly triggered automatic fallback from the stalled Keychain call. Earlier core tests cover local file replacement, reopening, permissions and deletion.

The desktop-control tool dropped non-ASCII typed input in both a local name field and remote Notepad. Therefore Unicode/IME keyboard entry remains unverified; generated SSH Unicode output passed. Ctrl–Alt–Delete initially appeared ineffective through accessibility actions but worked through the visible button, so it is not reported as an app defect. Full-screen timeouts were traced to the diagnostic Keychain read; full-screen behavior subsequently passed.

Quick Connect, clipboard, drag reordering, full-screen terminal programs, long sessions, suspend/resume and changed networks were not covered in this review. These results establish compatibility with the two supplied test servers, not a broad server matrix.

## Cleanup

Both sessions were disconnected and the tracked disposable profiles and local credential files were removed; the isolated library reported zero profiles and the private credential directory contained no JSON files. Keychain deletion was attempted with interaction disabled; no error surfaced, but item absence was not independently verified. The review app was quit, and its bundle, isolated library, private credential directory and preferences were then removed. The protected server JSON retained its original SHA256 digest and mode 600. Private test tooling stays under ignored .build; no test hook was added to shipped sources. No commit or publication was made.
