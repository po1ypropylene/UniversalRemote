#import <Foundation/Foundation.h>
typedef struct S_IRP IRP;
typedef struct rdp_settings rdpSettings;
@interface URRDPDrive : NSObject
- (instancetype)initWithURL:(NSURL *)url readOnly:(BOOL)readOnly;
- (void)processIRP:(IRP *)irp;
- (void)shutdown;
@end
@interface URRDPDriveManager : NSObject
+ (void)registerProvider;
- (BOOL)configure:(NSArray<NSDictionary *> *)folders settings:(rdpSettings *)settings;
- (void)close;
@end
