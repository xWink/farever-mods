#pragma once
#include <regex>

// Never run cmd/start/PowerShell. Copy out of GC memory before entering a
// blocking Windows call, so a slow browser cannot stop the game's GC threads.
static int open_fareverly_url(const char *bytes, int length) {
    if (!bytes || length <= 0 || length > 2048 || std::memchr(bytes, 0, length)) return ERROR_INVALID_PARAMETER;
    const std::string url(bytes, length);
    const std::regex allowed(R"(^https://fareverly\.com/(analyze(#desktop=v1\.[0-9]{1,5}\.[a-f0-9]{64})?|contact|connect/[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12})$)");
    if (!std::regex_match(url, allowed)) return ERROR_INVALID_PARAMETER;
    const std::wstring wide(url.begin(), url.end()); // Validated ASCII only.
    using Blocking = void (*)(bool);
    auto library = GetModuleHandleW(L"libhl.dll");
    auto address = library ? GetProcAddress(library, "hl_blocking") : nullptr;
    Blocking blocking = nullptr;
    static_assert(sizeof(blocking) == sizeof(address), "Windows function pointer size");
    std::memcpy(&blocking, &address, sizeof(blocking));
    if (blocking) blocking(true);
    HRESULT init = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);
    auto result = reinterpret_cast<INT_PTR>(ShellExecuteW(nullptr, L"open", wide.c_str(), nullptr, nullptr, SW_SHOWNORMAL));
    if (SUCCEEDED(init)) CoUninitialize();
    if (blocking) blocking(false);
    return result > 32 ? 0 : result ? static_cast<int>(result) : ERROR_GEN_FAILURE;
}
