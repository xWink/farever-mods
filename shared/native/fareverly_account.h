#pragma once
#include <bcrypt.h>
#include <aclapi.h>
#include <vector>

static int secure_random(unsigned char *bytes, int length) {
    if (!bytes || length != 32) return ERROR_INVALID_PARAMETER;
    return BCryptGenRandom(nullptr, bytes, 32, BCRYPT_USE_SYSTEM_PREFERRED_RNG) == 0 ? 0 : ERROR_GEN_FAILURE;
}

// Temporary file starts owner-only; replacement is atomic and preserves that ACL.
static int write_credential(const char *pathBytes, int pathLength, const unsigned char *bytes, int length) {
    std::wstring path;
    if (!path_from_utf8(pathBytes, pathLength, path) || !bytes || length < 2 || length > 4096) return ERROR_INVALID_PARAMETER;
    const auto attributes = GetFileAttributesW(path.c_str());
    if (attributes != INVALID_FILE_ATTRIBUTES && (attributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT))) return ERROR_ACCESS_DENIED;
    HANDLE token = nullptr;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) return win_error();
    DWORD required = 0;
    GetTokenInformation(token, TokenUser, nullptr, 0, &required);
    std::vector<unsigned char> user(required);
    if (!required || !GetTokenInformation(token, TokenUser, user.data(), required, &required)) { int e = win_error(); CloseHandle(token); return e; }
    CloseHandle(token);
    EXPLICIT_ACCESSW access{};
    access.grfAccessPermissions = GENERIC_ALL;
    access.grfAccessMode = SET_ACCESS;
    access.grfInheritance = NO_INHERITANCE;
    access.Trustee.TrusteeForm = TRUSTEE_IS_SID;
    access.Trustee.TrusteeType = TRUSTEE_IS_USER;
    access.Trustee.ptstrName = static_cast<LPWSTR>(reinterpret_cast<TOKEN_USER *>(user.data())->User.Sid);
    PACL acl = nullptr;
    DWORD error = SetEntriesInAclW(1, &access, nullptr, &acl);
    if (error) return static_cast<int>(error);
    SECURITY_DESCRIPTOR descriptor;
    InitializeSecurityDescriptor(&descriptor, SECURITY_DESCRIPTOR_REVISION);
    SetSecurityDescriptorDacl(&descriptor, TRUE, acl, FALSE);
    SetSecurityDescriptorControl(&descriptor, SE_DACL_PROTECTED, SE_DACL_PROTECTED);
    SECURITY_ATTRIBUTES security{sizeof(SECURITY_ATTRIBUTES), &descriptor, FALSE};
    unsigned char nonce[32];
    if (secure_random(nonce, 32)) { LocalFree(acl); return ERROR_GEN_FAILURE; }
    std::wstring temporary = path + L".";
    for (unsigned char c : nonce) { temporary += L"0123456789abcdef"[c >> 4]; temporary += L"0123456789abcdef"[c & 15]; }
    temporary += L".tmp";
    SecureZeroMemory(nonce, sizeof(nonce));
    HANDLE file = CreateFileW(temporary.c_str(), GENERIC_WRITE, 0, &security, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
    LocalFree(acl);
    if (file == INVALID_HANDLE_VALUE) return win_error();
    DWORD written = 0;
    error = (!WriteFile(file, bytes, length, &written, nullptr) || written != static_cast<DWORD>(length) || !FlushFileBuffers(file)) ? win_error() : 0;
    CloseHandle(file);
    if (!error && !MoveFileExW(temporary.c_str(), path.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) error = win_error();
    if (error) DeleteFileW(temporary.c_str());
    return static_cast<int>(error);
}
