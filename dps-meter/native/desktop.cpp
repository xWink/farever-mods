/* Windows x64 shell/clipboard bridge. No helper process or game-private ABI.
 * https://learn.microsoft.com/windows/win32/api/shobjidl_core/nf-shobjidl_core-ifileoperation-setoperationflags
 * https://learn.microsoft.com/windows/win32/api/shobjidl_core/nf-shobjidl_core-ifileoperationprogresssink-predeleteitem
 * https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-setclipboarddata
 */
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#define _WIN32_WINNT 0x0602
#include <windows.h>
#include <shellapi.h>
#include <shobjidl.h>
#include <cstdint>
#include <cstring>
#include <string>
#include "image_buffer.h"
#include "ready_audio.h"

#ifndef _WIN64
#error DPS Meter requires Windows x64
#endif

static int win_error() { DWORD error = GetLastError(); return error ? static_cast<int>(error) : ERROR_GEN_FAILURE; }
static bool path_from_utf8(const char *bytes, int length, std::wstring &path) {
    if (!bytes || length <= 0 || length > 131068 || std::memchr(bytes, 0, length)) return false;
    int count = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, bytes, length, nullptr, 0);
    if (count <= 0 || count > 32766) return false;
    path.resize(count);
    if (!MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, bytes, length, &path[0], count)) return false;
    // Require absolute filesystem paths, never shell expressions or URLs.
    return (path.size() >= 3 && path[1] == L':' && (path[2] == L'\\' || path[2] == L'/'))
        || (path.size() >= 3 && path[0] == L'\\' && path[1] == L'\\');
}

#include "fareverly_account.h"
#include "fareverly_browser.h"

static int open_folder(const char *bytes, int length) {
    std::wstring path;
    if (!path_from_utf8(bytes, length, path)) return ERROR_INVALID_PARAMETER;
    DWORD attributes = GetFileAttributesW(path.c_str());
    if (attributes == INVALID_FILE_ATTRIBUTES) return win_error();
    if (!(attributes & FILE_ATTRIBUTE_DIRECTORY)) return ERROR_DIRECTORY;
    auto result = reinterpret_cast<INT_PTR>(ShellExecuteW(nullptr, L"open", path.c_str(), nullptr, nullptr, SW_SHOWNORMAL));
    return result > 32 ? 0 : result ? static_cast<int>(result) : ERROR_GEN_FAILURE;
}

class RecycleSink final : public IFileOperationProgressSink {
    LONG refs = 1;
public:
    bool recycled = false;
    HRESULT itemResult = E_FAIL;
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID id, void **out) override {
        if (!out) return E_POINTER;
        *out = nullptr;
        if (IsEqualIID(id, IID_IUnknown) || IsEqualIID(id, IID_IFileOperationProgressSink)) {
            *out = static_cast<IFileOperationProgressSink *>(this); AddRef(); return S_OK;
        }
        return E_NOINTERFACE;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return InterlockedIncrement(&refs); }
    // Stack lifetime spans the whole synchronous operation; COM only borrows it.
    ULONG STDMETHODCALLTYPE Release() override { return InterlockedDecrement(&refs); }
    HRESULT STDMETHODCALLTYPE StartOperations() override { return S_OK; }
    HRESULT STDMETHODCALLTYPE FinishOperations(HRESULT) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE PreRenameItem(DWORD, IShellItem *, LPCWSTR) override { return E_ABORT; }
    HRESULT STDMETHODCALLTYPE PostRenameItem(DWORD, IShellItem *, LPCWSTR, HRESULT, IShellItem *) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE PreMoveItem(DWORD, IShellItem *, IShellItem *, LPCWSTR) override { return E_ABORT; }
    HRESULT STDMETHODCALLTYPE PostMoveItem(DWORD, IShellItem *, IShellItem *, LPCWSTR, HRESULT, IShellItem *) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE PreCopyItem(DWORD, IShellItem *, IShellItem *, LPCWSTR) override { return E_ABORT; }
    HRESULT STDMETHODCALLTYPE PostCopyItem(DWORD, IShellItem *, IShellItem *, LPCWSTR, HRESULT, IShellItem *) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE PreDeleteItem(DWORD flags, IShellItem *) override {
        // Refuse a permanent-delete fallback (e.g. an unsupported volume).
        return (flags & TSF_DELETE_RECYCLE_IF_POSSIBLE) ? S_OK : E_ABORT;
    }
    HRESULT STDMETHODCALLTYPE PostDeleteItem(DWORD, IShellItem *, HRESULT result, IShellItem *newItem) override {
        itemResult = result; recycled = SUCCEEDED(result) && newItem != nullptr; return S_OK;
    }
    HRESULT STDMETHODCALLTYPE PreNewItem(DWORD, IShellItem *, LPCWSTR) override { return E_ABORT; }
    HRESULT STDMETHODCALLTYPE PostNewItem(DWORD, IShellItem *, LPCWSTR, LPCWSTR, DWORD, HRESULT, IShellItem *) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE UpdateProgress(UINT, UINT) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE ResetTimer() override { return S_OK; }
    HRESULT STDMETHODCALLTYPE PauseTimer() override { return S_OK; }
    HRESULT STDMETHODCALLTYPE ResumeTimer() override { return S_OK; }
};

static int recycle_file(const char *bytes, int length) {
    std::wstring path;
    if (!path_from_utf8(bytes, length, path)) return ERROR_INVALID_PARAMETER;
    DWORD attributes = GetFileAttributesW(path.c_str());
    if (attributes == INVALID_FILE_ATTRIBUTES) return win_error();
    if (attributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)) return ERROR_ACCESS_DENIED;
    HRESULT init = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
    if (FAILED(init)) return static_cast<int>(init);
    IFileOperation *operation = nullptr;
    IShellItem *item = nullptr;
    RecycleSink sink;
    HRESULT result = CoCreateInstance(CLSID_FileOperation, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&operation));
    if (SUCCEEDED(result)) result = operation->SetOperationFlags(FOFX_RECYCLEONDELETE | FOFX_ADDUNDORECORD
        | FOFX_EARLYFAILURE | FOF_NOERRORUI | FOF_NOCONFIRMATION | FOF_SILENT | FOF_NO_CONNECTED_ELEMENTS);
    if (SUCCEEDED(result)) result = SHCreateItemFromParsingName(path.c_str(), nullptr, IID_PPV_ARGS(&item));
    if (SUCCEEDED(result)) result = operation->DeleteItem(item, &sink);
    if (SUCCEEDED(result)) result = operation->PerformOperations();
    BOOL aborted = TRUE;
    if (SUCCEEDED(result)) result = operation->GetAnyOperationsAborted(&aborted);
    if (SUCCEEDED(result) && (aborted || !sink.recycled)) result = FAILED(sink.itemResult) ? sink.itemResult : E_ABORT;
    if (item) item->Release();
    if (operation) operation->Release();
    CoUninitialize();
    return SUCCEEDED(result) ? 0 : static_cast<int>(result);
}

static int copy_image(const uint8_t *pixels, int length, int width, int height) {
    size_t pixelBytes = dps_image_bytes(width, height, length);
    if (!pixels || !pixelBytes) return ERROR_INVALID_PARAMETER;
    HGLOBAL memory = GlobalAlloc(GMEM_MOVEABLE | GMEM_ZEROINIT, sizeof(BITMAPINFOHEADER) + pixelBytes);
    if (!memory) return ERROR_NOT_ENOUGH_MEMORY;
    auto *header = static_cast<BITMAPINFOHEADER *>(GlobalLock(memory));
    if (!header) { int error = win_error(); GlobalFree(memory); return error; }
    header->biSize = sizeof(BITMAPINFOHEADER); header->biWidth = width; header->biHeight = height;
    header->biPlanes = 1; header->biBitCount = 32; header->biCompression = BI_RGB;
    header->biSizeImage = static_cast<DWORD>(pixelBytes);
    dps_copy_bottom_up(reinterpret_cast<uint8_t *>(header + 1), pixels, width, height);
    GlobalUnlock(memory);
    // A non-NULL owner is required after EmptyClipboard. This message-only
    // window never appears on screen and belongs to the calling game thread.
    HWND owner = CreateWindowExW(0, L"STATIC", L"DPS Meter clipboard", 0, 0, 0, 0, 0, HWND_MESSAGE, nullptr, nullptr, nullptr);
    if (!owner) { int error = win_error(); GlobalFree(memory); return error; }
    int error = 0;
    if (!OpenClipboard(owner)) error = win_error();
    else {
        if (!EmptyClipboard() || !SetClipboardData(CF_DIB, memory)) error = win_error();
        else memory = nullptr; // The system owns the allocation from this point.
        CloseClipboard();
    }
    DestroyWindow(owner);
    if (memory) GlobalFree(memory);
    return error;
}

// HashLink DEFINE_PRIM ABI: B = raw bytes, i = i32. No libhl dependency.
#define EXPORT extern "C" __declspec(dllexport)
EXPORT void *hlp_open_folder(const char **signature) { *signature = "PBi_i"; return reinterpret_cast<void *>(&open_folder); }
EXPORT void *hlp_recycle_file(const char **signature) { *signature = "PBi_i"; return reinterpret_cast<void *>(&recycle_file); }
EXPORT void *hlp_copy_image(const char **signature) { *signature = "PBiii_i"; return reinterpret_cast<void *>(&copy_image); }
EXPORT void *hlp_prepare_audio(const char **signature) { *signature = "P_i"; return reinterpret_cast<void *>(&prepare_audio); }
EXPORT void *hlp_play_audio(const char **signature) { *signature = "PBiiid_i"; return reinterpret_cast<void *>(&play_audio); }
EXPORT void *hlp_update_audio(const char **signature) { *signature = "Pd_i"; return reinterpret_cast<void *>(&update_audio); }
EXPORT void *hlp_stop_audio(const char **signature) { *signature = "P_i"; return reinterpret_cast<void *>(&stop_audio); }
EXPORT void *hlp_dispose_audio(const char **signature) { *signature = "P_i"; return reinterpret_cast<void *>(&dispose_audio); }

EXPORT void *hlp_secure_random(const char **signature) { *signature = "PBi_i"; return reinterpret_cast<void *>(&secure_random); }
EXPORT void *hlp_write_credential(const char **signature) { *signature = "PBiBi_i"; return reinterpret_cast<void *>(&write_credential); }
EXPORT void *hlp_open_url(const char **signature) { *signature = "PBi_i"; return reinterpret_cast<void *>(&open_fareverly_url); }
