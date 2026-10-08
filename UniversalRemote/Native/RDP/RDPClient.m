#import "RDPClient.h"
#import <Security/Security.h>
// CoreFoundation exports a different REFIID when Clang modules are enabled.
#define REFIID WINPR_REFIID
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmacro-redefined"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#import <freerdp/channels/channels.h>
#import <freerdp/client.h>
#import <freerdp/client/channels.h>
#import <freerdp/client/cliprdr.h>
#import <freerdp/client/disp.h>
#import <freerdp/client/rdpgfx.h>
#import <freerdp/codec/color.h>
#import <freerdp/freerdp.h>
#import <freerdp/gdi/gdi.h>
#import <freerdp/gdi/gfx.h>
#import <winpr/synch.h>
#import <winpr/wlog.h>
#pragma clang diagnostic pop
#import <openssl/err.h>
#import <openssl/pem.h>
#import <openssl/x509.h>
#import <stdatomic.h>
#import <time.h>

typedef struct {
    rdpClientContext common;
    void *owner;
    DispClientContext *display;
    CliprdrClientContext *clipboard;
    NSString *__unsafe_unretained localText;
    double lastFrame;
} URContext;
typedef struct {
    rdpPointer pointer;
    BYTE *pixels;
} URPointer;
@interface URRDPClient () {
    NSLock *_lock;
    NSMutableArray<NSDictionary *> *_events;
    freerdp *_instance;
    atomic_bool _stopped;
}
- (void)runHost:(NSString *)host
           port:(NSInteger)port
       username:(NSString *)username
         domain:(NSString *)domain
       password:(NSString *)password
          width:(NSInteger)width
         height:(NSInteger)height
          scale:(NSInteger)scale
      clipboard:(BOOL)clipboard;
- (void)drainEvents:(URContext *)context;
@end
static URRDPClient *owner(rdpContext *context) { return (__bridge URRDPClient *)((URContext *)context)->owner; }
static BOOL beginPaint(rdpContext *context) {
    if (context->gdi) {
        context->gdi->primary->hdc->hwnd->invalid->null = TRUE;
        context->gdi->primary->hdc->hwnd->ninvalid = 0;
    }
    return TRUE;
}
static BOOL endPaint(rdpContext *context) {
    rdpGdi *gdi = context->gdi;
    if (!gdi || !gdi->primary_buffer || gdi->width <= 0 || gdi->height <= 0)
        return TRUE;
    // Snapshot bytes while FreeRDP owns the buffer; the renderer never reads
    // native mutable memory.
    URRDPClient *client = owner(context);
    if (client.onFrame)
        client.onFrame([NSData dataWithBytes:gdi->primary_buffer length:(NSUInteger)gdi->stride * gdi->height],
                       gdi->width, gdi->height, gdi->stride);
    return TRUE;
}
static BOOL desktopResize(rdpContext *context) {
    return gdi_resize(context->gdi, freerdp_settings_get_uint32(context->settings, FreeRDP_DesktopWidth),
                      freerdp_settings_get_uint32(context->settings, FreeRDP_DesktopHeight));
}
static BOOL pointerNew(rdpContext *context, rdpPointer *pointer) {
    URPointer *p = (URPointer *)pointer;
    if (!pointer->width || !pointer->height || pointer->width > 512 || pointer->height > 512)
        return FALSE;
    p->pixels = calloc(pointer->width * pointer->height, 4);
    return p->pixels && freerdp_image_copy_from_pointer_data(
                            p->pixels, PIXEL_FORMAT_BGRA32, pointer->width * 4, 0, 0, pointer->width, pointer->height,
                            pointer->xorMaskData, pointer->lengthXorMask, pointer->andMaskData, pointer->lengthAndMask,
                            pointer->xorBpp, &context->gdi->palette);
}
static void pointerFree(rdpContext *context, rdpPointer *pointer) { free(((URPointer *)pointer)->pixels); }
static BOOL pointerSet(rdpContext *context, rdpPointer *pointer) {
    URRDPClient *client = owner(context);
    URPointer *p = (URPointer *)pointer;
    if (p->pixels && client.onCursor)
        client.onCursor([NSData dataWithBytes:p->pixels length:pointer->width * pointer->height * 4], pointer->width,
                        pointer->height, pointer->xPos, pointer->yPos);
    return TRUE;
}
static BOOL pointerDefault(rdpContext *context) {
    URRDPClient *client = owner(context);
    if (client.onCursor)
        client.onCursor([NSData data], 0, 0, 0, 0);
    return TRUE;
}
static BOOL pointerNull(rdpContext *context) {
    URRDPClient *client = owner(context);
    if (client.onCursor)
        client.onCursor([NSMutableData dataWithLength:4], 1, 1, 0, 0);
    return TRUE;
}
static UINT advertiseClipboard(CliprdrClientContext *clip) {
    CLIPRDR_FORMAT format = {.formatId = CF_UNICODETEXT, .formatName = NULL};
    CLIPRDR_FORMAT_LIST list = {0};
    list.numFormats = 1;
    list.formats = &format;
    return clip->ClientFormatList(clip, &list);
}
static UINT clipboardReady(CliprdrClientContext *clip, const CLIPRDR_MONITOR_READY *ready) {
    CLIPRDR_GENERAL_CAPABILITY_SET general = {0};
    general.capabilitySetType = CB_CAPSTYPE_GENERAL;
    general.capabilitySetLength = 12;
    general.version = CB_CAPS_VERSION_2;
    general.generalFlags = CB_USE_LONG_FORMAT_NAMES;
    CLIPRDR_CAPABILITIES caps = {0};
    caps.cCapabilitiesSets = 1;
    caps.capabilitySets = (CLIPRDR_CAPABILITY_SET *)&general;
    UINT rc = clip->ClientCapabilities(clip, &caps);
    if (rc)
        return rc;
    return advertiseClipboard(clip);
}
static UINT clipboardFormats(CliprdrClientContext *clip, const CLIPRDR_FORMAT_LIST *list) {
    CLIPRDR_FORMAT_LIST_RESPONSE response = {0};
    response.common.msgFlags = CB_RESPONSE_OK;
    UINT rc = clip->ClientFormatListResponse(clip, &response);
    if (rc)
        return rc;
    for (UINT32 i = 0; i < list->numFormats; i++)
        if (list->formats[i].formatId == CF_UNICODETEXT) {
            CLIPRDR_FORMAT_DATA_REQUEST request = {0};
            request.requestedFormatId = CF_UNICODETEXT;
            return clip->ClientFormatDataRequest(clip, &request);
        }
    return CHANNEL_RC_OK;
}
static UINT clipboardRequest(CliprdrClientContext *clip, const CLIPRDR_FORMAT_DATA_REQUEST *request) {
    URContext *ctx = clip->custom;
    CLIPRDR_FORMAT_DATA_RESPONSE response = {0};
    if (request->requestedFormatId == CF_UNICODETEXT && ctx->localText) {
        NSMutableData *data = [[ctx->localText dataUsingEncoding:NSUTF16LittleEndianStringEncoding] mutableCopy];
        uint16_t zero = 0;
        [data appendBytes:&zero length:2];
        response.common.msgFlags = CB_RESPONSE_OK;
        response.common.dataLen = (UINT32)data.length;
        response.requestedFormatData = data.bytes;
        return clip->ClientFormatDataResponse(clip, &response);
    }
    response.common.msgFlags = CB_RESPONSE_FAIL;
    return clip->ClientFormatDataResponse(clip, &response);
}
static UINT clipboardResponse(CliprdrClientContext *clip, const CLIPRDR_FORMAT_DATA_RESPONSE *response) {
    if (!(response->common.msgFlags & CB_RESPONSE_OK) || response->common.dataLen > 1024 * 1024 ||
        response->common.dataLen % 2)
        return CHANNEL_RC_OK;
    NSString *text = [[NSString alloc] initWithBytes:response->requestedFormatData
                                              length:response->common.dataLen
                                            encoding:NSUTF16LittleEndianStringEncoding];
    if (text) {
        NSRange nul = [text rangeOfString:[NSString stringWithCharacters:(unichar[]){0} length:1]];
        if (nul.location != NSNotFound)
            text = [text substringToIndex:nul.location];
        URRDPClient *client = owner((rdpContext *)clip->custom);
        if (client.onClipboard)
            client.onClipboard(text);
    }
    return CHANNEL_RC_OK;
}
static void channelConnected(void *context, const ChannelConnectedEventArgs *event) {
    URContext *ctx = context;
    if (!strcmp(event->name, "rdpgfx"))
        gdi_graphics_pipeline_init(((rdpContext *)context)->gdi, event->pInterface);
    else if (!strcmp(event->name, "disp"))
        ctx->display = event->pInterface;
    else if (!strcmp(event->name, "cliprdr")) {
        ctx->clipboard = event->pInterface;
        ctx->clipboard->custom = ctx;
        ctx->clipboard->MonitorReady = clipboardReady;
        ctx->clipboard->ServerFormatList = clipboardFormats;
        ctx->clipboard->ServerFormatDataRequest = clipboardRequest;
        ctx->clipboard->ServerFormatDataResponse = clipboardResponse;
    }
}
static void channelDisconnected(void *context, const ChannelDisconnectedEventArgs *event) {
    URContext *ctx = context;
    if (!strcmp(event->name, "rdpgfx"))
        gdi_graphics_pipeline_uninit(((rdpContext *)context)->gdi, event->pInterface);
    else if (!strcmp(event->name, "disp"))
        ctx->display = NULL;
    else if (!strcmp(event->name, "cliprdr"))
        ctx->clipboard = NULL;
}
static BOOL preConnect(freerdp *instance) {
    rdpContext *context = instance->context;
    PubSub_SubscribeChannelConnected(context->pubSub, channelConnected);
    PubSub_SubscribeChannelDisconnected(context->pubSub, channelDisconnected);
    return freerdp_client_load_addins(context->channels, context->settings);
}
static BOOL postConnect(freerdp *instance) {
    if (!gdi_init(instance, PIXEL_FORMAT_BGRA32))
        return FALSE;
    instance->context->update->BeginPaint = beginPaint;
    instance->context->update->EndPaint = endPaint;
    instance->context->update->DesktopResize = desktopResize;
    rdpPointer pointer = {0};
    pointer.size = sizeof(URPointer);
    pointer.New = pointerNew;
    pointer.Free = pointerFree;
    pointer.Set = pointerSet;
    pointer.SetNull = pointerNull;
    pointer.SetDefault = pointerDefault;
    graphics_register_pointer(instance->context->graphics, &pointer);
    return TRUE;
}
static void postDisconnect(freerdp *instance) {
    if (instance->context->gdi)
        gdi_free(instance);
}
static NSString *certificateFingerprint(const char *value, DWORD flags) {
    if (!value)
        return nil;
    if (!(flags & VERIFY_CERT_FLAG_FP_IS_PEM))
        return [NSString stringWithUTF8String:value];
    BIO *bio = BIO_new_mem_buf(value, -1);
    if (!bio)
        return nil;
    X509 *cert = PEM_read_bio_X509(bio, NULL, NULL, NULL);
    BIO_free(bio);
    if (!cert)
        return nil;
    unsigned char digest[EVP_MAX_MD_SIZE];
    unsigned int length = 0;
    BOOL ok = X509_digest(cert, EVP_sha256(), digest, &length);
    X509_free(cert);
    if (!ok)
        return nil;
    return [@"SHA256:" stringByAppendingString:[[[NSData dataWithBytes:digest
                                                                length:length] base64EncodedStringWithOptions:0]
                                                   stringByReplacingOccurrencesOfString:@"="
                                                                             withString:@""]];
}
static int verifyX509(freerdp *instance, const BYTE *pem, size_t length, const char *host, UINT16 port, DWORD flags) {
    BIO *bio = BIO_new_mem_buf(pem, (int)length);
    if (!bio)
        return 0;
    NSMutableArray *certificates = [NSMutableArray new];
    X509 *certificate;
    while ((certificate = PEM_read_bio_X509(bio, NULL, NULL, NULL))) {
        unsigned char *der = NULL;
        int count = i2d_X509(certificate, &der);
        if (count > 0 && der) {
            NSData *data = [NSData dataWithBytes:der length:count];
            SecCertificateRef item = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)data);
            if (item) {
                [certificates addObject:CFBridgingRelease(item)];
            }
        }
        OPENSSL_free(der);
        X509_free(certificate);
    }
    BIO_free(bio);
    ERR_clear_error();
    if (!certificates.count)
        return 0;
    SecPolicyRef policy = SecPolicyCreateSSL(true, (__bridge CFStringRef)[NSString stringWithUTF8String:host]);
    SecTrustRef trust = NULL;
    CFErrorRef error = NULL;
    OSStatus status = SecTrustCreateWithCertificates((__bridge CFArrayRef)certificates, policy, &trust);
    CFRelease(policy);
    BOOL valid = NO;
    if (status == errSecSuccess && trust) {
        SecTrustSetNetworkFetchAllowed(trust, false);
        valid = SecTrustEvaluateWithError(trust, &error);
        CFRelease(trust);
    }
    NSString *reason =
        error ? [CFBridgingRelease(error) localizedDescription] : @"The certificate could not be verified.";
    if (valid)
        return 1;
    NSString *pemString = [[NSString alloc] initWithBytes:pem length:length encoding:NSUTF8StringEncoding];
    NSString *hash = certificateFingerprint(pemString.UTF8String, VERIFY_CERT_FLAG_FP_IS_PEM);
    NSString *name =
        CFBridgingRelease(SecCertificateCopySubjectSummary((__bridge SecCertificateRef)certificates.firstObject));
    URRDPClient *client = owner(instance->context);
    NSString *details = [NSString stringWithFormat:@"RDP TLS certificate\nName: %@\n%@", name ?: @"Unknown", reason];
    return hash && client.onTrust && client.onTrust(hash, details) ? 1 : 0;
}
static BOOL authenticate(freerdp *instance, char **user, char **password, char **domain, rdp_auth_reason reason) {
    return FALSE;
}
static BOOL clientNew(freerdp *instance, rdpContext *context) {
    instance->PreConnect = preConnect;
    instance->PostConnect = postConnect;
    instance->PostDisconnect = postDisconnect;
    instance->VerifyX509Certificate = verifyX509;
    instance->AuthenticateEx = authenticate;
    return TRUE;
}
@implementation URRDPClient {
    NSString *_clipboardText;
}
- (instancetype)init {
    if ((self = [super init])) {
        _lock = [NSLock new];
        _events = [NSMutableArray new];
        atomic_init(&_stopped, false);
    }
    return self;
}
- (void)status:(NSString *)state message:(NSString *)message {
    if (self.onStatus)
        self.onStatus(state, message);
}
- (void)connectHost:(NSString *)host
               port:(NSInteger)port
           username:(NSString *)username
             domain:(NSString *)domain
           password:(NSString *)password
              width:(NSInteger)width
             height:(NSInteger)height
              scale:(NSInteger)scale
          clipboard:(BOOL)clipboard {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      @autoreleasepool {
          [self runHost:host
                   port:port
               username:username
                 domain:domain
               password:password
                  width:width
                 height:height
                  scale:scale
              clipboard:clipboard];
      }
    });
}
- (void)runHost:(NSString *)host
           port:(NSInteger)port
       username:(NSString *)username
         domain:(NSString *)domain
       password:(NSString *)password
          width:(NSInteger)width
         height:(NSInteger)height
          scale:(NSInteger)scale
      clipboard:(BOOL)clipboard {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      freerdp_register_addin_provider(freerdp_channels_load_static_addin_entry, 0);
      WLog_SetLogLevel(WLog_GetRoot(), WLOG_ERROR);
    });
    [self status:@"connecting" message:@"Connecting to remote desktop…"];
    RDP_CLIENT_ENTRY_POINTS ep = {0};
    ep.Size = sizeof(ep);
    ep.Version = RDP_CLIENT_INTERFACE_VERSION;
    ep.ContextSize = sizeof(URContext);
    ep.ClientNew = clientNew;
    rdpContext *context = freerdp_client_context_new(&ep);
    if (!context) {
        [self status:@"failed" message:@"Could not initialize RDP."];
        return;
    }
    ((URContext *)context)->owner = (__bridge void *)self;
    rdpSettings *s = context->settings;
    NSString *configRoot = NSProcessInfo.processInfo.environment[@"UNIVERSALREMOTE_RDP_CONFIG"];
    if (!configRoot)
        configRoot =
            [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject
                stringByAppendingPathComponent:@"UniversalRemote/RDP"];
    [[NSFileManager defaultManager] createDirectoryAtPath:configRoot
                              withIntermediateDirectories:YES
                                               attributes:@{NSFilePosixPermissions : @0700}
                                                    error:NULL];
    freerdp_settings_set_string(s, FreeRDP_ConfigPath, configRoot.UTF8String);
    freerdp_settings_set_string(s, FreeRDP_ServerHostname, host.UTF8String);
    freerdp_settings_set_uint32(s, FreeRDP_ServerPort, (UINT32)port);
    freerdp_settings_set_string(s, FreeRDP_Username, username.UTF8String);
    freerdp_settings_set_string(s, FreeRDP_Password, password.UTF8String);
    freerdp_settings_set_string(s, FreeRDP_Domain, domain.UTF8String);
    freerdp_settings_set_uint32(s, FreeRDP_DesktopWidth, (UINT32)width);
    freerdp_settings_set_uint32(s, FreeRDP_DesktopHeight, (UINT32)height);
    freerdp_settings_set_uint32(s, FreeRDP_DesktopScaleFactor, (UINT32)scale);
    freerdp_settings_set_uint32(s, FreeRDP_DeviceScaleFactor, scale >= 200 ? 180 : 100);
    freerdp_settings_set_uint32(s, FreeRDP_ColorDepth, 32);
    freerdp_settings_set_uint32(s, FreeRDP_KeyboardLayout, 0x00000409);
    freerdp_settings_set_bool(s, FreeRDP_SoftwareGdi, TRUE);
    freerdp_settings_set_bool(s, FreeRDP_NlaSecurity, TRUE);
    freerdp_settings_set_bool(s, FreeRDP_TlsSecurity, TRUE);
    freerdp_settings_set_bool(s, FreeRDP_RdpSecurity, FALSE);
    freerdp_settings_set_bool(s, FreeRDP_ExternalCertificateManagement, TRUE);
    freerdp_settings_set_bool(s, FreeRDP_IgnoreCertificate, FALSE);
    freerdp_settings_set_bool(s, FreeRDP_CertificateCallbackPreferPEM, TRUE);
    freerdp_settings_set_bool(s, FreeRDP_RedirectClipboard, clipboard);
    freerdp_settings_set_bool(s, FreeRDP_SupportDynamicChannels, TRUE);
    freerdp_settings_set_bool(s, FreeRDP_SupportDisplayControl, TRUE);
    freerdp_settings_set_bool(s, FreeRDP_DynamicResolutionUpdate, TRUE);
    // The supplied real server completed authentication but never started the
    // negotiated GFX channel. Standard software bitmap updates deliver its desktop.
    // Keep display control available independently of graphics-pipeline negotiation.
    freerdp_settings_set_bool(s, FreeRDP_SupportGraphicsPipeline, FALSE);
    freerdp_settings_set_bool(s, FreeRDP_RemoteFxCodec, TRUE);
    freerdp_settings_set_bool(s, FreeRDP_NSCodec, TRUE);
    freerdp_settings_set_bool(s, FreeRDP_GfxH264, FALSE);
    freerdp_settings_set_bool(s, FreeRDP_GfxProgressive, FALSE);
    freerdp_settings_set_uint32(s, FreeRDP_TcpConnectTimeout, 20000);
    freerdp_settings_set_uint32(s, FreeRDP_TcpAckTimeout, 20000);
    freerdp_settings_set_uint32(s, FreeRDP_ThreadingFlags, THREADING_FLAGS_DISABLE_THREADS);
    [_lock lock];
    _instance = context->instance;
    BOOL stopped = atomic_load(&_stopped);
    [_lock unlock];
    BOOL connected = !stopped && freerdp_connect(context->instance);
    NSString *failure = nil;
    if (connected) {
        [self status:@"connected" message:@"RDP connected"];
        while (!atomic_load(&_stopped) && !freerdp_shall_disconnect_context(context)) {
            @autoreleasepool {
                [self drainEvents:(URContext *)context];
                HANDLE handles[64];
                DWORD count = freerdp_get_event_handles(context, handles, 64);
                if (!count || WaitForMultipleObjects(count, handles, FALSE, 16) == WAIT_FAILED ||
                    !freerdp_check_event_handles(context))
                    break;
            }
        }
    }
    UINT32 error = freerdp_get_last_error(context);
    if (!atomic_load(&_stopped) && (!connected || error)) {
        failure = [NSString stringWithFormat:@"RDP connection failed (%s). Check credentials, "
                                             @"server settings, and network access.",
                                             freerdp_get_last_error_name(error) ?: "unknown error"];
    }
    [_lock lock];
    _instance = NULL;
    [_lock unlock];
    freerdp_disconnect(context->instance);
    freerdp_client_context_free(context);
    _clipboardText = nil;
    if (failure)
        [self status:@"failed" message:failure];
    else
        [self status:@"disconnected" message:@"RDP disconnected"];
}
- (void)enqueue:(NSDictionary *)event {
    [_lock lock];
    if (_events.count < 4096)
        [_events addObject:event];
    [_lock unlock];
}
- (void)drainEvents:(URContext *)ctx {
    [_lock lock];
    NSArray *events = [_events copy];
    [_events removeAllObjects];
    [_lock unlock];
    rdpContext *context = (rdpContext *)ctx;
    for (NSDictionary *event in events) {
        NSString *type = event[@"type"];
        if ([type isEqualToString:@"key"])
            freerdp_input_send_keyboard_event_ex(
                context->input, [event[@"pressed"] boolValue], [event[@"repeat"] boolValue],
                [event[@"code"] unsignedIntValue] | ([event[@"extended"] boolValue] ? 0x100 : 0));
        else if ([type isEqualToString:@"unicode"])
            freerdp_input_send_unicode_keyboard_event(context->input,
                                                      [event[@"pressed"] boolValue] ? 0 : KBD_FLAGS_RELEASE,
                                                      [event[@"code"] unsignedShortValue]);
        else if ([type isEqualToString:@"pointer"])
            freerdp_input_send_mouse_event(context->input, [event[@"flags"] unsignedShortValue],
                                           [event[@"x"] unsignedShortValue], [event[@"y"] unsignedShortValue]);
        else if ([type isEqualToString:@"resize"] && ctx->display) {
            DISPLAY_CONTROL_MONITOR_LAYOUT layout = {0};
            layout.Flags = DISPLAY_CONTROL_MONITOR_PRIMARY;
            layout.Width = [event[@"width"] unsignedIntValue];
            layout.Height = [event[@"height"] unsignedIntValue];
            layout.PhysicalWidth = MAX(10, layout.Width * 254 / 960);
            layout.PhysicalHeight = MAX(10, layout.Height * 254 / 960);
            layout.DesktopScaleFactor = [event[@"scale"] unsignedIntValue];
            layout.DeviceScaleFactor = layout.DesktopScaleFactor >= 200 ? 180 : 100;
            ctx->display->SendMonitorLayout(ctx->display, 1, &layout);
        } else if ([type isEqualToString:@"clipboard"] && ctx->clipboard) {
            _clipboardText = event[@"text"];
            ctx->localText = _clipboardText;
            advertiseClipboard(ctx->clipboard);
        }
    }
}
- (void)resizeWidth:(NSInteger)width height:(NSInteger)height scale:(NSInteger)scale {
    [self enqueue:@{
        @"type" : @"resize",
        @"width" : @(MAX(200, MIN(8192, width / 2 * 2))),
        @"height" : @(MAX(200, MIN(8192, height))),
        @"scale" : @(scale)
    }];
}
- (void)sendScanCode:(NSInteger)code pressed:(BOOL)pressed extended:(BOOL)extended {
    [self enqueue:@{@"type" : @"key", @"code" : @(code), @"pressed" : @(pressed), @"extended" : @(extended)}];
}
- (void)sendUnicode:(NSInteger)code pressed:(BOOL)pressed {
    [self enqueue:@{@"type" : @"unicode", @"code" : @(code), @"pressed" : @(pressed)}];
}
- (void)sendPointerFlags:(NSInteger)flags x:(NSInteger)x y:(NSInteger)y {
    [self enqueue:@{@"type" : @"pointer", @"flags" : @(flags), @"x" : @(x), @"y" : @(y)}];
}
- (void)setClipboardText:(NSString *)text {
    if (text.length <= 512 * 1024)
        [self enqueue:@{@"type" : @"clipboard", @"text" : text}];
}
- (void)sendControlAltDelete {
    [self sendScanCode:0x1D pressed:YES extended:NO];
    [self sendScanCode:0x38 pressed:YES extended:NO];
    [self sendScanCode:0x53 pressed:YES extended:YES];
    [self sendScanCode:0x53 pressed:NO extended:YES];
    [self sendScanCode:0x38 pressed:NO extended:NO];
    [self sendScanCode:0x1D pressed:NO extended:NO];
}
- (void)disconnect {
    atomic_store(&_stopped, true);
    [_lock lock];
    if (_instance)
        freerdp_abort_connect_context(_instance->context);
    [_lock unlock];
}
@end
