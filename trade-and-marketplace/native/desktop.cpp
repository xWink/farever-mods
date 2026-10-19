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

#ifndef _WIN64
#error Trade and Marketplace requires Windows x64
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

#include "../../shared/native/fareverly_account.h"
#include "../../shared/native/fareverly_browser.h"

#define EXPORT extern "C" __declspec(dllexport)
EXPORT void *hlp_secure_random(const char **s) { *s="PBi_i"; return reinterpret_cast<void *>(&secure_random); }
EXPORT void *hlp_write_credential(const char **s) { *s="PBiBi_i"; return reinterpret_cast<void *>(&write_credential); }
EXPORT void *hlp_open_url(const char **s) { *s="PBi_i"; return reinterpret_cast<void *>(&open_fareverly_url); }
