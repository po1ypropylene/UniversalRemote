#import "SSHClient.h"
#import <fcntl.h>
#import <libssh2.h>
#import <netdb.h>
#import <poll.h>
#import <stdatomic.h>
#import <sys/socket.h>
#import <time.h>
#import <unistd.h>

@interface URSSHClient () {
    atomic_bool _stopped;
    NSLock *_lock;
    NSMutableData *_outgoing;
    int _socket;
    NSInteger _columns, _rows;
    BOOL _resizePending;
}
@end

static double monotonicTime(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec / 1e9;
}
static void keyboardPrompt(const char *name, int nameLen, const char *instruction, int instructionLen, int count,
                           const LIBSSH2_USERAUTH_KBDINT_PROMPT *prompts, LIBSSH2_USERAUTH_KBDINT_RESPONSE *responses,
                           void **abstract) {
    URSSHClient *client = (__bridge URSSHClient *)*abstract;
    for (int i = 0; i < count; i++) {
        NSString *prompt = [[NSString alloc] initWithBytes:prompts[i].text
                                                    length:prompts[i].length
                                                  encoding:NSUTF8StringEncoding]
                               ?: @"Authentication response";
        NSString *answer = client.onPrompt ? client.onPrompt(prompt, prompts[i].echo != 0) : nil;
        const char *utf8 = (answer ?: @"").UTF8String;
        responses[i].text = strdup(utf8);
        responses[i].length = (unsigned int)strlen(utf8);
    }
}

@implementation URSSHClient
- (instancetype)init {
    if ((self = [super init])) {
        _lock = [NSLock new];
        _outgoing = [NSMutableData new];
        _socket = -1;
        _columns = 100;
        _rows = 30;
        atomic_init(&_stopped, false);
    }
    return self;
}
- (void)status:(NSString *)state message:(NSString *)message {
    if (self.onStatus)
        self.onStatus(state, message);
}
- (BOOL)waitSocket:(LIBSSH2_SESSION *)session deadline:(double)deadline {
    if (atomic_load(&_stopped) || monotonicTime() >= deadline)
        return NO;
    int direction = session ? libssh2_session_block_directions(session) : 0;
    short events = session ? 0 : POLLOUT;
    if (direction & LIBSSH2_SESSION_BLOCK_INBOUND)
        events |= POLLIN;
    if (direction & LIBSSH2_SESSION_BLOCK_OUTBOUND)
        events |= POLLOUT;
    if (!events)
        events = POLLIN | POLLOUT;
    struct pollfd p = {_socket, events, 0};
    poll(&p, 1, 100);
    return !atomic_load(&_stopped) && monotonicTime() < deadline;
}
- (BOOL)openSocket:(NSString *)host port:(NSInteger)port {
    struct addrinfo hints = {0}, *addresses = NULL;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_family = AF_UNSPEC;
    if (getaddrinfo(host.UTF8String, [@(port).stringValue UTF8String], &hints, &addresses))
        return NO;
    BOOL connected = NO;
    double deadline = monotonicTime() + 20;
    for (struct addrinfo *a = addresses; a && !atomic_load(&_stopped); a = a->ai_next) {
        int fd = socket(a->ai_family, a->ai_socktype, a->ai_protocol);
        if (fd < 0)
            continue;
        int one = 1;
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
        fcntl(fd, F_SETFL, O_NONBLOCK);
        [_lock lock];
        _socket = fd;
        [_lock unlock];
        int rc = connect(fd, a->ai_addr, a->ai_addrlen);
        if (rc == 0)
            connected = YES;
        else if (errno == EINPROGRESS) {
            while ([self waitSocket:NULL deadline:deadline]) {
                struct pollfd p = {fd, POLLOUT, 0};
                if (poll(&p, 1, 0) > 0) {
                    int error = 0;
                    socklen_t length = sizeof(error);
                    getsockopt(fd, SOL_SOCKET, SO_ERROR, &error, &length);
                    connected = error == 0;
                    break;
                }
            }
        }
        if (connected)
            break;
        [_lock lock];
        close(fd);
        _socket = -1;
        [_lock unlock];
    }
    freeaddrinfo(addresses);
    return connected && !atomic_load(&_stopped);
}
- (void)connectHost:(NSString *)host
               port:(NSInteger)port
           username:(NSString *)username
           password:(NSString *)password
         privateKey:(NSData *)key
     authentication:(NSString *)authentication {
    // One worker owns all libssh2 handles. Public methods only enqueue input or
    // interrupt the socket.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      @autoreleasepool {
          [self runHost:host
                        port:port
                    username:username
                    password:password
                  privateKey:key
              authentication:authentication];
      }
    });
}
- (void)runHost:(NSString *)host
              port:(NSInteger)port
          username:(NSString *)username
          password:(NSString *)password
        privateKey:(NSData *)key
    authentication:(NSString *)authentication {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      libssh2_init(0);
    });
    LIBSSH2_SESSION *session = NULL;
    LIBSSH2_CHANNEL *channel = NULL;
    NSString *failure = nil;
    NSString *fingerprint = nil;
    double deadline = monotonicTime() + 30;
    int rc = 0;
    [self status:@"connecting" message:@"Connecting to server…"];
    if (![self openSocket:host port:port]) {
        failure = @"Could not reach the SSH server. Check the host, port, and network.";
        goto cleanup;
    }
    session = libssh2_session_init_ex(NULL, NULL, NULL, (__bridge void *)self);
    if (!session) {
        failure = @"Could not initialize SSH.";
        goto cleanup;
    }
    libssh2_session_set_blocking(session, 0);
    while ((rc = libssh2_session_handshake(session, _socket)) == LIBSSH2_ERROR_EAGAIN && [self waitSocket:session
                                                                                                 deadline:deadline]) {
    }
    if (rc) {
        failure = @"SSH handshake failed or timed out.";
        goto cleanup;
    }
    const char *hash = libssh2_hostkey_hash(session, LIBSSH2_HOSTKEY_HASH_SHA256);
    if (!hash) {
        failure = @"The server did not supply a verifiable host key.";
        goto cleanup;
    }
    fingerprint =
        [@"SHA256:" stringByAppendingString:[[[NSData dataWithBytes:hash length:32] base64EncodedStringWithOptions:0]
                                                stringByReplacingOccurrencesOfString:@"="
                                                                          withString:@""]];
    [self status:@"verifying" message:@"Verifying server identity…"];
    if (!self.onTrust || !self.onTrust(fingerprint, @"SSH host key")) {
        failure = @"Server identity was not trusted.";
        goto cleanup;
    }
    if (atomic_load(&_stopped))
        goto cleanup;
    [self status:@"authenticating" message:@"Signing in…"];
    deadline = monotonicTime() + 120;
    const char *user = username.UTF8String;
    unsigned int userLen = (unsigned int)strlen(user);
    do {
        if ([authentication isEqualToString:@"privateKey"])
            rc = libssh2_userauth_publickey_frommemory(session, user, userLen, NULL, 0, key.bytes, key.length,
                                                       password.UTF8String);
        else if ([authentication isEqualToString:@"interactive"])
            rc = libssh2_userauth_keyboard_interactive_ex(session, user, userLen, keyboardPrompt);
        else
            rc = libssh2_userauth_password_ex(session, user, userLen, password.UTF8String,
                                              (unsigned int)strlen(password.UTF8String), NULL);
    } while (rc == LIBSSH2_ERROR_EAGAIN && [self waitSocket:session deadline:deadline]);
    if (rc) {
        failure = [NSString stringWithFormat:@"SSH authentication failed (%d). Check your credentials or choose "
                                             @"keyboard-interactive authentication if the server requires it.",
                                             rc];
        goto cleanup;
    }
    deadline = monotonicTime() + 20;
    do {
        channel = libssh2_channel_open_session(session);
    } while (!channel && libssh2_session_last_errno(session) == LIBSSH2_ERROR_EAGAIN &&
             [self waitSocket:session deadline:deadline]);
    if (!channel) {
        failure = @"Could not open an SSH shell channel.";
        goto cleanup;
    }
    [_lock lock];
    int cols = (int)_columns, rows = (int)_rows;
    [_lock unlock];
    do {
        rc = libssh2_channel_request_pty_ex(channel, "xterm-256color", 14, NULL, 0, cols, rows, 0, 0);
    } while (rc == LIBSSH2_ERROR_EAGAIN && [self waitSocket:session deadline:deadline]);
    if (rc) {
        failure = @"The server refused an interactive terminal.";
        goto cleanup;
    }
    do {
        rc = libssh2_channel_shell(channel);
    } while (rc == LIBSSH2_ERROR_EAGAIN && [self waitSocket:session deadline:deadline]);
    if (rc) {
        failure = @"The server refused a shell.";
        goto cleanup;
    }
    libssh2_keepalive_config(session, 1, 30);
    [self status:@"connected" message:@"SSH connected"];
    while (!atomic_load(&_stopped) && !libssh2_channel_eof(channel)) {
        @autoreleasepool {
            [_lock lock];
            NSData *pending = [_outgoing copy];
            [_lock unlock];
            if (pending.length) {
                ssize_t sent = libssh2_channel_write(channel, pending.bytes, pending.length);
                if (sent > 0) {
                    [_lock lock];
                    [_outgoing replaceBytesInRange:NSMakeRange(0, sent) withBytes:NULL length:0];
                    [_lock unlock];
                } else if (sent < 0 && sent != LIBSSH2_ERROR_EAGAIN) {
                    failure = @"The SSH connection was interrupted.";
                    break;
                }
            }
            [_lock lock];
            BOOL resize = _resizePending;
            cols = (int)_columns;
            rows = (int)_rows;
            [_lock unlock];
            if (resize && libssh2_channel_request_pty_size(channel, cols, rows) == 0) {
                [_lock lock];
                if (cols == _columns && rows == _rows)
                    _resizePending = NO;
                [_lock unlock];
            }
            char buffer[32768];
            BOOL readAny = NO;
            for (int stream = 0; stream < 2; stream++) {
                ssize_t count;
                while ((count = libssh2_channel_read_ex(channel, stream, buffer, sizeof(buffer))) > 0) {
                    readAny = YES;
                    if (self.onData)
                        self.onData([NSData dataWithBytes:buffer length:count]);
                    if (atomic_load(&_stopped))
                        break;
                }
                if (count < 0 && count != LIBSSH2_ERROR_EAGAIN && !libssh2_channel_eof(channel)) {
                    failure = @"The SSH connection was interrupted.";
                }
            }
            if (failure)
                break;
            int next = 0;
            libssh2_keepalive_send(session, &next);
            if (!readAny) {
                struct pollfd p = {_socket, POLLIN, 0};
                poll(&p, 1, 20);
            }
        }
    }
cleanup:
    [_lock lock];
    if (_socket >= 0)
        shutdown(_socket, SHUT_RDWR);
    [_lock unlock];
    if (session) {
        libssh2_session_set_blocking(session, 1);
        libssh2_session_set_timeout(session, 1000);
    }
    if (channel) {
        libssh2_channel_close(channel);
        libssh2_channel_free(channel);
    }
    if (session) {
        libssh2_session_disconnect(session, "Disconnected");
        libssh2_session_free(session);
    }
    [_lock lock];
    if (_socket >= 0)
        close(_socket);
    _socket = -1;
    [_outgoing setLength:0];
    [_lock unlock];
    if (failure && !atomic_load(&_stopped))
        [self status:@"failed" message:failure];
    else
        [self status:@"disconnected" message:@"SSH disconnected"];
}
- (void)sendData:(NSData *)data {
    [_lock lock];
    if (_outgoing.length + data.length <= 1024 * 1024)
        [_outgoing appendData:data];
    [_lock unlock];
}
- (void)resizeColumns:(NSInteger)columns rows:(NSInteger)rows {
    [_lock lock];
    _columns = MAX(1, columns);
    _rows = MAX(1, rows);
    _resizePending = YES;
    [_lock unlock];
}
- (void)disconnect {
    atomic_store(&_stopped, true);
    [_lock lock];
    if (_socket >= 0)
        shutdown(_socket, SHUT_RDWR);
    [_lock unlock];
}
@end
