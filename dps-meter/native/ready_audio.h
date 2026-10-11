#pragma once
#include <xaudio2.h>
#include <cmath>
#include <new>
#include <vector>

// A private output voice: never changes the game's mixer or Windows device volume.
// All entry points are called on the game thread. XAudio2 owns the audio thread.
class ReadyAudio {
    HMODULE library = nullptr;
    IXAudio2 *engine = nullptr;
    IXAudio2MasteringVoice *master = nullptr;
    IXAudio2SourceVoice *source = nullptr;
    std::vector<uint8_t> pcm;
    bool uninitializeCom = false;

public:
    HRESULT prepare() {
        if (engine) return S_OK;
        // Match the desktop plugin's shell/clipboard apartment. If the game
        // already chose another apartment, preserve it.
        HRESULT result = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
        if (FAILED(result) && result != RPC_E_CHANGED_MODE) return result;
        uninitializeCom = SUCCEEDED(result);
        library = LoadLibraryExW(L"xaudio2_9.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
        if (!library) library = LoadLibraryExW(L"xaudio2_8.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
        if (!library) { result = HRESULT_FROM_WIN32(GetLastError()); clear(); return result; }
        using CreateAudio = HRESULT (WINAPI *)(IXAudio2 **, UINT32, XAUDIO2_PROCESSOR);
        FARPROC address = GetProcAddress(library, "XAudio2Create");
        if (!address) { clear(); return HRESULT_FROM_WIN32(ERROR_PROC_NOT_FOUND); }
        CreateAudio create = nullptr;
        static_assert(sizeof(create) == sizeof(address), "Function pointer width");
        std::memcpy(&create, &address, sizeof(create));
        // Processor1 is also the 2.8 default; avoid old headers' ANY_PROCESSOR
        // constant creating a worker on every CPU when using 2.9.
        result = create(&engine, 0, Processor1);
        if (SUCCEEDED(result)) result = engine->CreateMasteringVoice(&master);
        if (FAILED(result)) clear();
        return result;
    }

    void stop() {
        // DestroyVoice waits until the audio thread no longer reads the buffer.
        if (source) { source->DestroyVoice(); source = nullptr; }
        pcm.clear();
    }

    void clear() {
        stop();
        if (master) { master->DestroyVoice(); master = nullptr; }
        if (engine) { engine->Release(); engine = nullptr; }
        if (library) { FreeLibrary(library); library = nullptr; }
        if (uninitializeCom) { CoUninitialize(); uninitializeCom = false; }
    }

    HRESULT play(const uint8_t *bytes, int length, int rate, int channels, double volume) {
        // Only bounded, interleaved signed PCM16. Validate before touching state.
        if (!bytes || length <= 0 || length > 8 * 1024 * 1024 || rate < 8000 || rate > 192000
            || channels < 1 || channels > 2 || length % (channels * 2) != 0
            || !std::isfinite(volume) || volume < 0 || volume > 1) return E_INVALIDARG;
        HRESULT result = prepare();
        if (FAILED(result)) return result;
        stop();
        try { pcm.assign(bytes, bytes + length); }
        catch (const std::bad_alloc &) { return E_OUTOFMEMORY; }
        WAVEFORMATEX format = {};
        format.wFormatTag = WAVE_FORMAT_PCM;
        format.nChannels = static_cast<WORD>(channels);
        format.nSamplesPerSec = static_cast<DWORD>(rate);
        format.wBitsPerSample = 16;
        format.nBlockAlign = static_cast<WORD>(channels * 2);
        format.nAvgBytesPerSec = format.nSamplesPerSec * format.nBlockAlign;
        result = engine->CreateSourceVoice(&source, &format);
        XAUDIO2_BUFFER buffer = {};
        buffer.Flags = XAUDIO2_END_OF_STREAM;
        buffer.AudioBytes = static_cast<UINT32>(pcm.size());
        buffer.pAudioData = pcm.data();
        if (SUCCEEDED(result)) result = source->SetVolume(static_cast<float>(volume));
        if (SUCCEEDED(result)) result = source->SubmitSourceBuffer(&buffer);
        if (SUCCEEDED(result)) result = source->Start(0);
        if (FAILED(result)) clear();
        return result;
    }

    // 1 while queued/playing, 0 once complete, negative HRESULT on failure.
    int update(double volume) {
        if (!std::isfinite(volume) || volume < 0 || volume > 1) return static_cast<int>(E_INVALIDARG);
        if (!source) return 0;
        XAUDIO2_VOICE_STATE state = {};
        source->GetState(&state, XAUDIO2_VOICE_NOSAMPLESPLAYED);
        if (!state.BuffersQueued) { stop(); return 0; }
        HRESULT result = source->SetVolume(static_cast<float>(volume));
        if (FAILED(result)) { clear(); return static_cast<int>(result); }
        return 1;
    }
};

// Explicit lifecycle avoids destroying audio voices under the DLL loader lock.
static ReadyAudio *readyAudio = nullptr;
static int prepare_audio() {
    if (!readyAudio) readyAudio = new (std::nothrow) ReadyAudio();
    return readyAudio ? static_cast<int>(readyAudio->prepare()) : static_cast<int>(E_OUTOFMEMORY);
}
static int play_audio(const uint8_t *bytes, int length, int rate, int channels, double volume) {
    if (!readyAudio) readyAudio = new (std::nothrow) ReadyAudio();
    return readyAudio ? static_cast<int>(readyAudio->play(bytes, length, rate, channels, volume)) : static_cast<int>(E_OUTOFMEMORY);
}
static int update_audio(double volume) { return readyAudio ? readyAudio->update(volume) : 0; }
static int stop_audio() { if (readyAudio) readyAudio->stop(); return 0; }
static int dispose_audio() {
    if (readyAudio) { readyAudio->clear(); delete readyAudio; readyAudio = nullptr; }
    return 0;
}
