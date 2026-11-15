# [haizei] 验证游戏内账号密码登录页：启动 -> 截图 -> 检查登录链路日志
param(
    [int]$wait = 8,
    [switch]$WithInput,
    [string]$Account = "heigui",
    [string]$Password = "123456"
)
$ErrorActionPreference = "SilentlyContinue"
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class VWP {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, UIntPtr e);
    public struct RECT { public int L, T, R, B; }
    public struct POINT { public int X, Y; }
}
"@

$root = "E:\PCGame\Haizeiwang"
$dbg  = Join-Path $root "build\Debug"
$log  = Join-Path $dbg "verify_run.log"
$crash= Join-Path $dbg "crash_stack.txt"
$shot = Join-Path $root "_tools\login_page.png"

Get-Process Haizeiwang -EA 0 | Stop-Process -Force
Start-Sleep -Seconds 1
if (Test-Path $crash) { [System.IO.File]::Delete($crash) }
if (Test-Path $log)   { [System.IO.File]::Delete($log) }

Start-Process -FilePath "cmd.exe" -ArgumentList "/c","Haizeiwang.exe > verify_run.log 2>&1" -WorkingDirectory $dbg -WindowStyle Normal | Out-Null
$g = $null
for ($i=0; $i -lt 40; $i++) {
    $g = Get-Process Haizeiwang -EA 0 | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if ($g) { break }
    Start-Sleep -Seconds 1
}
if (-not $g) { Write-Output "GAMELAUNCH_FAILED"; exit 1 }
$h = $g.MainWindowHandle
[VWP]::ShowWindow($h, 9) | Out-Null
[VWP]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Seconds $wait

# 截图（窗口客户区）
$cr = New-Object VWP+RECT; [VWP]::GetClientRect($h, [ref]$cr) | Out-Null
$pt = New-Object VWP+POINT; $pt.X=0; $pt.Y=0; [VWP]::ClientToScreen($h, [ref]$pt) | Out-Null
$cw = $cr.R - $cr.L; $ch = $cr.B - $cr.T
$bmp = New-Object System.Drawing.Bitmap($cw, $ch)
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$gfx.CopyFromScreen($pt.X, $pt.Y, 0, 0, (New-Object System.Drawing.Size($cw, $ch)))
$bmp.Save($shot, [System.Drawing.Imaging.ImageFormat]::Png)
$gfx.Dispose(); $bmp.Dispose()
Write-Output ("SHOT: {0} ({1}x{2})" -f $shot, $cw, $ch)

# 可选：用键盘在登录页输入账号密码并回车（EditBox 焦点默认在账号框）
if ($WithInput) {
    [System.Windows.Forms.SendKeys]::SendWait($Account)
    Start-Sleep -Milliseconds 300
    [System.Windows.Forms.SendKeys]::SendWait("{TAB}")
    Start-Sleep -Milliseconds 300
    [System.Windows.Forms.SendKeys]::SendWait($Password)
    Start-Sleep -Milliseconds 300
    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
    Write-Output "SENT_KEYS: $Account / $Password"
    Start-Sleep -Seconds 10
    $bmp2 = New-Object System.Drawing.Bitmap($cw, $ch)
    $gfx2 = [System.Drawing.Graphics]::FromImage($bmp2)
    $gfx2.CopyFromScreen($pt.X, $pt.Y, 0, 0, (New-Object System.Drawing.Size($cw, $ch)))
    $shot2 = Join-Path $root "_tools\login_after.png"
    $bmp2.Save($shot2, [System.Drawing.Imaging.ImageFormat]::Png)
    $gfx2.Dispose(); $bmp2.Dispose()
    Write-Output "SHOT2: $shot2"
}

Write-Output "=== login-related log lines ==="
if (Test-Path $log) {
    Select-String -Path $log -Pattern "LoginPage|lib91|GM flag|OPLogin|login handler|send packet|Assertion|crash" |
        Select-Object -Last 40 | ForEach-Object { $_.Line }
}
Write-Output "=== crash stack ==="
if (Test-Path $crash) { Get-Content $crash -TotalCount 12 } else { Write-Output "(none)" }
Write-Output ("ALIVE: {0}" -f [bool](Get-Process Haizeiwang -EA 0))
