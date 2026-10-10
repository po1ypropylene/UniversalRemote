"""Local, synthetic SSH server; never executes received commands on the host."""
import base64
import hashlib
import socket
import sys
import subprocess
import threading
from pathlib import Path
import paramiko
from sftp_fixture import Files, FixtureSFTPServer

root = Path(sys.argv[1]); root.mkdir(parents=True, exist_ok=True)
mode = sys.argv[2] if len(sys.argv) > 2 else 'interactive'
host_key = paramiko.RSAKey.generate(2048)
user_key = paramiko.RSAKey.generate(2048)
(root / 'fingerprint').write_text('SHA256:' + base64.b64encode(hashlib.sha256(host_key.asbytes()).digest()).decode().rstrip('='))
user_key.write_private_key_file(str(root / 'user-key.pem'), password='fixture-passphrase')
ed_key_path = root / 'ed25519-key'
if ed_key_path.exists(): ed_key_path.unlink()
if ed_key_path.with_suffix('.pub').exists(): ed_key_path.with_suffix('.pub').unlink()
subprocess.run(['ssh-keygen','-q','-t','ed25519','-N','fixture-passphrase','-f',str(ed_key_path)], check=True)
ed_key = paramiko.Ed25519Key.from_private_key_file(str(ed_key_path), password='fixture-passphrase')
class Server(paramiko.ServerInterface):
    def __init__(self):
        self.shell = threading.Event()
        self.channel = None
    def get_allowed_auths(self, username):
        if mode.startswith('keyboard-'): return 'keyboard-interactive'
        if mode == 'key-only': return 'publickey'
        return 'password,publickey,keyboard-interactive'
    def check_auth_none(self, username):
        return paramiko.AUTH_SUCCESSFUL if mode == 'none-auth' and username == 'fixture' else paramiko.AUTH_FAILED
    def check_auth_password(self, username, password):
        if mode.startswith('keyboard-') or mode in ('password-fallback', 'key-only'): return paramiko.AUTH_FAILED
        return paramiko.AUTH_SUCCESSFUL if username == 'fixture' and password == 'fixture-password' else paramiko.AUTH_FAILED
    def check_auth_publickey(self, username, key):
        return paramiko.AUTH_SUCCESSFUL if username == 'fixture' and key in (user_key, ed_key) else paramiko.AUTH_FAILED
    def check_auth_interactive(self, username, submethods):
        if mode == 'key-only' or username != 'fixture': return paramiko.AUTH_FAILED
        if mode == 'keyboard-code':
            return paramiko.InteractiveQuery('Fixture code', '', ('Verification code:', False))
        if mode == 'keyboard-echo':
            return paramiko.InteractiveQuery('Fixture visible prompt', '', ('Password:', True))
        if mode in ('keyboard-password', 'keyboard-no-shell', 'password-fallback'):
            return paramiko.InteractiveQuery('Fixture password', '', ('Password:', False))
        return paramiko.InteractiveQuery('Fixture MFA', 'Test prompts', ('Password:', False), ('Code:', False))
    def check_auth_interactive_response(self, responses):
        expected = ['fixture-password', '123456']
        if mode == 'keyboard-code': expected = ['123456']
        if mode in ('keyboard-password', 'keyboard-no-shell', 'keyboard-echo', 'password-fallback'):
            expected = ['fixture-password']
        return paramiko.AUTH_SUCCESSFUL if responses == expected else paramiko.AUTH_FAILED
    def check_channel_request(self, kind, channel):
        if mode == 'channel-denied' and channel == 0:
            return paramiko.OPEN_FAILED_ADMINISTRATIVELY_PROHIBITED
        return paramiko.OPEN_SUCCEEDED if kind == 'session' else paramiko.OPEN_FAILED_ADMINISTRATIVELY_PROHIBITED
    def check_channel_pty_request(self, channel, term, width, height, *args):
        return mode not in ('no-pty', 'no-services') and term == b'xterm-256color'
    def check_channel_shell_request(self, channel):
        if mode in ('no-shell', 'keyboard-no-shell'): return False
        self.channel = channel
        self.shell.set()
        return True
    def check_channel_window_change_request(self, channel, width, height, *args):
        channel.send(f'RESIZED:{width}x{height}\r\n'.encode()); return True

def serve_shell(transport, channel):
    try:
        if mode == 'shell-eof':
            channel.send_exit_status(0)
            channel.shutdown_write()
            channel.close()
            return
        channel.send(b'\x1b[32mFIXTURE_READY\x1b[0m\r\n')
        buffer = b''
        while transport.is_active():
            data = channel.recv(4096)
            if not data: break
            buffer += data.replace(b'\r', b'\n')
            while b'\n' in buffer:
                line, buffer = buffer.split(b'\n', 1)
                if line.strip() == b'exit':
                    channel.send_exit_status(0); channel.shutdown_write(); channel.close()
                    return
                channel.send(b'INPUT:' + line + b'\r\n')
    except Exception:
        pass

def serve(sock):
    transport = paramiko.Transport(sock); transport.add_server_key(host_key); server = Server()
    if mode not in ('no-sftp', 'no-services'):
        transport.set_subsystem_handler('sftp', FixtureSFTPServer, Files, root=root)
    try:
        transport.start_server(server=server)
        shell_started = False
        channels = []
        # Keep the authenticated transport alive for subsystem-only clients.
        while transport.is_active():
            channel = transport.accept(0.05)
            if channel is not None: channels.append(channel)
            if server.shell.is_set() and not shell_started:
                shell_started = True
                threading.Thread(target=serve_shell, args=(transport, server.channel), daemon=True).start()
    except Exception:
        pass
    finally:
        transport.close()
listener = socket.socket(); listener.bind(('127.0.0.1', 0)); listener.listen(10)
(root / 'port').write_text(str(listener.getsockname()[1]))
print('Synthetic SSH fixture ready', flush=True)
while True:
    sock, _ = listener.accept()
    threading.Thread(target=serve, args=(sock,), daemon=True).start()
