// Synthetic clipboard peer for the disposable FreeRDP sample server only.
// Echoes protocol text and relays synthetic file ranges; it never accesses the host pasteboard.
#include <freerdp/server/cliprdr.h>

typedef struct {
    BYTE *bytes;
    UINT32 length;
    UINT32 sourceFormat;
    BOOL files;
} FCFixtureClipboard;

static UINT fc_fixture_formats(CliprdrServerContext *clip, const CLIPRDR_FORMAT_LIST *list) {
    CLIPRDR_FORMAT_LIST_RESPONSE ack = {0};
    ack.common.msgFlags = CB_RESPONSE_OK;
    UINT rc = clip->ServerFormatListResponse(clip, &ack);
    if (rc)
        return rc;
    FCFixtureClipboard *state = clip->custom;
    for (UINT32 i = 0; i < list->numFormats; ++i) {
        if (list->formats[i].formatName && !strcmp(list->formats[i].formatName, "FileGroupDescriptorW")) {
            state->files = TRUE;
            state->sourceFormat = list->formats[i].formatId;
            CLIPRDR_FORMAT_DATA_REQUEST request = {0};
            request.requestedFormatId = state->sourceFormat;
            return clip->ServerFormatDataRequest(clip, &request);
        }
        if (list->formats[i].formatId == CF_UNICODETEXT) {
            state->files = FALSE;
            state->sourceFormat = CF_UNICODETEXT;
            CLIPRDR_FORMAT_DATA_REQUEST request = {0};
            request.requestedFormatId = CF_UNICODETEXT;
            return clip->ServerFormatDataRequest(clip, &request);
        }
    }
    return CHANNEL_RC_OK;
}

static UINT fc_fixture_data(CliprdrServerContext *clip, const CLIPRDR_FORMAT_DATA_RESPONSE *response) {
    if (!(response->common.msgFlags & CB_RESPONSE_OK) || !response->requestedFormatData ||
        response->common.dataLen > 1024 * 1024)
        return ERROR_INVALID_DATA;
    FCFixtureClipboard *state = clip->custom;
    free(state->bytes);
    state->length = response->common.dataLen;
    state->bytes = malloc(state->length);
    if (!state->bytes)
        return CHANNEL_RC_NO_MEMORY;
    memcpy(state->bytes, response->requestedFormatData, state->length);
    CLIPRDR_FORMAT format = {.formatId = state->files ? 0xC111 : CF_UNICODETEXT,
                             .formatName = state->files ? "FileGroupDescriptorW" : NULL};
    CLIPRDR_FORMAT_LIST list = {0};
    list.numFormats = 1;
    list.formats = &format;
    return clip->ServerFormatList(clip, &list);
}

static UINT fc_fixture_request(CliprdrServerContext *clip, const CLIPRDR_FORMAT_DATA_REQUEST *request) {
    FCFixtureClipboard *state = clip->custom;
    CLIPRDR_FORMAT_DATA_RESPONSE response = {0};
    response.common.msgFlags = CB_RESPONSE_FAIL;
    if (request->requestedFormatId == (state->files ? 0xC111 : CF_UNICODETEXT) && state->bytes) {
        response.common.msgFlags = CB_RESPONSE_OK;
        response.common.dataLen = state->length;
        response.requestedFormatData = state->bytes;
    }
    return clip->ServerFormatDataResponse(clip, &response);
}

static UINT fc_fixture_file_request(CliprdrServerContext *clip, const CLIPRDR_FILE_CONTENTS_REQUEST *request) {
    return clip->ServerFileContentsRequest(clip, request);
}
static UINT fc_fixture_file_response(CliprdrServerContext *clip, const CLIPRDR_FILE_CONTENTS_RESPONSE *response) {
    return clip->ServerFileContentsResponse(clip, response);
}
static UINT fc_fixture_lock(CliprdrServerContext *clip, const CLIPRDR_LOCK_CLIPBOARD_DATA *lock) {
    return clip->ServerLockClipboardData(clip, lock);
}
static UINT fc_fixture_unlock(CliprdrServerContext *clip, const CLIPRDR_UNLOCK_CLIPBOARD_DATA *unlock) {
    return clip->ServerUnlockClipboardData(clip, unlock);
}

static BOOL fc_fixture_clipboard_start(testPeerContext *context) {
    if (!WTSVirtualChannelManagerIsChannelJoined(context->vcm, "cliprdr"))
        return TRUE;
    CliprdrServerContext *clip = cliprdr_server_context_new(context->vcm);
    if (!clip)
        return FALSE;
    context->fc_clipboard = clip;
    clip->custom = calloc(1, sizeof(FCFixtureClipboard));
    if (!clip->custom)
        return FALSE;
    clip->rdpcontext = &context->_p;
    clip->useLongFormatNames = TRUE;
    clip->streamFileClipEnabled = TRUE;
    clip->fileClipNoFilePaths = TRUE;
    clip->canLockClipData = TRUE;
    clip->hasHugeFileSupport = TRUE;
    clip->ClientFileContentsRequest = fc_fixture_file_request;
    clip->ClientFileContentsResponse = fc_fixture_file_response;
    clip->ClientLockClipboardData = fc_fixture_lock;
    clip->ClientUnlockClipboardData = fc_fixture_unlock;
    clip->autoInitializationSequence = TRUE;
    clip->ClientFormatList = fc_fixture_formats;
    clip->ClientFormatDataResponse = fc_fixture_data;
    clip->ClientFormatDataRequest = fc_fixture_request;
    return clip->Start(clip) == CHANNEL_RC_OK;
}

static void fc_fixture_clipboard_stop(testPeerContext *context) {
    CliprdrServerContext *clip = context->fc_clipboard;
    if (!clip)
        return;
    clip->Stop(clip);
    FCFixtureClipboard *state = clip->custom;
    if (state) {
        free(state->bytes);
        free(state);
    }
    cliprdr_server_context_free(clip);
    context->fc_clipboard = NULL;
}
