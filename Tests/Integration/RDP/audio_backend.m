#import <Foundation/Foundation.h>
#define REFIID WINPR_REFIID
#import <freerdp/addin.h>
#import <freerdp/channels/channels.h>
#import <freerdp/client/channels.h>
#import <freerdp/client/rdpsnd.h>

static rdpsndDevicePlugin *output;
static void registerOutput(rdpsndPlugin *plugin, rdpsndDevicePlugin *device) { output = device; }

int main(void) {
    @autoreleasepool {
        freerdp_register_addin_provider(freerdp_channels_load_static_addin_entry, 0);
        PFREERDP_RDPSND_DEVICE_ENTRY entry = (PFREERDP_RDPSND_DEVICE_ENTRY)freerdp_load_channel_addin_entry(
            "rdpsnd", "mac", NULL, FREERDP_ADDIN_CHANNEL_STATIC | FREERDP_ADDIN_CHANNEL_ENTRYEX);
        FREERDP_RDPSND_DEVICE_ENTRY_POINTS points = {0};
        points.pRegisterRdpsndDevice = registerOutput;
        if (!entry || entry(&points) != CHANNEL_RC_OK || !output) {
            puts("FAIL RDP Mac audio backend registration");
            return 1;
        }
        AUDIO_FORMAT format = {0};
        format.wFormatTag = WAVE_FORMAT_PCM;
        format.nChannels = 2;
        format.nSamplesPerSec = 48000;
        format.wBitsPerSample = 16;
        format.nBlockAlign = 4;
        format.nAvgBytesPerSec = 192000;
        if (!output->FormatSupported(output, &format) || !output->Open(output, &format, 100)) {
            output->Free(output);
            puts("FAIL RDP Mac audio output initialization");
            return 1;
        }
        // Exercise the real output device with silence, without recording any audio.
        BYTE silence[19200] = {0};
        output->Play(output, silence, sizeof(silence));
        [NSThread sleepForTimeInterval:0.3];
        output->Close(output);
        output->Free(output);
        puts("PASS RDP Mac audio backend: registration, PCM output, shutdown");
        return 0;
    }
}
