#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface URSSHClient : NSObject
@property(nonatomic, copy) void (^onStatus)(NSString *state, NSString *message);
@property(nonatomic, copy) void (^onData)(NSData *data);
@property(nonatomic, copy) BOOL (^onTrust)(NSString *fingerprint, NSString *details);
@property(nonatomic, copy) NSString *_Nullable (^onPrompt)(NSString *prompt, BOOL echo);
- (void)connectHost:(NSString *)host
               port:(NSInteger)port
           username:(NSString *)username
           password:(NSString *)password
         privateKey:(nullable NSData *)key
     authentication:(NSString *)authentication;
// Results and progress are delivered on the SSH worker, never the UI thread.
@property(nonatomic, copy, nullable) void (^onFiles)
    (NSString *requestID, NSDictionary *result, NSString *_Nullable error);
@property(nonatomic, copy, nullable) void (^onFileProgress)
    (NSString *requestID, unsigned long long bytes, unsigned long long total);
- (void)listDirectory:(NSString *)path requestID:(NSString *)requestID;
- (void)transferLocalPath:(NSString *)localPath
               remotePath:(NSString *)remotePath
                   upload:(BOOL)upload
                requestID:(NSString *)requestID;
// kind: uploadTree, downloadTree, copyRemote, mkdir, rename, removeTree.
- (void)fileOperation:(NSString *)kind
               source:(NSString *)source
          destination:(NSString *)destination
                 move:(BOOL)move
            requestID:(NSString *)requestID;
- (void)sendData:(NSData *)data;
- (void)resizeColumns:(NSInteger)columns rows:(NSInteger)rows;
- (void)cancelFiles;
- (void)disconnect;
@end
NS_ASSUME_NONNULL_END
