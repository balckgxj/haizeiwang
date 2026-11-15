# 端到端核对：自动登录 -> 进入主城 -> 打开船员突破页 -> （可选）点击突破按钮
# 必须在一次 PowerShell 执行内完成，否则游戏子进程会随会话结束被回收。
param(
    [int]$BreakX = -1,          # 「突破」按钮「设计坐标」X（320x480），留空则只截图定位
    [int]$BreakY = -1,          # 「突破」按钮「设计坐标」Y（左下原点）
    [int]$EnterX = 168,         # 「进入游戏」按钮设计坐标
    [int]$EnterY = 100,
    [string]$Page = 'DiscipleUpgradePage'
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
public class VB {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  public const uint DOWN = 0x0002, UP = 0x0004;
}
'@

function Shot([string]$name) {
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.X, $b.Y, 0, 0, $bmp.Size)
    $p = Join-Path $out $name
    $bmp.Save($p, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    Write-Output "SHOT: $p"
}

function Click([int]$x, [int]$y) {
    [void][VB]::SetCursorPos($x, $y)
    Start-Sleep -Milliseconds 150
    [VB]::mouse_event([VB]::DOWN, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [VB]::mouse_event([VB]::UP, 0, 0, 0, [UIntPtr]::Zero)
    Write-Output "CLICK: ($x,$y)"
}

function FindGL {
    $script:gl = [IntPtr]::Zero
    $pids = @(Get-Process -Name 'Haizeiwang' -ErrorAction SilentlyContinue | ForEach-Object { [uint32]$_.Id })
    if ($pids.Count -eq 0) { return $false }
    $ph = @{}; foreach ($p in $pids) { $ph[$p] = $true }
    $cb = [VB+EnumProc]{
        param($h, $l)
        [uint32]$owner = 0
        [void][VB]::GetWindowThreadProcessId($h, [ref]$owner)
        if (-not $ph.ContainsKey($owner)) { return $true }
        $sb = New-Object System.Text.StringBuilder 256
        [void][VB]::GetClassNameW($h, $sb, 256)
        if ($sb.ToString() -eq 'GLFW30' -and [VB]::IsWindowVisible($h)) { $script:gl = $h }
        return $true
    }
    [void][VB]::EnumWindows($cb, [IntPtr]::Zero)
    return ($script:gl -ne [IntPtr]::Zero)
}

# ---- 启动 ----
Get-Process -Name 'Haizeiwang' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 700
Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue
[System.IO.File]::WriteAllText($cmdFile, 'boot')
Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', 'Haizeiwang.exe > verify_run.log 2>&1') `
    -WorkingDirectory $dbg -WindowStyle Normal | Out-Null
Start-Sleep -Seconds 7
if (-not (FindGL)) { Write-Output 'GLWINDOW_NOT_FOUND'; exit 1 }
[void][VB]::SetForegroundWindow($script:gl)
$r = New-Object VB+RECT
[void][VB]::GetWindowRect($script:gl, [ref]$r)
Write-Output "GLRECT virtual: L=$($r.L) T=$($r.T) W=$($r.R-$r.L) H=$($r.B-$r.T)"
# GLFW 每次启动位置不同；150% DPI 下窗口 rect 是虚拟坐标，标题栏约 30 虚拟像素。
# 客户区虚拟尺寸约 320x480，与设计分辨率 1:1。
$clientL = $r.L
$clientT = $r.T + 30
function ToScreen([int]$dx, [int]$dy) { return @( ($clientL + $dx), ($clientT + (480 - $dy)) ) }
Shot 'crew_01_login.png'

# ---- 进入游戏 ----
$e = ToScreen $EnterX $EnterY
Write-Output "ENTER design=($EnterX,$EnterY) -> screen=($($e[0]),$($e[1]))"
Click $e[0] $e[1]
Start-Sleep -Seconds 9
Shot 'crew_02_maincity.png'

# ---- 打开目标页面 ----
[System.IO.File]::WriteAllText($cmdFile, "goto:$Page")
Write-Output "CMD: goto:$Page"
Start-Sleep -Seconds 3
Shot 'crew_03_page.png'

# ---- 可选：点击突破按钮 ----
if ($BreakX -ge 0 -and $BreakY -ge 0) {
    [void][VB]::SetForegroundWindow($script:gl)
    $b = ToScreen $BreakX $BreakY
    Write-Output "BREAK design=($BreakX,$BreakY) -> screen=($($b[0]),$($b[1]))"
    Click $b[0] $b[1]
    Start-Sleep -Seconds 4
    Shot 'crew_04_after_break.png'
}

# ---- 日志关键行 ----
Write-Output '=== LOG (login / GM / page / break) ==='
if (Test-Path $log) {
    Get-Content -LiteralPath $log | Where-Object {
        $_ -notmatch 'load ccbi file|ERROR: SpriteFrame nullptr|^$'
    } | Select-Object -Last 80
}
Write-Output '=== CRASH/EVIDENCE ==='
if (Test-Path $log) {
    Get-Content -LiteralPath $log | Where-Object { $_ -match 'Assertion|CRASH|assert|error|Error|Exception' } | Select-Object -Last 20
}
Write-Output "ALIVE: $((Get-Process -Name 'Haizeiwang' -ErrorAction SilentlyContinue) -ne $null)"
