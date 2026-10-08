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
- (void)sendData:(NSData *)data;
- (void)resizeColumns:(NSInteger)columns rows:(NSInteger)rows;
- (void)disconnect;
@end
NS_ASSUME_NONNULL_END
