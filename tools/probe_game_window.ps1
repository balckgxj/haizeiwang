# 启动游戏并探测窗口：全屏截图 + 正确的 Unicode 窗口枚举 + 运行日志
# 用途：核对登录页/主城/船员突破页的真实渲染与可点击坐标
param(
    [int]$WaitSeconds = 7
)

$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$root = 'E:\PCGame\Haizeiwang'
$dbg  = Join-Path $root 'build\Debug'
$log  = Join-Path $dbg 'verify_run.log'
$out  = Join-Path $root '_tools'
if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out | Out-Null }

Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class WinProbe {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
'@

function Get-GamePids {
    @(Get-Process -Name 'Haizeiwang' -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
}

# 清掉旧实例
Get-Process -Name 'Haizeiwang' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 800
Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue

Start-Process -FilePath 'cmd.exe' `
    -ArgumentList @('/c', 'Haizeiwang.exe > verify_run.log 2>&1') `
    -WorkingDirectory $dbg -WindowStyle Normal | Out-Null
Start-Sleep -Seconds $WaitSeconds

$pids = Get-GamePids
Write-Output "GAME_PIDS: $($pids -join ',')"

$pidsHash = @{}
foreach ($p in $pids) { $pidsHash[[uint32]$p] = $true }
$rows = New-Object System.Collections.ArrayList
$cb = [WinProbe+EnumProc]{
    param($h, $l)
    [uint32]$owner = 0
    [void][WinProbe]::GetWindowThreadProcessId($h, [ref]$owner)
    if (-not $pidsHash.ContainsKey($owner)) { return $true }
    $sbT = New-Object System.Text.StringBuilder 512
    $sbC = New-Object System.Text.StringBuilder 512
    [void][WinProbe]::GetWindowTextW($h, $sbT, 512)
    [void][WinProbe]::GetClassNameW($h, $sbC, 512)
    $r = New-Object WinProbe+RECT
    [void][WinProbe]::GetWindowRect($h, [ref]$r)
    $vis = [WinProbe]::IsWindowVisible($h)
    [void]$rows.Add([pscustomobject]@{
        HWND = [int64]$h
        Class = $sbC.ToString()
        Title = $sbT.ToString()
        L = $r.L; T = $r.T; W = ($r.R - $r.L); H = ($r.B - $r.T)
        Visible = $vis
    })
    return $true
}
[void][WinProbe]::EnumWindows($cb, [IntPtr]::Zero)

Write-Output '=== windows owned by game ==='
$rows | ForEach-Object {
    Write-Output ("{0}|{1}|{2}|{3}x{4}|{5},{6}|visible={7}" -f $_.HWND, $_.Class, $_.Title, $_.W, $_.H, $_.L, $_.T, $_.Visible)
}

# 全屏截图
$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
$bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($bounds.X, $bounds.Y, 0, 0, $bmp.Size)
$shot = Join-Path $out 'probe_full.png'
$bmp.Save($shot, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output "FULLSHOT: $shot ($($bounds.Width)x$($bounds.Height))"

Write-Output '=== log tail (login chain) ==='
if (Test-Path $log) {
    Get-Content -LiteralPath $log -Tail 60 | Where-Object {
        $_ -match 'LoginPage|lib91|haizei|showEnter|LoadingFrame|send|GM flag|status|error|Error|assert'
    }
} else { Write-Output '(no log)' }
