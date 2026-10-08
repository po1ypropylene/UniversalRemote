#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface URRDPClient : NSObject
@property(nonatomic, copy) void (^onStatus)(NSString *state, NSString *message);
@property(nonatomic, copy) void (^onFrame)(NSData *pixels, NSInteger width, NSInteger height, NSInteger stride);
@property(nonatomic, copy) BOOL (^onTrust)(NSString *fingerprint, NSString *details);
@property(nonatomic, copy) void (^onClipboard)(NSString *text);
@property(nonatomic, copy) void (^onCursor)
    (NSData *pixels, NSInteger width, NSInteger height, NSInteger hotX, NSInteger hotY);
- (void)connectHost:(NSString *)host
               port:(NSInteger)port
           username:(NSString *)username
             domain:(NSString *)domain
           password:(NSString *)password
              width:(NSInteger)width
             height:(NSInteger)height
              scale:(NSInteger)scale
          clipboard:(BOOL)clipboard;
- (void)resizeWidth:(NSInteger)width height:(NSInteger)height scale:(NSInteger)scale;
- (void)sendScanCode:(NSInteger)code pressed:(BOOL)pressed extended:(BOOL)extended;
- (void)sendUnicode:(NSInteger)code pressed:(BOOL)pressed;
- (void)sendPointerFlags:(NSInteger)flags x:(NSInteger)x y:(NSInteger)y;
- (void)setClipboardText:(NSString *)text;
- (void)sendControlAltDelete;
- (void)disconnect;
@end
NS_ASSUME_NONNULL_END
