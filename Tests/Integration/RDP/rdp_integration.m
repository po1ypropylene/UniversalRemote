#import "RDPClient.h"
#import <Foundation/Foundation.h>
int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc < 3)
            return 2;
        NSString *mode = @(argv[1]);
        NSInteger port = atoi(argv[2]);
        URRDPClient *client = [URRDPClient new];
        __weak URRDPClient *weakClient = client;
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block BOOL trusted = NO, connected = NO, failed = NO, frame = NO;
        client.onTrust = ^BOOL(NSString *fingerprint, NSString *details) {
          trusted = [fingerprint hasPrefix:@"SHA256:"];
          return ![mode isEqualToString:@"reject"];
        };
        client.onClipboard = ^(NSString *text) {
        };
        client.onCursor = ^(NSData *pixels, NSInteger w, NSInteger h, NSInteger x, NSInteger y) {
        };
        client.onFrame = ^(NSData *pixels, NSInteger w, NSInteger h, NSInteger stride) {
          frame = pixels.length == stride * h && w > 0 && h > 0;
          if (frame)
              [weakClient disconnect];
        };
        client.onStatus = ^(NSString *state, NSString *message) {
          if ([state isEqualToString:@"connected"]) {
              connected = YES;
              [weakClient sendScanCode:0x1E pressed:YES extended:NO];
              [weakClient sendScanCode:0x1E pressed:NO extended:NO];
              [weakClient sendPointerFlags:0x0800 x:50 y:50];
              if ([mode isEqualToString:@"cancel"])
                  [weakClient disconnect];
          }
          if ([state isEqualToString:@"failed"]) {
              failed = YES;
              printf("  %s\n", message.UTF8String);
          }
          if ([state isEqualToString:@"failed"] || [state isEqualToString:@"disconnected"])
              dispatch_semaphore_signal(done);
        };
        [client connectHost:@"127.0.0.1"
                       port:port
                   username:@"fixture"
                     domain:@""
                   password:([mode isEqualToString:@"bad-password"] ? @"wrong" : @"fixture-password")width:1024
                     height:768
                      scale:100
                  clipboard:YES];
        BOOL timeout = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 25 * NSEC_PER_SEC)) != 0;
        [client disconnect];
        BOOL pass = !timeout && trusted;
        if ([mode isEqualToString:@"reject"] || [mode isEqualToString:@"bad-password"])
            pass = pass && failed && !connected;
        else
            pass = pass && connected && !failed && ([mode isEqualToString:@"cancel"] || frame);
        printf("%s RDP %s (trust=%d connected=%d frame=%d)\n", pass ? "PASS" : "FAIL", mode.UTF8String, trusted,
               connected, frame);
        return pass ? 0 : 1;
    }
}
