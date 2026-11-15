# Attach to an already-running Haizeiwang.exe, open the Adventure page with key "1",
# take a screenshot and report whether a crash stack was produced.
# Usage: powershell -File tools\verify_adventure.ps1
$ErrorActionPreference = "SilentlyContinue"
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WV {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr e);
    [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint vk, uint map);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr wp, IntPtr lp);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    public struct RECT { public int L, T, R, B; }
}
"@

$dbg = "E:\PCGame\Haizeiwang\build\Debug"
$crash = Join-Path $dbg "crash_stack.txt"
$log = "E:\PCGame\Haizeiwang\_tools\verify_run.log"
Remove-Item $crash -Force -ErrorAction SilentlyContinue

$p = Get-Process Haizeiwang -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { Write-Output "NO_GAME_PROCESS"; exit 1 }
$h = $p.MainWindowHandle
Write-Output ("attached pid={0} hwnd={1} title='{2}'" -f $p.Id, $h, $p.MainWindowTitle)

[WV]::ShowWindow($h, 9) | Out-Null            # SW_RESTORE
[WV]::SetWindowPos($h, [IntPtr](-1), 0, 0, 0, 0, 0x0001 -bor 0x0002) | Out-Null  # TOPMOST, NOSIZE|NOMOVE
[WV]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 600

# Post WM_KEYDOWN/WM_KEYUP straight to the game window: does not need focus.
function SendKey($vk) {
    [WV]::PostMessage($h, 0x0100, [IntPtr]$vk, [IntPtr]0) | Out-Null
    Start-Sleep -Milliseconds 90
    [WV]::PostMessage($h, 0x0101, [IntPtr]$vk, [IntPtr]0) | Out-Null
}

function Shot($name) {
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
    $bmp.Save("E:\PCGame\Haizeiwang\_tools\$name.png")
    $g.Dispose(); $bmp.Dispose()
}

$before = (Get-Content $log | Measure-Object -Line).Lines
SendKey 0x31   # KEY_1 -> AdventurePage
Start-Sleep -Seconds 9
Shot "verify_adventure"

Write-Output ("log_lines_before=$before")
Write-Output ("alive=" + (-not $p.HasExited))
Write-Output ("crash_file=" + (Test-Path $crash))
if (Test-Path $crash) { Write-Output "--- crash stack ---"; Get-Content $crash }
Write-Output ("log_lines=" + (Get-Content $log | Measure-Object -Line).Lines)
Write-Output "--- Adventure / SkillBook log hits ---"
Select-String -Path $log -Pattern "AdventurePage|SkillBook|AdventureNavButton" | Select-Object -Last 10 | ForEach-Object { $_.Line }
Write-Output "--- tail ---"
Get-Content $log -Tail 12
