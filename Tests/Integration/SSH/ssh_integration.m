#import "SSHClient.h"
#import <Foundation/Foundation.h>
#import <libssh2.h>

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc < 4)
            return 2;
        NSString *mode = @(argv[1]);
        int port = atoi(argv[2]);
        NSString *keyPath = @(argv[3]);
        URSSHClient *client = [URSSHClient new];
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block BOOL trusted = NO, connected = NO, failed = NO, verifiedInput = NO, resized = NO;
        __block int prompts = 0;
        NSMutableString *received = [NSMutableString new];
        __block BOOL sentExit = NO;
        __weak URSSHClient *weakClient = client;
        client.onTrust = ^BOOL(NSString *fingerprint, NSString *details) {
          trusted = YES;
          return ![mode isEqualToString:@"reject"];
        };
        client.onPrompt = ^NSString *(NSString *prompt, BOOL echo) {
          prompts++;
          return [prompt containsString:@"Code"] ? @"123456" : @"fixture-password";
        };
        client.onData = ^(NSData *data) {
          NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
          [received appendString:text];
          if ([received containsString:@"INPUT:integration-check"])
              verifiedInput = YES;
          if ([received containsString:@"RESIZED:120x40"])
              resized = YES;
          if (verifiedInput && resized && !sentExit) {
              sentExit = YES;
              [weakClient sendData:[@"exit\n" dataUsingEncoding:NSUTF8StringEncoding]];
          }
        };
        client.onStatus = ^(NSString *status, NSString *message) {
          if ([status isEqualToString:@"connected"]) {
              connected = YES;
              [weakClient resizeColumns:120 rows:40];
              [weakClient sendData:[@"integration-check\n" dataUsingEncoding:NSUTF8StringEncoding]];
              if ([mode isEqualToString:@"cancel"])
                  [weakClient disconnect];
          }
          if ([status isEqualToString:@"failed"]) {
              failed = YES;
              printf("  %s\n", message.UTF8String);
          }
          if ([status isEqualToString:@"failed"] || [status isEqualToString:@"disconnected"])
              dispatch_semaphore_signal(done);
        };
        NSString *authentication = ([mode isEqualToString:@"key"] || [mode isEqualToString:@"ed25519"]) ? @"privateKey"
                                   : [mode isEqualToString:@"interactive"]                              ? @"interactive"
                                                                                                        : @"password";
        NSData *key = ([mode isEqualToString:@"key"] || [mode isEqualToString:@"ed25519"])
                          ? [NSData dataWithContentsOfFile:keyPath]
                          : nil;
        NSString *password = ([mode isEqualToString:@"key"] || [mode isEqualToString:@"ed25519"])
                                 ? @"fixture-passphrase"
                             : [mode isEqualToString:@"bad-password"] ? @"wrong"
                                                                      : @"fixture-password";
        [client connectHost:@"127.0.0.1"
                       port:port
                   username:@"fixture"
                   password:password
                 privateKey:key
             authentication:authentication];
        BOOL timedOut = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC)) != 0;
        [client disconnect];
        BOOL expectedFailure = [mode isEqualToString:@"reject"] || [mode isEqualToString:@"bad-password"];
        BOOL passed = !timedOut && trusted && (expectedFailure ? failed && !connected : connected && !failed);
        if (!expectedFailure && ![mode isEqualToString:@"cancel"])
            passed = passed && verifiedInput && resized;
        if ([mode isEqualToString:@"interactive"])
            passed = passed && prompts == 2;
        printf("%s SSH %s\n", passed ? "PASS" : "FAIL", mode.UTF8String);
        return passed ? 0 : 1;
    }
}
