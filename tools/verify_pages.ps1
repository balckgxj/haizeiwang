# Full page sweep against an already-running Haizeiwang.exe.
# Prereq: tools\start_local_env.ps1 -WithGame  (MySQL + DZM server + client)
# Clicks "Enter Game", sends keys 1..9 (MainFrame test shortcuts),
# screenshots each page, reports crash_stack.txt and the latest loaded ccbi.
$ErrorActionPreference = "SilentlyContinue"
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WP {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, UIntPtr e);
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr e);
    [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint vk, uint map);
    public struct RECT { public int L, T, R, B; }
    public struct POINT { public int X, Y; }
}
"@

$root = "E:\PCGame\Haizeiwang"
$dbg = Join-Path $root "build\Debug"
$crash = Join-Path $dbg "crash_stack.txt"
$log = Join-Path $root "_tools\verify_run.log"
if (Test-Path $crash) { [System.IO.File]::Delete($crash) }

$p = Get-Process Haizeiwang -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { Write-Output "NO_GAME_PROCESS"; exit 1 }
$h = $p.MainWindowHandle
Write-Output ("attached pid={0} hwnd={1}" -f $p.Id, $h)

[WP]::ShowWindow($h, 9) | Out-Null
[WP]::SetWindowPos($h, [IntPtr](-1), 0, 0, 0, 0, 0x0001 -bor 0x0002) | Out-Null
[WP]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 700

$cr = New-Object WP+RECT
[WP]::GetClientRect($h, [ref]$cr) | Out-Null
$pt = New-Object WP+POINT
$pt.X = 0; $pt.Y = 0
[WP]::ClientToScreen($h, [ref]$pt) | Out-Null
$cw = $cr.R - $cr.L; $ch = $cr.B - $cr.T
Write-Output ("client origin={0},{1} size={2}x{3}" -f $pt.X, $pt.Y, $cw, $ch)

function Shot($name) {
    [WP]::SetForegroundWindow($h) | Out-Null
    Start-Sleep -Milliseconds 350
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
    $bmp.Save((Join-Path $root ("_tools\verify_" + $name + ".png")))
    $g.Dispose(); $bmp.Dispose()
}

function LastCcbi {
    $l = Select-String -Path $log -Pattern "^load ccbi file:" | Select-Object -Last 1
    if ($l) { return $l.Line } else { return "-" }
}

# Click "Enter Game"
$x = [int]($pt.X + $cw * 0.50); $y = [int]($pt.Y + $ch * 0.82)
[WP]::SetCursorPos($x, $y) | Out-Null
Start-Sleep -Milliseconds 250
[WP]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
[WP]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
Write-Output ("clicked enter at {0},{1}" -f $x, $y)
Start-Sleep -Seconds 18
Shot "0_maincity"
Write-Output ("after enter: alive={0} crash={1} lastccbi={2}" -f (-not $p.HasExited), (Test-Path $crash), (LastCcbi))

# Global key events (GLFW ignores PostMessage key messages), needs foreground focus.
function SendKey($vk) {
    [WP]::SetForegroundWindow($h) | Out-Null
    Start-Sleep -Milliseconds 120
    $scan = [WP]::MapVirtualKey($vk, 0)
    [WP]::keybd_event([byte]$vk, [byte]$scan, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 90
    [WP]::keybd_event([byte]$vk, [byte]$scan, 2, [UIntPtr]::Zero)
}

$pages = @(
    @{k=0x31; n="1_adventure"}, @{k=0x32; n="2_arena"},
    @{k=0x33; n="3_career"},    @{k=0x34; n="4_equip"},
    @{k=0x35; n="5_skill"},     @{k=0x36; n="6_disciple"},
    @{k=0x37; n="7_settings"},  @{k=0x38; n="8_package"},
    @{k=0x39; n="9_handbook"}
)
foreach ($pg in $pages) {
    SendKey $pg.k
    Start-Sleep -Seconds 3
    Shot $pg.n
    $state = if (Test-Path $crash) { "CRASH" } else { "ok" }
    Write-Output ("{0,-14} {1,-6} alive={2} lastccbi={3}" -f $pg.n, $state, (-not $p.HasExited), (LastCcbi))
    if ($state -eq "CRASH") { Write-Output "--- crash stack ---"; Get-Content $crash; break }
    SendKey 0x30
    Start-Sleep -Seconds 2
}
Write-Output "--- tail of run log ---"
Get-Content $log -Tail 12
