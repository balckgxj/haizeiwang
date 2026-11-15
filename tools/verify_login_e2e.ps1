# [haizei] 端到端验证：游戏内账号密码登录 -> 服务端登录 -> 主城 / GM 标记
# 必须在单次会话内跑完（通过 cmd /c 启动的游戏进程会随会话结束被回收）。
param(
    [string]$Account  = "heigui",
    [string]$Password = "123456",
    [switch]$WrongPassword
)
$ErrorActionPreference = "SilentlyContinue"
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public class EW {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc p, IntPtr l);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out WINRECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, UIntPtr e);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    public struct WINRECT { public int L, T, R, B; }
    public static List<string> Find(uint targetPid) {
        var outp = new List<string>();
        EnumWindows((h, l) => {
            uint pid; GetWindowThreadProcessId(h, out pid);
            if (pid != targetPid) return true;
            var cls = new StringBuilder(256); GetClassNameW(h, cls, 256);
            var ttl = new StringBuilder(256); GetWindowTextW(h, ttl, 256);
            WINRECT r; GetWindowRect(h, out r);
            outp.Add(h.ToInt64() + "|" + cls + "|" + ttl + "|" + (r.R-r.L) + "x" + (r.B-r.T) + "|" + r.L + "," + r.T + "|visible=" + IsWindowVisible(h));
            return true;
        }, IntPtr.Zero);
        return outp;
    }
}
"@

$root = "E:\PCGame\Haizeiwang"
$dbg  = Join-Path $root "build\Debug"
$log  = Join-Path $dbg "verify_run.log"
$crash= Join-Path $dbg "crash_stack.txt"

function Shot([int]$x,[int]$y,[int]$w,[int]$h,[string]$path) {
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size($w, $h)))
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $gfx.Dispose(); $bmp.Dispose()
    Write-Output ("SHOT {0} ({1}x{2} at {3},{4})" -f $path, $w, $h, $x, $y)
}
function Click([int]$x,[int]$y) {
    [EW]::SetCursorPos($x,$y) | Out-Null
    Start-Sleep -Milliseconds 180
    [EW]::mouse_event(0x0002,0,0,0,[UIntPtr]::Zero)
    [EW]::mouse_event(0x0004,0,0,0,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 250
}

Get-Process Haizeiwang -EA 0 | Stop-Process -Force
Start-Sleep -Seconds 1
if (Test-Path $crash) { [System.IO.File]::Delete($crash) }
if (Test-Path $log)   { [System.IO.File]::Delete($log) }

Start-Process -FilePath "cmd.exe" -ArgumentList "/c","Haizeiwang.exe > verify_run.log 2>&1" -WorkingDirectory $dbg -WindowStyle Normal | Out-Null
$g = $null
for ($i=0; $i -lt 40; $i++) {
    $g = Get-Process Haizeiwang -EA 0 | Select-Object -First 1
    if ($g -and $g.MainWindowHandle -ne 0) { break }
    Start-Sleep -Seconds 1
}
if (-not $g) { Write-Output "GAMELAUNCH_FAILED"; exit 1 }
Start-Sleep -Seconds 7

Write-Output "=== windows owned by game pid $($g.Id) ==="
$wins = [EW]::Find([uint32]$g.Id)
$wins | ForEach-Object { Write-Output ("  " + $_) }

# 选面积最大、可见、且不是控制台窗口的那个作为 GL 窗口
$best = $null; $bestArea = 0
foreach ($w in $wins) {
    $p = $w.Split('|')
    if ($p[1] -eq 'ConsoleWindowClass' -or $p[1] -eq 'PseudoConsoleWindow') { continue }
    if ($p[5] -ne 'visible=True') { continue }
    $dim = $p[3].Split('x'); $area = [int]$dim[0] * [int]$dim[1]
    if ($area -gt $bestArea) { $bestArea = $area; $best = $w }
}
if (-not $best) { Write-Output "GLWINDOW_NOT_FOUND"; exit 1 }
$p = $best.Split('|'); $hwnd = [IntPtr]([int64]$p[0]); $dim = $p[3].Split('x')
$gw = [int]$dim[0]; $gh = [int]$dim[1]; $pos = $p[4].Split(',')
$gx = [int]$pos[0]; $gy = [int]$pos[1]
Write-Output ("GLWINDOW hwnd={0} class={1} size={2}x{3} at {4},{5}" -f $p[0],$p[1],$gw,$gh,$gx,$gy)
[EW]::ShowWindow($hwnd, 9) | Out-Null
[EW]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 600

$scr = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
Shot $scr.X $scr.Y $scr.Width $scr.Height (Join-Path $root "_tools\login_e2e_full.png")
Shot $gx $gy $gw $gh (Join-Path $root "_tools\login_e2e_before.png")

# 设计分辨率 480x720：账号框 y=432，密码框 y=372，登录按钮 y=272（Cocos Y 轴向上）
$sx = $gx + [int]($gw * 0.50)
$accY = $gy + $gh - [int]($gh * (432.0/720.0))
$pwdY = $gy + $gh - [int]($gh * (372.0/720.0))
$btnY = $gy + $gh - [int]($gh * (272.0/720.0))
Write-Output ("click coords: acc=({0},{1}) pwd=({2},{3}) btn=({4},{5})" -f $sx,$accY,$sx,$pwdY,$sx,$btnY)

Click $sx $accY
[System.Windows.Forms.SendKeys]::SendWait($Account)
Start-Sleep -Milliseconds 350
Click $sx $pwdY
[System.Windows.Forms.SendKeys]::SendWait($(if ($WrongPassword) { $Password + "X" } else { $Password }))
Start-Sleep -Milliseconds 350
Click $sx $btnY
Write-Output "SENT_LOGIN_FORM"
Start-Sleep -Seconds 14

Shot $gx $gy $gw $gh (Join-Path $root "_tools\login_e2e_after.png")
Write-Output "=== log (login chain) ==="
if (Test-Path $log) {
    Select-String -Path $log -Pattern "LoginPage|lib91|GM flag|OPLogin|login handler|send packet|status|Assertion|crash|LoadingFrame::showEnter|preEnterMainMenu" |
        Select-Object -Last 45 | ForEach-Object { $_.Line }
}
Write-Output "=== crash stack ==="
if (Test-Path $crash) { Get-Content $crash -TotalCount 12 } else { Write-Output "(none)" }
Write-Output ("ALIVE: {0}" -f [bool](Get-Process Haizeiwang -EA 0))
