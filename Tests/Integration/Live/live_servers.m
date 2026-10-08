#import "RDPClient.h"
#import "SSHClient.h"
#import <Foundation/Foundation.h>
#include <sys/stat.h>
#include <unistd.h>

// No connection details, remote terminal data or library diagnostics reach
// stdout. Each connection authenticates and opens a shell/desktop, then
// disconnects.
int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc < 2 || argc > 3)
            return 2;
        BOOL configured = argc == 3 && !strcmp(argv[2], "--configured");
        setbuf(stdout, NULL);
        struct stat attributes;
        if (lstat(argv[1], &attributes) != 0 || !S_ISREG(attributes.st_mode) || attributes.st_uid != getuid() ||
            (attributes.st_mode & 077) != 0 || attributes.st_size > 1048576) {
            puts("FAIL: credentials file must be owned by you, regular, at most 1 "
                 "MB, and mode 600.");
            return 2;
        }
        NSData *bytes = [NSData dataWithContentsOfFile:@(argv[1])];
        NSDictionary *document = bytes ? [NSJSONSerialization JSONObjectWithData:bytes options:0 error:nil] : nil;
        if (![document isKindOfClass:NSDictionary.class] || ![document[@"schemaVersion"] isEqual:@1] ||
            ![document[@"servers"] isKindOfClass:NSArray.class] || [document[@"servers"] count] > 100) {
            puts("FAIL: invalid local test-server document.");
            return 2;
        }
        int index = 0, failures = 0;
        NSMutableSet *ids = [NSMutableSet new];
        for (id item in document[@"servers"]) {
            if (![item isKindOfClass:NSDictionary.class] || ![item[@"enabled"] isKindOfClass:NSNumber.class]) {
                puts("FAIL: invalid server entry.");
                return 2;
            }
            if (![item[@"enabled"] boolValue]) {
                if (!configured || ![item[@"host"] isKindOfClass:NSString.class] || ![item[@"host"] length] ||
                    ![item[@"username"] isKindOfClass:NSString.class] || ![item[@"username"] length])
                    continue;
            }
            index++;
            NSString *kind = item[@"protocol"], *host = item[@"host"], *username = item[@"username"];
            NSString *password = item[@"password"] ?: @"", *domain = item[@"domain"] ?: @"";
            NSString *pin = item[@"expectedFingerprint"] ?: @"";
            NSUUID *identifier =
                [item[@"id"] isKindOfClass:NSString.class] ? [[NSUUID alloc] initWithUUIDString:item[@"id"]] : nil;
            id portValue = item[@"port"];
            BOOL ssh = [kind isKindOfClass:NSString.class] && [kind isEqualToString:@"SSH"];
            BOOL rdp = [kind isKindOfClass:NSString.class] && [kind isEqualToString:@"RDP"];
            BOOL valid =
                identifier && ![ids containsObject:identifier] && (ssh || rdp) && [host isKindOfClass:NSString.class] &&
                host.length > 0 &&
                [host rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location == NSNotFound &&
                ![host containsString:@"/"] && [username isKindOfClass:NSString.class] && username.length > 0 &&
                [password isKindOfClass:NSString.class] && [domain isKindOfClass:NSString.class] &&
                [pin isKindOfClass:NSString.class] && [portValue isKindOfClass:NSNumber.class] &&
                [portValue integerValue] >= 1 && [portValue integerValue] <= 65535 &&
                (!ssh || [pin hasPrefix:@"SHA256:"]);
            if (!valid) {
                printf("FAIL server %d: invalid entry or missing SSH fingerprint.\n", index);
                failures++;
                continue;
            }
            [ids addObject:identifier];
            NSInteger port = [portValue integerValue];
            dispatch_semaphore_t done = dispatch_semaphore_create(0);
            __block BOOL connected = NO, failed = NO, frame = NO;
            BOOL (^trust)(NSString *, NSString *) = ^BOOL(NSString *fingerprint, NSString *details) {
              return pin.length > 0 && [fingerprint isEqualToString:pin];
            };
            URSSHClient *sshClient = ssh ? [URSSHClient new] : nil;
            URRDPClient *rdpClient = rdp ? [URRDPClient new] : nil;
            __weak URSSHClient *weakSSH = sshClient;
            __weak URRDPClient *weakRDP = rdpClient;
            void (^status)(NSString *, NSString *) = ^(NSString *state, NSString *message) {
              if ([state isEqualToString:@"connected"]) {
                  connected = YES;
                  if (ssh)
                      [weakSSH disconnect];
              }
              if ([state isEqualToString:@"failed"])
                  failed = YES;
              if ([state isEqualToString:@"failed"] || [state isEqualToString:@"disconnected"])
                  dispatch_semaphore_signal(done);
            };
            if (ssh) {
                sshClient.onTrust = trust;
                sshClient.onStatus = status;
                sshClient.onData = ^(NSData *data) {
                };
                sshClient.onPrompt = ^NSString *(NSString *prompt, BOOL echo) {
                  return nil;
                };
                [sshClient connectHost:host
                                  port:port
                              username:username
                              password:password
                            privateKey:nil
                        authentication:@"password"];
            } else {
                rdpClient.onTrust = trust;
                rdpClient.onStatus = status;
                rdpClient.onFrame = ^(NSData *pixels, NSInteger width, NSInteger height, NSInteger stride) {
                  frame = width > 0 && height > 0 && stride >= width * 4 && pixels.length == stride * height;
                  if (frame) {
                      // Empty allocation/paint callbacks do not prove a usable desktop.
                      const uint8_t *data = pixels.bytes;
                      BOOL visible = NO;
                      for (NSInteger y = 0; y < height && !visible; y++) {
                          for (NSInteger x = 0; x < width; x++) {
                              const uint8_t *pixel = data + y * stride + x * 4;
                              if (pixel[0] || pixel[1] || pixel[2]) {
                                  visible = YES;
                                  break;
                              }
                          }
                      }
                      frame = visible;
                  }
                  if (frame)
                      [weakRDP disconnect];
                };
                [rdpClient connectHost:host
                                  port:port
                              username:username
                                domain:domain
                              password:password
                                 width:1024
                                height:768
                                 scale:100
                             clipboard:NO
                         audioPlayback:NO];
            }
            BOOL timeout = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 40 * NSEC_PER_SEC)) != 0;
            [sshClient disconnect];
            [rdpClient disconnect];
            BOOL pass = !timeout && connected && !failed && (ssh || frame);
            printf("%s server %d (%s): %s\n", pass ? "PASS" : "FAIL", index, ssh ? "SSH" : "RDP",
                   pass ? (ssh ? "authenticated session opened" : "authenticated desktop pixels received")
                        : (connected && rdp ? "connected but no visible desktop received"
                                            : "connection, identity, authentication or timeout check failed"));
            if (!pass)
                failures++;
        }
        if (!index)
            puts("SKIP: no enabled real servers. Fill the local file before testing.");
        return failures ? 1 : 0;
    }
}
