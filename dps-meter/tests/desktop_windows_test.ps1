param([Parameter(Mandatory=$true)][string]$Plugin)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DesktopTest {
    [DllImport("kernel32", CharSet=CharSet.Unicode, SetLastError=true)] public static extern IntPtr LoadLibrary(string path);
    [DllImport("kernel32", CharSet=CharSet.Ansi)] public static extern IntPtr GetProcAddress(IntPtr module, string name);
    [DllImport("user32", SetLastError=true)] public static extern bool OpenClipboard(IntPtr owner);
    [DllImport("user32")] public static extern bool CloseClipboard();
    [DllImport("user32")] public static extern IntPtr GetClipboardData(uint format);
    [DllImport("kernel32")] public static extern IntPtr GlobalLock(IntPtr memory);
    [DllImport("kernel32")] public static extern bool GlobalUnlock(IntPtr memory);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate IntPtr Primitive(out IntPtr signature);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate int PathAction(byte[] path, int length);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate int CopyImage(byte[] bytes, int length, int width, int height);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate int AudioAction();
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate int WriteCredential(byte[] path, int pathLength, byte[] content, int length);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate int PlayAudio(byte[] bytes, int length, int rate, int channels, double volume);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] public delegate int UpdateAudio(double volume);
    public static Delegate Bind(IntPtr module, string name, string expected, Type type) {
        IntPtr address = GetProcAddress(module, name);
        if (address == IntPtr.Zero) throw new Exception("Missing export: " + name);
        var registration = (Primitive)Marshal.GetDelegateForFunctionPointer(address, typeof(Primitive));
        IntPtr signature;
        IntPtr function = registration(out signature);
        if (Marshal.PtrToStringAnsi(signature) != expected) throw new Exception("Wrong HL signature: " + name);
        return Marshal.GetDelegateForFunctionPointer(function, type);
    }
    public static void CheckClipboard() {
        if (!OpenClipboard(IntPtr.Zero)) throw new Exception("Cannot read clipboard");
        try {
            IntPtr handle = GetClipboardData(8); // CF_DIB
            IntPtr data = GlobalLock(handle);
            if (data == IntPtr.Zero) throw new Exception("Missing clipboard DIB");
            try {
                if (Marshal.ReadInt32(data, 0) != 40 || Marshal.ReadInt32(data, 4) != 2 || Marshal.ReadInt32(data, 8) != 2)
                    throw new Exception("Wrong DIB dimensions");
                if (Marshal.ReadByte(data, 40) != 255 || Marshal.ReadByte(data, 42) != 0 || Marshal.ReadByte(data, 43) != 0)
                    throw new Exception("Bottom blue pixel was not preserved");
                if (Marshal.ReadByte(data, 48) != 0 || Marshal.ReadByte(data, 50) != 255)
                    throw new Exception("Top red pixel was not preserved");
            } finally { GlobalUnlock(handle); }
        } finally { CloseClipboard(); }
    }
}
'@
$module = [DesktopTest]::LoadLibrary((Resolve-Path -LiteralPath $Plugin).Path)
if ($module -eq [IntPtr]::Zero) { throw "Could not load desktop plugin: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())" }
$copy = [DesktopTest]::Bind($module, 'hlp_copy_image', 'PBiii_i', [DesktopTest+CopyImage])
$recycle = [DesktopTest]::Bind($module, 'hlp_recycle_file', 'PBi_i', [DesktopTest+PathAction])
$open = [DesktopTest]::Bind($module, 'hlp_open_folder', 'PBi_i', [DesktopTest+PathAction])
$prepareAudio = [DesktopTest]::Bind($module, 'hlp_prepare_audio', 'P_i', [DesktopTest+AudioAction])
$playAudio = [DesktopTest]::Bind($module, 'hlp_play_audio', 'PBiiid_i', [DesktopTest+PlayAudio])
$updateAudio = [DesktopTest]::Bind($module, 'hlp_update_audio', 'Pd_i', [DesktopTest+UpdateAudio])
$stopAudio = [DesktopTest]::Bind($module, 'hlp_stop_audio', 'P_i', [DesktopTest+AudioAction])
$disposeAudio = [DesktopTest]::Bind($module, 'hlp_dispose_audio', 'P_i', [DesktopTest+AudioAction])
$openUrl = [DesktopTest]::Bind($module, 'hlp_open_url', 'PBi_i', [DesktopTest+PathAction])
foreach ($badUrl in @('https://example.invalid/', 'https://fareverly.com.evil/analyze', 'https://fareverly.com/analyze&calc', 'file:///C:/Windows/System32/cmd.exe')) {
    $urlBytes = [Text.Encoding]::UTF8.GetBytes($badUrl)
    if ($openUrl.Invoke($urlBytes, $urlBytes.Length) -ne 87) { throw 'Unsafe browser URL accepted' }
}
# Offline checks: no Steam requests or production combat reports.
$random = [DesktopTest]::Bind($module, 'hlp_secure_random', 'PBi_i', [DesktopTest+PathAction])
$writeCredential = [DesktopTest]::Bind($module, 'hlp_write_credential', 'PBiBi_i', [DesktopTest+WriteCredential])
[byte[]]$entropyA = New-Object byte[] 32
[byte[]]$entropyB = New-Object byte[] 32
if ($random.Invoke($entropyA, 31) -eq 0) { throw 'Incorrect entropy size accepted' }
if ($random.Invoke($entropyA, 32) -ne 0 -or $random.Invoke($entropyB, 32) -ne 0) { throw 'Windows CSPRNG failed' }
if ([Convert]::ToBase64String($entropyA) -eq [Convert]::ToBase64String($entropyB)) { throw 'Random outputs repeated' }
$credentialFolder = Join-Path ([IO.Path]::GetTempPath()) ('fareverly-local-test-' + [Guid]::NewGuid())
[IO.Directory]::CreateDirectory($credentialFolder) | Out-Null
try {
    $credentialPath = Join-Path $credentialFolder 'account.json'
    $pathBytes = [Text.Encoding]::UTF8.GetBytes($credentialPath)
    $first = [Text.Encoding]::UTF8.GetBytes('{"fixture":"first"}')
    $second = [Text.Encoding]::UTF8.GetBytes('{"fixture":"replacement"}')
    if ($writeCredential.Invoke($pathBytes, $pathBytes.Length, $first, $first.Length) -ne 0) { throw 'Secure initial write failed' }
    if ($writeCredential.Invoke($pathBytes, $pathBytes.Length, $second, $second.Length) -ne 0) { throw 'Atomic credential replacement failed' }
    if ([IO.File]::ReadAllText($credentialPath) -ne '{"fixture":"replacement"}') { throw 'Wrong contents after replacement' }
    if ($writeCredential.Invoke($pathBytes, $pathBytes.Length, $first, 0) -eq 0) { throw 'Invalid write accepted' }
    if ([IO.File]::ReadAllText($credentialPath) -ne '{"fixture":"replacement"}') { throw 'Rejected write destroyed the old credential' }
    $acl = Get-Acl -LiteralPath $credentialPath
    if (-not $acl.AreAccessRulesProtected) { throw 'Credential ACL inherits access' }
    $owner = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
    if ($rules.Count -ne 1 -or $rules[0].IdentityReference.Value -ne $owner) { throw 'Credential access is not restricted to the current OS user' }
    if (@(Get-ChildItem -LiteralPath $credentialFolder).Count -ne 1) { throw 'Temporary credential files remain' }
    Write-Output 'Windows credentials: CSPRNG, atomic replacement, owner-only ACL, and failure preservation passed'
} finally { Remove-Item -LiteralPath $credentialFolder -Recurse -Force }
# Hosted runners may have no endpoint; never mistake a no-op backend for success.
[byte[]]$pcm = New-Object byte[] 96000 # 0.5 seconds, stereo PCM16 at 48 kHz
if ($playAudio.Invoke($pcm, 95999, 48000, 2, 0.5) -eq 0) { throw 'Unaligned PCM buffer was accepted' }
if ($playAudio.Invoke($pcm, 0, 48000, 2, 0.5) -eq 0) { throw 'Empty PCM buffer was accepted' }
if ($playAudio.Invoke($pcm, $pcm.Length, 48000, 3, 0.5) -eq 0) { throw 'Unsupported channel count was accepted' }
if ($playAudio.Invoke($pcm, $pcm.Length, 48000, 2, [double]::NaN) -eq 0) { throw 'Invalid audio gain was accepted' }
$audioResult = $prepareAudio.Invoke()
try {
    if ($audioResult -eq 0) {
        if ($playAudio.Invoke($pcm, $pcm.Length, 48000, 2, 0.5) -ne 0) { throw 'Could not submit PCM to native audio device' }
        if ($updateAudio.Invoke(0.2) -ne 1) { throw 'Native voice did not start asynchronously' }
        if ($updateAudio.Invoke(0.0) -ne 1) { throw 'Live audio mute failed' }
        $deadline = [DateTime]::UtcNow.AddSeconds(5)
        do {
            Start-Sleep -Milliseconds 50
            $playing = $updateAudio.Invoke(0.5)
            if ($playing -lt 0) { throw "Native audio update failed: $playing" }
        } while ($playing -eq 1 -and [DateTime]::UtcNow -lt $deadline)
        if ($playing -ne 0) { throw 'Native audio never consumed its samples' }
        if ($playAudio.Invoke($pcm, $pcm.Length, 48000, 2, 0.5) -ne 0) { throw 'Native audio replay failed' }
        if ($stopAudio.Invoke() -ne 0 -or $updateAudio.Invoke(1.0) -ne 0) { throw 'Native audio stop did not clear playback' }
        Write-Output 'Windows audio: PCM submission, consumption, live volume, replay, and stop passed'
    } elseif ($audioResult -eq -2147023728 -or $audioResult -eq -2004287484 -or $audioResult -eq -2003435516) {
        # ERROR_NOT_FOUND, AUDCLNT_E_DEVICE_INVALIDATED, XAUDIO2_E_DEVICE_INVALIDATED.
        Write-Output "Windows audio: no usable endpoint on this runner ($audioResult); ABI and input validation passed, playback not tested"
    } else { throw "Unexpected native audio initialization failure: $audioResult" }
} finally {
    if ($disposeAudio.Invoke() -ne 0 -or $disposeAudio.Invoke() -ne 0) { throw 'Native audio disposal failed' }
}
[byte[]]$pixels = 0,0,255,255, 0,255,0,255, 255,0,0,255, 255,255,255,255
if ($copy.Invoke($pixels, 16, 2, 2) -ne 0) { throw 'Could not write native clipboard image' }
[DesktopTest]::CheckClipboard()
if ($copy.Invoke($pixels, 15, 2, 2) -eq 0) { throw 'Truncated pixel buffer was accepted' }
[DesktopTest]::CheckClipboard() # Failed copies must leave the previous image intact.

$folder = Join-Path ([IO.Path]::GetTempPath()) ('dps-desktop-test-測試 & ' + [Guid]::NewGuid())
[IO.Directory]::CreateDirectory($folder) | Out-Null
$path = Join-Path $folder 'fight.json'
$content = '{"fixture":"recoverable combat log"}'
[IO.File]::WriteAllText($path, $content)
try {
    $bytes = [Text.Encoding]::UTF8.GetBytes($folder)
    if ($recycle.Invoke($bytes, $bytes.Length) -eq 0) { throw 'Directory deletion was accepted' }
    if (-not [IO.File]::Exists($path)) { throw 'Directory rejection changed its contents' }
    $invalid = [Text.Encoding]::UTF8.GetBytes('https://example.invalid')
    if ($open.Invoke($invalid, $invalid.Length) -eq 0) { throw 'Non-filesystem folder target was accepted' }
    $bytes = [Text.Encoding]::UTF8.GetBytes($path)
    $result = $recycle.Invoke($bytes, $bytes.Length)
    if ($result -ne 0) { throw "Native recycling failed: $result" }
    if ([IO.File]::Exists($path)) { throw 'Recycled fixture is still at its original path' }
    $shell = New-Object -ComObject Shell.Application
    $recovered = @($shell.Namespace(10).Items() | Where-Object { $_.ExtendedProperty('System.Recycle.DeletedFrom') -eq $folder })
    if ($recovered.Count -ne 1) { throw 'The fixture was not found in the actual Windows Recycle Bin' }
    if ([IO.File]::ReadAllText($recovered[0].Path) -ne $content) { throw 'Recycled contents differ' }
    $recovered[0].InvokeVerb('undelete')
    for ($attempt = 0; $attempt -lt 40 -and -not [IO.File]::Exists($path); $attempt++) { Start-Sleep -Milliseconds 250 }
    if (-not [IO.File]::Exists($path) -or [IO.File]::ReadAllText($path) -ne $content) { throw 'Recycle Bin restore did not recover the original file' }
    Write-Output 'Windows desktop: plugin ABI, clipboard image, validation, Unicode recycling, and Recycle Bin restore passed'
} finally {
    # Only this test's uniquely named temporary directory is removed.
    if ([IO.Directory]::Exists($folder)) { [IO.Directory]::Delete($folder, $true) }
}
