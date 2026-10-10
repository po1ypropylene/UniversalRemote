# Testing

```sh
swift test --scratch-path .build/core-tests

# Test-only Python dependency; it is not bundled in the app.
python3 -m venv .dependencies/test-venv
.dependencies/test-venv/bin/python -m pip install 'paramiko==4.0.0'
scripts/test-ssh.sh
scripts/test-sftp.sh
scripts/test-sftp-throughput.sh

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
resize, rejected trust, wrong passwords, and cancellation. Reused fixture modes
cover keyboard-interactive-only passwords, password-method fallback, MFA, visible
and code-only prompts, prompt cancellation, unsupported methods and none authentication.
Workspace checks cover fresh credential prompts after rejection and explicit
Interactive retry without loading saved secrets. They also exercise the production
Workspace/RemoteSession/native adapter from a rejected saved password through a
fresh prompt to a file-only SFTP listing. Run `scripts/build.sh` first; this check
reuses its SwiftTerm module/object while all test executables/preferences are disposable.
SFTP checks include
file-only connections after channel/PTY/shell refusal or immediate shell EOF,
refusal of both services, keyboard-interactive password sign-in without a shell,
byte-verified transfers/overwrites and cancellation
that retains file access without a terminal. The RDP fixture uses
an upstream sample desktop, not the user's screen, and checks TLS trust decisions,
framebuffer delivery, and cancellation. It can also enable NLA with a synthetic
SAM file through `UNIVERSALREMOTE_FIXTURE_NLA` and `UNIVERSALREMOTE_FIXTURE_SAM`.
The disposable RDP fixture also echoes synthetic Unicode clipboard text through
the actual clipboard channel, including updates and clearing. The audio test opens
the Mac output device and plays silence; the keyboard test uses synthetic events.
These tests never read the user's clipboard. Audible playback from a real server
still needs verification.
Fixture processes are stopped when their harness exits.

See [validation](validation.md) for completed checks and remaining release validation.
Real Windows/xrdp interoperability, clipboard round trips, all keyboard layouts,
long-running sessions, network recovery and accessibility with VoiceOver require
further validation before a production release. Older macOS and Intel are unsupported.


## Additional regression checks

```sh
python3 -m unittest discover -s Tests/Maintenance -v
scripts/test-workspace.sh
scripts/test-wireguard.sh
scripts/test-wireguard-lifecycle.sh
scripts/test-wireguard-migration.sh
scripts/test-wireguard-rdp.sh
```

Run RDP TLS and NLA suites sequentially: their sample server uses a fixed loopback port. WireGuard RDP and protected-probe checks use distinct fixed ports. Do not run two instances of the same RDP suite concurrently.

## Fixture retention

Keep tracked integration sources when they test a distinct behavior: authentication/trust, cancellation, byte equality, atomic overwrite, recursive move safety, sandbox inheritance, migration, input coordinates or bounded performance. They are reproducible test tools, not app seed data. Keep the blank server-document example because setup/import depends on it.

Every shell integration harness creates an owner-only unique directory under `.build/tests`, stops and waits for its child servers, and deletes the directory on success, failure or interruption. Generated keys, data, executables and logs are disposable. The RDP sample-server build is reusable infrastructure under `.dependencies/rdp-fixture`; its patch is derived from tracked sources. Logs from ordinary tests are not archived. `scripts/clean-project.py --apply` removes leftovers from killed/crashed runs along with other build outputs.

UI reviews should use an isolated app, in-memory metadata and synthetic profiles. Do not open the user's restored sessions or browse Home merely to inspect layout. Use disposable files for transfer tests. Touch-target checks inspect bounds and edge clicks; they do not establish physical touchscreen support on macOS.
