#import "SSHClient.h"
#import <Foundation/Foundation.h>
int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc != 5)
            return 2;
        BOOL upload = [@(argv[1]) isEqual:@"upload"];
        NSString *root = @(argv[3]);
        NSString *pin = [NSString stringWithContentsOfFile:@(argv[4]) encoding:NSUTF8StringEncoding error:nil];
        NSString *local =
            [root stringByAppendingPathComponent:upload ? @"cancel-upload-source" : @"cancel-download-target"];
        if (upload)
            [[NSMutableData dataWithLength:32 * 1024 * 1024] writeToFile:local atomically:YES];
        else
            [[NSFileManager defaultManager] removeItemAtPath:local error:nil];
        URSSHClient *client = [URSSHClient new];
        __weak URSSHClient *weak = client;
        dispatch_semaphore_t ready = dispatch_semaphore_create(0), reply = dispatch_semaphore_create(0),
                             echo = dispatch_semaphore_create(0);
        dispatch_semaphore_t finished = dispatch_semaphore_create(0);
        __block BOOL stopped = NO, cancelled = NO, responseError = NO, resumed = NO;
        __block int trusts = 0;
        NSMutableString *text = [NSMutableString new];
        client.onTrust = ^BOOL(NSString *fingerprint, NSString *details) {
          trusts++;
          return [pin isEqual:fingerprint];
        };
        client.onStatus = ^(NSString *state, NSString *message) {
          if ([state isEqual:@"connected"])
              dispatch_semaphore_signal(ready);
          if ([state isEqual:@"disconnected"] || [state isEqual:@"failed"]) {
              stopped = YES;
              dispatch_semaphore_signal(finished);
          }
        };
        client.onData = ^(NSData *data) {
          [text appendString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @""];
          if ([text containsString:@"INPUT:after-file-cancel"])
              dispatch_semaphore_signal(echo);
        };
        client.onFiles = ^(NSString *id, NSDictionary *result, NSString *error) {
          if ([id isEqual:@"cancel"])
              responseError = error != nil;
          else
              resumed = error == nil && result[@"entries"] != nil;
          dispatch_semaphore_signal(reply);
        };
        client.onFileProgress = ^(NSString *id, unsigned long long bytes, unsigned long long total) {
          if ([id isEqual:@"cancel"] && bytes > 0 && !cancelled) {
              cancelled = YES;
              [weak cancelFiles];
          }
        };
        [client connectHost:@"127.0.0.1"
                       port:atoi(argv[2])
                   username:@"fixture"
                   password:@"fixture-password"
                 privateKey:nil
             authentication:@"password"];
        if (dispatch_semaphore_wait(ready, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC)))
            return 1;
        [client transferLocalPath:local
                       remotePath:upload ? @"/slow-upload.bin" : @"/slow.bin"
                           upload:upload
                        requestID:@"cancel"];
        BOOL timely = dispatch_semaphore_wait(reply, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC)) == 0;
        [client sendData:[@"after-file-cancel\n" dataUsingEncoding:NSUTF8StringEncoding]];
        BOOL terminal = dispatch_semaphore_wait(echo, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0;
        [client listDirectory:@"/" requestID:@"resumed"];
        BOOL listed = dispatch_semaphore_wait(reply, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0;
        BOOL pass = timely && terminal && listed && cancelled && responseError && resumed && !stopped && trusts == 1;
        if (!upload)
            pass = pass && ![[NSFileManager defaultManager] fileExistsAtPath:local];
        printf("%s SFTP cancel-%s-keeps-terminal-and-reopens-files\n", pass ? "PASS" : "FAIL",
               upload ? "upload" : "download");
        [client disconnect];
        pass = pass && dispatch_semaphore_wait(finished, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0;
        return pass ? 0 : 1;
    }
}
