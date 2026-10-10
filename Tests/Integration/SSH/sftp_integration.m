#import "SSHClient.h"
#import <Foundation/Foundation.h>

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc != 5)
            return 2;
        NSString *mode = @(argv[1]);
        BOOL filesOnly =
            [@[ @"no-pty", @"no-shell", @"channel-denied", @"shell-eof", @"keyboard-no-shell" ] containsObject:mode];
        BOOL noServices = [mode isEqual:@"no-services"];
        NSInteger port = atoi(argv[2]);
        NSString *root = @(argv[3]);
        NSString *pin = [NSString stringWithContentsOfFile:@(argv[4]) encoding:NSUTF8StringEncoding error:nil];
        NSData *payload = [NSMutableData dataWithLength:1024 * 1024 + 19];
        // Nonuniform binary data exposes chunk/pointer corruption.
        NSMutableData *source = [payload mutableCopy];
        for (NSUInteger i = 0; i < source.length; i++)
            ((uint8_t *)source.mutableBytes)[i] = i % 251;
        NSString *local = [root stringByAppendingPathComponent:[mode stringByAppendingString:@"-source.bin"]];
        NSString *download = [root stringByAppendingPathComponent:[mode stringByAppendingString:@"-download.bin"]];
        [source writeToFile:local atomically:YES];
        [[NSFileManager defaultManager] removeItemAtPath:download error:nil];
        FCSSHClient *client = [FCSSHClient new];
        __weak FCSSHClient *weak = client;
        dispatch_semaphore_t done = dispatch_semaphore_create(0);
        __block BOOL passed = NO, input = NO, resized = NO, cancelling = NO;
        __block BOOL terminalUnavailable = NO, connected = NO, listed = NO;
        __block int auth = 0, trusts = 0, phase = 0;
        __block int conflicts = 0;
        __block unsigned long long lastBytes = 0;
        NSMutableString *terminal = [NSMutableString new];
        client.onTrust = ^BOOL(NSString *fingerprint, NSString *details) {
          trusts++;
          return [fingerprint isEqual:pin];
        };
        client.onPrompt = ^NSString *(NSString *prompt, BOOL echo) {
          auth++;
          return [prompt containsString:@"Code"] ? @"123456" : @"fixture-password";
        };
        client.onData = ^(NSData *data) {
          [terminal appendString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @""];
          input = [terminal containsString:@"INPUT:during-transfer"];
          resized = [terminal containsString:@"RESIZED:120x40"];
          if ([mode isEqual:@"no-sftp"] && input && resized)
              [weak disconnect];
        };
        client.onTerminalAvailability = ^(BOOL available) {
          terminalUnavailable = !available;
        };
        if (filesOnly) {
            client.onFileConflict = ^(NSString *token, NSString *name) {
              conflicts++;
              // Exercise the worker wait without a shell; UI responses arrive asynchronously.
              dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC),
                             dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                               [weak resolveFileConflict:token overwrite:YES];
                             });
            };
        }
        client.onStatus = ^(NSString *status, NSString *message) {
          if ([status isEqual:@"connected"]) {
              connected = YES;
              if (listed || (filesOnly && !terminalUnavailable))
                  return;
              listed = YES;
              [weak listDirectory:@"." requestID:@"list"];
          }
          if ([status isEqual:@"failed"] || [status isEqual:@"disconnected"]) {
              if (noServices)
                  passed = [status isEqual:@"failed"] && !connected && !listed;
              if ([mode isEqual:@"cancel"])
                  passed = cancelling && ![[NSFileManager defaultManager] fileExistsAtPath:download];
              dispatch_semaphore_signal(done);
          }
        };
        client.onFileProgress = ^(NSString *request, unsigned long long bytes, unsigned long long total) {
          if (bytes < lastBytes) {
              [weak disconnect];
              return;
          }
          lastBytes = bytes;
          if ([mode isEqual:@"race"] && ![[NSFileManager defaultManager] fileExistsAtPath:download])
              [source writeToFile:download atomically:YES];
          if (bytes > 0) {
              [weak sendData:[@"during-transfer\n" dataUsingEncoding:NSUTF8StringEncoding]];
              [weak resizeColumns:120 rows:40];
          }
          if ([mode isEqual:@"cancel"] && bytes > 0) {
              cancelling = YES;
              [weak disconnect];
          }
        };
        client.onFiles = ^(NSString *request, NSDictionary *result, NSString *error) {
          if ([mode isEqual:@"cancel"] && cancelling)
              return;
          if ([mode isEqual:@"no-sftp"]) {
              passed = error != nil;
              [weak sendData:[@"during-transfer\n" dataUsingEncoding:NSUTF8StringEncoding]];
              [weak resizeColumns:120 rows:40];
              return;
          }
          if (phase == 0) {
              NSArray *entries = result[@"entries"];
              BOOL unicode = NO, folder = NO, link = NO;
              for (NSDictionary *entry in entries) {
                  if ([entry[@"name"] isEqual:@"hello 世界.txt"])
                      unicode = [entry[@"regular"] boolValue] && [entry[@"size"] unsignedLongLongValue] == 2097152;
                  if ([entry[@"name"] isEqual:@"folder"])
                      folder = [entry[@"directory"] boolValue];
                  if ([entry[@"name"] isEqual:@"link"])
                      link = ![entry[@"regular"] boolValue] && ![entry[@"directory"] boolValue];
              }
              if (error || !unicode || !folder || !link || ![result[@"path"] isEqual:@"/"]) {
                  [weak disconnect];
                  return;
              }
              phase++;
              if ([mode isEqual:@"cancel"])
                  [weak transferLocalPath:download remotePath:@"/slow.bin" upload:NO requestID:@"cancel"];
              else if ([mode isEqual:@"missing-file"])
                  [weak transferLocalPath:download remotePath:@"/missing-file" upload:NO requestID:@"missing"];
              else if ([mode isEqual:@"directory"])
                  [weak transferLocalPath:download remotePath:@"/folder" upload:NO requestID:@"directory"];
              else if ([mode isEqual:@"race"])
                  [weak transferLocalPath:download remotePath:@"/hello 世界.txt" upload:NO requestID:@"race"];
              else if ([mode isEqual:@"missing"])
                  [weak listDirectory:@"/missing" requestID:@"missing"];
              else if ([mode isEqual:@"local-collision"])
                  [weak transferLocalPath:local remotePath:@"/hello 世界.txt" upload:NO requestID:@"collision"];
              else if ([mode isEqual:@"remote-collision"])
                  [weak transferLocalPath:local remotePath:@"/hello 世界.txt" upload:YES requestID:@"collision"];
              else if ([mode isEqual:@"empty"])
                  [weak transferLocalPath:download remotePath:@"/empty.txt" upload:NO requestID:@"empty"];
              else
                  [weak transferLocalPath:local remotePath:@"/uploaded 世界.bin" upload:YES requestID:@"upload"];
          } else if ([mode isEqual:@"remote-collision"]) {
              if (phase == 1) {
                  if (!error) {
                      [weak disconnect];
                      return;
                  }
                  phase++;
                  [weak transferLocalPath:download
                               remotePath:@"/hello 世界.txt"
                                   upload:NO
                                requestID:@"verify-original"];
              } else {
                  NSData *original = [NSData dataWithContentsOfFile:download];
                  passed = error == nil && original.length == 2097152;
                  for (NSUInteger i = 0; i < original.length; i++)
                      if (((const uint8_t *)original.bytes)[i] != i % 256) {
                          passed = NO;
                          break;
                      }
                  [weak disconnect];
              }
          } else if ([mode isEqual:@"race"] || [mode isEqual:@"missing"] || [mode isEqual:@"missing-file"] ||
                     [mode isEqual:@"directory"] || [mode isEqual:@"local-collision"]) {
              passed = error != nil && [[NSData dataWithContentsOfFile:local] isEqual:source];
              if ([mode isEqual:@"race"])
                  passed = passed && [[NSData dataWithContentsOfFile:download] isEqual:source];
              if ([mode isEqual:@"missing-file"] || [mode isEqual:@"directory"])
                  passed = passed && ![[NSFileManager defaultManager] fileExistsAtPath:download];
              [weak disconnect];
          } else if ([mode isEqual:@"empty"]) {
              passed = error == nil && [[NSData dataWithContentsOfFile:download] length] == 0 &&
                       [[NSFileManager defaultManager] fileExistsAtPath:download];
              [weak disconnect];
          } else if (phase == 1) {
              if (error || [result[@"bytes"] unsignedLongLongValue] != source.length) {
                  [weak disconnect];
                  return;
              }
              phase++;
              lastBytes = 0;
              [weak transferLocalPath:download remotePath:@"/uploaded 世界.bin" upload:NO requestID:@"download"];
          } else if (filesOnly && phase == 2) {
              if (error || ![[NSData dataWithContentsOfFile:download] isEqual:source]) {
                  [weak disconnect];
                  return;
              }
              phase++;
              lastBytes = 0;
              [weak transferLocalPath:local remotePath:@"/uploaded 世界.bin" upload:YES requestID:@"overwrite"];
          } else if (filesOnly && phase == 3) {
              if (error || [result[@"bytes"] unsignedLongLongValue] != source.length) {
                  [weak disconnect];
                  return;
              }
              phase++;
              lastBytes = 0;
              [weak transferLocalPath:download
                           remotePath:@"/uploaded 世界.bin"
                               upload:NO
                            requestID:@"replace-download"];
          } else {
              passed = error == nil && [[NSData dataWithContentsOfFile:download] isEqual:source] &&
                       (filesOnly ? terminalUnavailable && !input && !resized && conflicts == 2 : input && resized);
              if ([mode isEqual:@"interactive"])
                  passed = passed && auth == 2;
              if ([mode isEqual:@"keyboard-no-shell"])
                  passed = passed && auth == 0;
              [weak disconnect];
          }
        };
        BOOL key = [mode isEqual:@"key"];
        [client connectHost:@"127.0.0.1"
                       port:port
                   username:@"fixture"
                   password:key ? @"fixture-passphrase" : @"fixture-password"
                 privateKey:key ? [NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"user-key.pem"]]
                                : nil
             authentication:key                             ? @"privateKey"
                            : [mode isEqual:@"interactive"] ? @"interactive"
                                                            : @"password"];
        BOOL timeout = dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 40 * NSEC_PER_SEC)) != 0;
        [client disconnect];
        passed = passed && !timeout && trusts == 1;
        if ([mode isEqual:@"no-sftp"])
            passed = passed && input && resized;
        for (NSString *name in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:root error:nil])
            if ([name hasPrefix:@".farcast-transfer-"])
                passed = NO;
        printf("%s SFTP %s\n", passed ? "PASS" : "FAIL", mode.UTF8String);
        return passed ? 0 : 1;
    }
}
