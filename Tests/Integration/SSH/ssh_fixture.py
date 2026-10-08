"""Local, synthetic SSH server; never executes received commands on the host."""
import base64
import hashlib
import socket
import sys
import subprocess
import threading
import time
from pathlib import Path
import paramiko

root = Path(sys.argv[1]); root.mkdir(parents=True, exist_ok=True)
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
    def get_allowed_auths(self, username): return 'password,publickey,keyboard-interactive'
    def check_auth_password(self, username, password):
        return paramiko.AUTH_SUCCESSFUL if username == 'fixture' and password == 'fixture-password' else paramiko.AUTH_FAILED
    def check_auth_publickey(self, username, key):
        return paramiko.AUTH_SUCCESSFUL if username == 'fixture' and key in (user_key, ed_key) else paramiko.AUTH_FAILED
    def check_auth_interactive(self, username, submethods):
        return paramiko.InteractiveQuery('Fixture MFA', 'Test prompts', ('Password:', False), ('Code:', False))
    def check_auth_interactive_response(self, responses):
        return paramiko.AUTH_SUCCESSFUL if responses == ['fixture-password', '123456'] else paramiko.AUTH_FAILED
    def check_channel_request(self, kind, channel): return paramiko.OPEN_SUCCEEDED if kind == 'session' else paramiko.OPEN_FAILED_ADMINISTRATIVELY_PROHIBITED
    def check_channel_pty_request(self, channel, term, width, height, *args): return term == b'xterm-256color'
    def check_channel_shell_request(self, channel): self.shell.set(); return True
    def check_channel_window_change_request(self, channel, width, height, *args):
        channel.send(f'RESIZED:{width}x{height}\r\n'.encode()); return True

def serve(sock):
    transport = paramiko.Transport(sock); transport.add_server_key(host_key); server = Server()
    try:
        transport.start_server(server=server)
        channel = transport.accept(15)
        if not channel or not server.shell.wait(10): return
        channel.send(b'\x1b[32mFIXTURE_READY\x1b[0m\r\n')
        buffer = b''
        while transport.is_active():
            data = channel.recv(4096)
            if not data: break
            buffer += data.replace(b'\r', b'\n')
            while b'\n' in buffer:
                line, buffer = buffer.split(b'\n', 1)
                if line.strip() == b'exit': channel.send_exit_status(0); channel.shutdown_write(); channel.close(); time.sleep(0.1); return
                channel.send(b'INPUT:' + line + b'\r\n')
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
