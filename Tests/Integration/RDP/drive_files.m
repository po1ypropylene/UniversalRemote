#import "RDPDrive.h"
#define REFIID WINPR_REFIID
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#import <freerdp/channels/rdpdr.h>
#pragma clang diagnostic pop
#import <fcntl.h>
#import <unistd.h>
static NTSTATUS result;
static NSData *output;
static NSUInteger checks;
static void check(BOOL value, const char *message) {
    if (!value) {
        fprintf(stderr, "FAIL redirected folder: %s\n", message);
        exit(1);
    }
    checks++;
}
static UINT completed(IRP *irp) {
    result = irp->IoStatus;
    output = [NSData dataWithBytes:Stream_Buffer(irp->output) length:Stream_GetPosition(irp->output)];
    return 0;
}
static void invoke(URRDPDrive *drive, UINT32 major, UINT32 file, UINT32 minor, wStream *input) {
    Stream_SealLength(input);
    Stream_SetPosition(input, 0);
    IRP irp = {0};
    irp.MajorFunction = major;
    irp.MinorFunction = minor;
    irp.FileId = file;
    irp.input = input;
    irp.output = Stream_New(NULL, 128);
    irp.Complete = completed;
    [drive processIRP:&irp];
    Stream_Free(irp.output, TRUE);
    Stream_Free(input, TRUE);
}
static UINT32 create(URRDPDrive *drive, NSString *path, UINT32 access, UINT32 disposition, UINT32 options,
                     UINT32 share) {
    wStream *s = Stream_New(NULL, 17000);
    NSData *name = [path dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
    Stream_Write_UINT32(s, access);
    Stream_Write_UINT64(s, 0);
    Stream_Write_UINT32(s, FILE_ATTRIBUTE_NORMAL);
    Stream_Write_UINT32(s, share);
    Stream_Write_UINT32(s, disposition);
    Stream_Write_UINT32(s, options);
    Stream_Write_UINT32(s, (UINT32)name.length);
    Stream_Write(s, name.bytes, name.length);
    invoke(drive, IRP_MJ_CREATE, 0, 0, s);
    if (result != STATUS_SUCCESS)
        return 0;
    uint32_t identifier;
    memcpy(&identifier, output.bytes, 4);
    return CFSwapInt32LittleToHost(identifier);
}
static void closeFile(URRDPDrive *drive, UINT32 identifier) {
    invoke(drive, IRP_MJ_CLOSE, identifier, 0, Stream_New(NULL, 1));
}
static void readFile(URRDPDrive *drive, UINT32 identifier, uint64_t offset, UINT32 length) {
    wStream *s = Stream_New(NULL, 32);
    Stream_Write_UINT32(s, length);
    Stream_Write_UINT64(s, offset);
    Stream_Zero(s, 20);
    invoke(drive, IRP_MJ_READ, identifier, 0, s);
}
static void writeFile(URRDPDrive *drive, UINT32 identifier, uint64_t offset, NSData *bytes) {
    wStream *s = Stream_New(NULL, bytes.length + 32);
    Stream_Write_UINT32(s, (UINT32)bytes.length);
    Stream_Write_UINT64(s, offset);
    Stream_Zero(s, 20);
    Stream_Write(s, bytes.bytes, bytes.length);
    invoke(drive, IRP_MJ_WRITE, identifier, 0, s);
}
static void setInfo(URRDPDrive *drive, UINT32 identifier, UINT32 kind, NSData *bytes) {
    wStream *s = Stream_New(NULL, bytes.length + 32);
    Stream_Write_UINT32(s, kind);
    Stream_Write_UINT32(s, (UINT32)bytes.length);
    Stream_Zero(s, 24);
    Stream_Write(s, bytes.bytes, bytes.length);
    invoke(drive, IRP_MJ_SET_INFORMATION, identifier, 0, s);
}
static NSData *renameData(NSString *path, BOOL replace) {
    NSMutableData *data = [NSMutableData dataWithBytes:(BYTE[]){replace, 0} length:2];
    NSData *name = [path dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
    uint32_t length = CFSwapInt32HostToLittle((uint32_t)name.length);
    [data appendBytes:&length length:4];
    [data appendData:name];
    return data;
}
int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc != 2)
            return 2;
        NSURL *root = [NSURL fileURLWithPath:@(argv[1])];
        NSFileManager *fm = NSFileManager.defaultManager;
        NSURL *export = [root URLByAppendingPathComponent:@"export"];
        NSURL *outside = [root URLByAppendingPathComponent:@"outside"];
        [fm createDirectoryAtURL:export withIntermediateDirectories:YES attributes:nil error:NULL];
        [fm createDirectoryAtURL:outside withIntermediateDirectories:YES attributes:nil error:NULL];
        NSData *payload = [@"Synthetic bytes 繁體😀" dataUsingEncoding:NSUTF8StringEncoding];
        NSURL *original = [export URLByAppendingPathComponent:@"original.bin"];
        [payload writeToURL:original atomically:YES];
        [payload writeToURL:[outside URLByAppendingPathComponent:@"protected.bin"] atomically:YES];
        symlink(outside.fileSystemRepresentation,
                [export URLByAppendingPathComponent:@"escape"].fileSystemRepresentation);
        symlink(original.fileSystemRepresentation,
                [export URLByAppendingPathComponent:@"link"].fileSystemRepresentation);
        URRDPDrive *rw = [[URRDPDrive alloc] initWithURL:export readOnly:NO];
        UINT32 fullAccess = GENERIC_READ | GENERIC_WRITE | DELETE;
        UINT32 shares = FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE;
        UINT32 h = create(rw, @"\\new.bin", fullAccess, FILE_CREATE, FILE_NON_DIRECTORY_FILE, shares);
        check(h > 0, "create writable file");
        writeFile(rw, h, 0, payload);
        check(result == STATUS_SUCCESS, "write");
        readFile(rw, h, 0, (UINT32)payload.length);
        check(result == STATUS_SUCCESS && [[output subdataWithRange:NSMakeRange(4, output.length - 4)] isEqual:payload],
              "read byte equality");
        writeFile(rw, h, (1ULL << 32) + 9, [@"large" dataUsingEncoding:NSUTF8StringEncoding]);
        check(result == STATUS_SUCCESS, "64-bit write");
        readFile(rw, h, (1ULL << 32) + 9, 5);
        check(result == STATUS_SUCCESS && output.length == 9, "64-bit read");
        uint64_t size = CFSwapInt64HostToLittle(payload.length);
        setInfo(rw, h, FileEndOfFileInformation, [NSData dataWithBytes:&size length:8]);
        check(result == STATUS_SUCCESS, "truncate");
        for (NSNumber *kind in
             @[ @(FileNameInformation), @(FileAllInformation), @(FileBasicInformation), @(FileStandardInformation) ]) {
            wStream *query = Stream_New(NULL, 4);
            Stream_Write_UINT32(query, kind.unsignedIntValue);
            invoke(rw, IRP_MJ_QUERY_INFORMATION, h, 0, query);
            check(result == STATUS_SUCCESS && output.length > 8, "query name/basic/standard/all metadata");
        }
        setInfo(rw, h, FileRenameInformation, renameData(@"\\renamed.bin", NO));
        check(result == STATUS_SUCCESS, "rename");
        check([fm fileExistsAtPath:[export URLByAppendingPathComponent:@"renamed.bin"].path], "rename destination");
        setInfo(rw, h, FileRenameInformation, renameData(@"\\escape\\outside.bin", YES));
        check(result == STATUS_ACCESS_DENIED, "rename intermediate symlink denied");
        setInfo(rw, h, FileDispositionInformation, [NSData dataWithBytes:(BYTE[]){1} length:1]);
        check(result == STATUS_SUCCESS, "delete pending");
        closeFile(rw, h);
        check(result == STATUS_SUCCESS &&
                  ![fm fileExistsAtPath:[export URLByAppendingPathComponent:@"renamed.bin"].path],
              "delete on close");
        for (NSString *bad in @[
                 @"\\..\\outside\\protected.bin", @"/absolute", @"C:\\absolute", @"\\\\network\\share",
                 @"escape/protected.bin", @"link"
             ]) {
            check(create(rw, bad, fullAccess, FILE_OPEN_IF, 0, shares) == 0, "traversal/link open refused");
        }
        h = create(rw, @"original.bin", GENERIC_READ, FILE_OPEN, 0, 0);
        check(h > 0, "exclusive open");
        check(create(rw, @"original.bin", GENERIC_WRITE, FILE_OPEN, 0, shares) == 0 &&
                  result == STATUS_SHARING_VIOLATION,
              "share conflict");
        closeFile(rw, h);
        UINT32 directory = create(rw, @"\\", GENERIC_READ, FILE_OPEN, FILE_DIRECTORY_FILE, shares);
        check(directory > 0, "root directory open");
        NSMutableSet *listed = [NSMutableSet new];
        for (NSUInteger i = 0; i < 10; i++) {
            wStream *s = Stream_New(NULL, 40);
            NSData *pattern = [@"\\*" dataUsingEncoding:NSUTF16LittleEndianStringEncoding];
            Stream_Write_UINT32(s, FileNamesInformation);
            Stream_Write_UINT8(s, i == 0);
            Stream_Write_UINT32(s, (UINT32)pattern.length);
            Stream_Zero(s, 23);
            Stream_Write(s, pattern.bytes, pattern.length);
            invoke(rw, IRP_MJ_DIRECTORY_CONTROL, directory, IRP_MN_QUERY_DIRECTORY, s);
            if (result == STATUS_NO_MORE_FILES)
                break;
            check(result == STATUS_SUCCESS && output.length >= 16, "directory page");
            NSString *name = [[NSString alloc] initWithBytes:(BYTE *)output.bytes + 16
                                                      length:output.length - 16
                                                    encoding:NSUTF16LittleEndianStringEncoding];
            [listed addObject:name];
        }
        check([listed containsObject:@"original.bin"] && ![listed containsObject:@"escape"] &&
                  ![listed containsObject:@"link"],
              "listing excludes links");
        closeFile(rw, directory);
        UINT32 rootHandle = create(rw, @"\\", GENERIC_READ | DELETE, FILE_OPEN, FILE_DIRECTORY_FILE, shares);
        check(rootHandle == 0 && result == STATUS_ACCESS_DENIED, "root mutation access refused");
        [fm createDirectoryAtURL:[export URLByAppendingPathComponent:@"nonempty"]
            withIntermediateDirectories:YES
                             attributes:nil
                                  error:NULL];
        [payload writeToURL:[export URLByAppendingPathComponent:@"nonempty/file"] atomically:YES];
        UINT32 nonempty = create(rw, @"nonempty", GENERIC_READ | DELETE, FILE_OPEN, FILE_DIRECTORY_FILE, shares);
        setInfo(rw, nonempty, FileDispositionInformation, [NSData dataWithBytes:(BYTE[]){1} length:1]);
        check(result == STATUS_DIRECTORY_NOT_EMPTY, "nonempty directory deletion rejected when marked");
        closeFile(rw, nonempty);
        invoke(rw, IRP_MJ_CREATE, 0, 0, Stream_New(NULL, 1));
        check(result == STATUS_INVALID_PARAMETER, "truncated request rejected");
        URRDPDrive *ro = [[URRDPDrive alloc] initWithURL:export readOnly:YES];
        UINT32 reader = create(ro, @"original.bin", GENERIC_READ, FILE_OPEN, 0, shares);
        check(reader > 0, "read-only open/read allowed");
        readFile(ro, reader, 0, (UINT32)payload.length);
        check(result == STATUS_SUCCESS, "read-only data read");
        for (UINT32 access = 0; access < 7; access++) {
            UINT32 masks[] = {GENERIC_WRITE,    GENERIC_ALL,   DELETE,   FILE_WRITE_ATTRIBUTES,
                              FILE_APPEND_DATA, FILE_WRITE_EA, WRITE_DAC};
            check(create(ro, @"original.bin", masks[access], FILE_OPEN, 0, shares) == 0 &&
                      result == STATUS_ACCESS_DENIED,
                  "read-only mutation access denied");
        }
        for (UINT32 disposition = 0; disposition <= FILE_OVERWRITE_IF; disposition++) {
            if (disposition == FILE_OPEN)
                continue;
            check(create(ro, @"original.bin", GENERIC_READ, disposition, 0, shares) == 0 &&
                      result == STATUS_ACCESS_DENIED,
                  "read-only create/replacement denied before mutation");
        }
        writeFile(ro, reader, 0, [@"change" dataUsingEncoding:NSUTF8StringEncoding]);
        check(result == STATUS_ACCESS_DENIED, "read-only write denied");
        for (NSNumber *kind in @[
                 @(FileBasicInformation), @(FileEndOfFileInformation), @(FileAllocationInformation),
                 @(FileRenameInformation), @(FileDispositionInformation)
             ]) {
            setInfo(ro, reader, kind.unsignedIntValue, [NSMutableData dataWithLength:40]);
            check(result == STATUS_ACCESS_DENIED, "read-only metadata/delete/rename/truncate denied");
        }
        invoke(ro, IRP_MJ_DEVICE_CONTROL, reader, 0, Stream_New(NULL, 32));
        check(result == STATUS_ACCESS_DENIED, "read-only controls denied");
        check([[NSData dataWithContentsOfURL:original] isEqual:payload], "read-only original unchanged");
        closeFile(ro, reader);
        [ro shutdown];
        invoke(ro, IRP_MJ_READ, reader, 0, Stream_New(NULL, 32));
        check(result == STATUS_CANCELLED, "disconnected device refuses work");
        h = create(rw, @"cancel.bin", fullAccess, FILE_CREATE, FILE_DELETE_ON_CLOSE, shares);
        check(h > 0, "pending delete setup");
        [rw shutdown];
        check([fm fileExistsAtPath:[export URLByAppendingPathComponent:@"cancel.bin"].path],
              "disconnect does not execute pending deletion");
        check([[NSData dataWithContentsOfURL:[outside URLByAppendingPathComponent:@"protected.bin"]] isEqual:payload],
              "outside root unchanged");
        printf("PASS %lu redirected-folder filesystem checks\n", (unsigned long)checks);
    }
    return 0;
}
