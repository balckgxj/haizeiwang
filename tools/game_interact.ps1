# 对游戏窗口做一次点击 / 写调试指令，并输出全屏截图 + 新增日志
# 用于端到端核对登录、GM 标记、船员突破等真实交互
param(
    [int]$X = -1,
    [int]$Y = -1,
    [int]$Wait = 3,
    [string]$Cmd = '',
    [string]$Shot = 'interact.png',
    [switch]$NoClick
)

$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$root = 'E:\PCGame\Haizeiwang'
$dbg  = Join-Path $root 'build\Debug'
$log  = Join-Path $dbg 'verify_run.log'
$out  = Join-Path $root '_tools'
$cmdFile = 'C:\Users\24219\AppData\Local\Haizeiwang\haizei_debug_cmd.txt'

Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class GI {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
  public const uint DOWN = 0x0002, UP = 0x0004;
}
'@

$pids = @(Get-Process -Name 'Haizeiwang' -ErrorAction SilentlyContinue | ForEach-Object { [uint32]$_.Id })
if ($pids.Count -eq 0) { Write-Output 'GAME_NOT_RUNNING'; exit 1 }
$ph = @{}; foreach ($p in $pids) { $ph[$p] = $true }

$target = [IntPtr]::Zero
$cb = [GI+EnumProc]{
    param($h, $l)
    [uint32]$owner = 0
    [void][GI]::GetWindowThreadProcessId($h, [ref]$owner)
    if (-not $ph.ContainsKey($owner)) { return $true }
    $sb = New-Object System.Text.StringBuilder 256
    [void][GI]::GetClassNameW($h, $sb, 256)
    if ($sb.ToString() -eq 'GLFW30' -and [GI]::IsWindowVisible($h)) {
        $script:target = $h
    }
    return $true
}
[void][GI]::EnumWindows($cb, [IntPtr]::Zero)
if ($target -eq [IntPtr]::Zero) { Write-Output 'GLWINDOW_NOT_FOUND'; exit 1 }
Write-Output "GLWINDOW: $target"

$before = if (Test-Path $log) { (Get-Item $log).Length } else { 0 }

if ($Cmd -ne '') {
    [System.IO.File]::WriteAllText($cmdFile, $Cmd)
    Write-Output "CMD_WRITTEN: $Cmd"
}

if (-not $NoClick -and $X -ge 0 -and $Y -ge 0) {
    [void][GI]::SetForegroundWindow($target)
    Start-Sleep -Milliseconds 250
    [void][GI]::SetCursorPos($X, $Y)
    Start-Sleep -Milliseconds 150
    [GI]::mouse_event([GI]::DOWN, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [GI]::mouse_event([GI]::UP, 0, 0, 0, [UIntPtr]::Zero)
    Write-Output "CLICK: ($X,$Y)"
}

Start-Sleep -Seconds $Wait

$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bmp.Size)
$p = Join-Path $out $Shot
$bmp.Save($p, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output "SHOT: $p"

Write-Output '=== new log lines ==='
if (Test-Path $log) {
    $len = (Get-Item $log).Length
    if ($len -gt $before) {
        $fs = [System.IO.File]::Open($log, 'Open', 'Read', 'ReadWrite')
        try {
            [void]$fs.Seek($before, 'Begin')
            $sr = New-Object System.IO.StreamReader($fs)
            $txt = $sr.ReadToEnd()
            $sr.Dispose()
        } finally { $fs.Dispose() }
        ($txt -split "`n") | Where-Object {
            $_ -match 'haizei|lib91|LoginPage|showEnter|GM flag|status|debug|cmd|send|Packet|Login|Enter|ERROR|Error|assert|CRASH|breakthrough|Break'
        } | Select-Object -First 60
    } else { Write-Output '(no new log)' }
}
