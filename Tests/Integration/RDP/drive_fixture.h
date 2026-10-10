// Synthetic filesystem redirector. All requests target owned loopback-test roots.
#include <freerdp/server/rdpdr.h>
typedef struct {
    UINT32 device, file;
    BOOL readOnly;
    int phase;
    testPeerContext *peer;
} URDriveFixture;
static void ur_drive_finish(RdpdrServerContext *c) {
    URDriveFixture *state = c->data;
    CliprdrServerContext *clip = state->peer->ur_clipboard;
    if (!clip)
        return;
    URFixtureClipboard *clipboard = clip->custom;
    const char *text = "Synthetic redirected drive passed";
    size_t length = strlen(text);
    free(clipboard->bytes);
    clipboard->length = (UINT32)((length + 1) * 2);
    clipboard->bytes = calloc(1, clipboard->length);
    clipboard->files = FALSE;
    for (size_t i = 0; i < length; i++)
        clipboard->bytes[i * 2] = (BYTE)text[i];
    CLIPRDR_FORMAT format = {.formatId = CF_UNICODETEXT};
    CLIPRDR_FORMAT_LIST list = {0};
    list.numFormats = 1;
    list.formats = &format;
    clip->ServerFormatList(clip, &list);
}
static void ur_drive_closed(RdpdrServerContext *c, void *data, UINT32 status) {
    if (!status)
        ur_drive_finish(c);
}
static void ur_drive_read(RdpdrServerContext *c, void *data, UINT32 status, const char *bytes, UINT32 length) {
    URDriveFixture *state = c->data;
    const char *expected = state->readOnly ? "initial fixture" : "written fixture";
    if (!status && length == strlen(expected) && !memcmp(bytes, expected, length))
        c->DriveCloseFile(c, state, state->device, state->file);
}
static void ur_drive_written(RdpdrServerContext *c, void *data, UINT32 status, UINT32 length) {
    URDriveFixture *state = c->data;
    if (!status && length == 15)
        c->DriveReadFile(c, state, state->device, state->file, 15, 0);
}
static void ur_drive_opened(RdpdrServerContext *c, void *data, UINT32 status, UINT32 device, UINT32 file) {
    URDriveFixture *state = c->data;
    if (state->readOnly && state->phase == 0) {
        if (status != STATUS_ACCESS_DENIED)
            return;
        state->phase = 1;
        c->DriveOpenFile(c, state, state->device, "\\probe.bin", GENERIC_READ, FILE_OPEN);
        return;
    }
    if (status)
        return;
    state->file = file;
    if (state->readOnly)
        c->DriveReadFile(c, state, device, file, 15, 0);
    else
        c->DriveWriteFile(c, state, device, file, "written fixture", 15, 0);
}
static UINT ur_drive_created(RdpdrServerContext *c, const RdpdrDevice *device) {
    URDriveFixture *state = c->data;
    state->device = device->DeviceId;
    const BYTE readonlyName[] = {'R', 0, 'e', 0, 'a', 0, 'd', 0, 'O', 0, 'n', 0, 'l', 0, 'y', 0};
    state->readOnly = device->DeviceDataLength >= sizeof(readonlyName) &&
                      !memcmp(device->DeviceData, readonlyName, sizeof(readonlyName));
    return c->DriveOpenFile(c, state, state->device, "\\probe.bin", GENERIC_WRITE | GENERIC_READ, FILE_OPEN);
}
static BOOL ur_fixture_drive_start(testPeerContext *peer) {
    if (!WTSVirtualChannelManagerIsChannelJoined(peer->vcm, "rdpdr"))
        return TRUE;
    RdpdrServerContext *c = rdpdr_server_context_new(peer->vcm);
    if (!c)
        return FALSE;
    peer->ur_drive = c;
    c->rdpcontext = &peer->_p;
    c->supported = RDPDR_DTYP_FILESYSTEM;
    URDriveFixture *state = calloc(1, sizeof(*state));
    if (!state)
        return FALSE;
    state->peer = peer;
    c->data = state;
    c->OnDriveCreate = ur_drive_created;
    c->OnDriveOpenFileComplete = ur_drive_opened;
    c->OnDriveReadFileComplete = ur_drive_read;
    c->OnDriveWriteFileComplete = ur_drive_written;
    c->OnDriveCloseFileComplete = ur_drive_closed;
    return c->Start(c) == 0;
}
static void ur_fixture_drive_stop(testPeerContext *peer) {
    RdpdrServerContext *c = peer->ur_drive;
    if (!c)
        return;
    c->Stop(c);
    free(c->data);
    rdpdr_server_context_free(c);
    peer->ur_drive = NULL;
}
