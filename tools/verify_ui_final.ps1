# [haizei] 第五轮 UI 修复 · 最终实跑回归（一体化）
# 关键：三个后台服务由 Start-Process 拉起，会随 PowerShell 会话结束被回收，
# 因此「启服务 -> 启客户端 -> 登录 -> 逐页点击/拖动 -> 截图 -> 读日志」必须
# 在同一次 .ps1 执行内完成。服务在脚本结束后自动停止，不残留常驻进程。
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# PowerShell 5.1 Start-Process 的大小写不敏感 env 字典会撞代理变量
foreach ($n in @('http_proxy','https_proxy','all_proxy','no_proxy',
                 'HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY')) {
    [Environment]::SetEnvironmentVariable($n, $null, 'Process')
}

$root = 'E:\PCGame\Haizeiwang'
$dbg  = Join-Path $root 'build\Debug'
$out  = Join-Path $root '_tools'
$log  = Join-Path $dbg 'verify_final.log'
$err  = Join-Path $dbg 'verify_final.err'
$cmdFile = 'C:\Users\24219\AppData\Local\Haizeiwang\haizei_debug_cmd.txt'
$mysqlDir = 'E:\Softwares\mysql-5.6.51-winx64'
$jdk  = 'E:\Softwares\jdk8u512-b09\bin\java.exe'
$srvDir = 'E:\BaiduNetdiskDownload\(SY-096)草M船Z\src\src\server\Code_Server\server'
$php  = 'E:\Softwares\php-5.6.40\php.exe'
$gmDir = Join-Path $root 'tools\gm_admin'

Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class V7 {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
  public struct RECT { public int L, T, R, B; }
  public const uint DOWN = 0x0002, UP = 0x0004;
}
'@

function PortUp([int]$port) {
    return ($null -ne (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue))
}
function WaitPort([int]$port, [int]$sec) {
    for ($i = 0; $i -lt $sec; $i++) { if (PortUp $port) { return $true }; Start-Sleep -Seconds 1 }
    return (PortUp $port)
}

Write-Output '=== 1) 拉起本地服务 ==='
if (-not (PortUp 3306)) {
    $null = Start-Process -FilePath (Join-Path $mysqlDir 'bin\mysqld.exe') `
        -ArgumentList @("--defaults-file=`"$(Join-Path $mysqlDir 'my.ini')`"") `
        -WorkingDirectory $mysqlDir -WindowStyle Hidden -PassThru `
        -RedirectStandardError (Join-Path $out 'mysql_stderr.log')
}
Write-Output ("mysql 3306 : {0}" -f (WaitPort 3306 25))

if (-not (PortUp 25524)) {
    $null = Start-Process -FilePath $jdk -ArgumentList @('-Dfile.encoding=UTF-8','-jar','DZM.jar') `
        -WorkingDirectory $srvDir -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $srvDir 'dzm_stdout.log') `
        -RedirectStandardError (Join-Path $srvDir 'dzm_stderr.log')
}
Write-Output ("server 25524 : {0}" -f (WaitPort 25524 30))

if (-not (PortUp 8080)) {
    $null = Start-Process -FilePath $php -ArgumentList @('-S','127.0.0.1:8080','-t',"`"$gmDir`"") `
        -WorkingDirectory $gmDir -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $out 'gm_admin_stdout.log') `
        -RedirectStandardError (Join-Path $out 'gm_admin_stderr.log')
}
Write-Output ("gm_admin 8080 : {0}" -f (WaitPort 8080 15))

if (-not ((PortUp 3306) -and (PortUp 25524) -and (PortUp 8080))) {
    Write-Output 'SERVICES_NOT_READY'; exit 1
}

function FindGL {
    $script:gl = [IntPtr]::Zero
    $pids = @(Get-Process -Name 'Haizeiwang' -ErrorAction SilentlyContinue | ForEach-Object { [uint32]$_.Id })
    if ($pids.Count -eq 0) { return $false }
    $ph = @{}; foreach ($p in $pids) { $ph[$p] = $true }
    $cb = [V7+EnumProc]{
        param($h, $l)
        [uint32]$owner = 0
        [void][V7]::GetWindowThreadProcessId($h, [ref]$owner)
        if (-not $ph.ContainsKey($owner)) { return $true }
        $sb = New-Object System.Text.StringBuilder 256
        [void][V7]::GetClassNameW($h, $sb, 256)
        if ($sb.ToString() -eq 'GLFW30' -and [V7]::IsWindowVisible($h)) { $script:gl = $h }
        return $true
    }
    [void][V7]::EnumWindows($cb, [IntPtr]::Zero)
    return ($script:gl -ne [IntPtr]::Zero)
}
function Get-Client {
    if (-not (FindGL)) { return $null }
    [void][V7]::SetForegroundWindow($script:gl)
    Start-Sleep -Milliseconds 250
    $r = New-Object V7+RECT
    [void][V7]::GetWindowRect($script:gl, [ref]$r)
    return @{ L = $r.L; T = $r.T + 30; W = ($r.R - $r.L) }
}
function ToScreen($c, [int]$dx, [int]$dy) { return @( ($c.L + $dx), ($c.T + (480 - $dy)) ) }
function Click($c, [int]$dx, [int]$dy) {
    $p = ToScreen $c $dx $dy
    [void][V7]::SetCursorPos($p[0], $p[1]); Start-Sleep -Milliseconds 150
    [V7]::mouse_event([V7]::DOWN,0,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 80
    [V7]::mouse_event([V7]::UP,0,0,0,[UIntPtr]::Zero)
}
function Drag($c, [int]$x1, [int]$y1, [int]$x2, [int]$y2) {
    $p1 = ToScreen $c $x1 $y1; $p2 = ToScreen $c $x2 $y2
    [void][V7]::SetCursorPos($p1[0], $p1[1]); Start-Sleep -Milliseconds 250
    [V7]::mouse_event([V7]::DOWN,0,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 120
    for ($i = 1; $i -le 14; $i++) {
        $nx = $p1[0] + ($p2[0]-$p1[0]) * $i / 14
        $ny = $p1[1] + ($p2[1]-$p1[1]) * $i / 14
        [void][V7]::SetCursorPos([int]$nx, [int]$ny); Start-Sleep -Milliseconds 40
    }
    Start-Sleep -Milliseconds 200
    [V7]::mouse_event([V7]::UP,0,0,0,[UIntPtr]::Zero)
}
function Shot([string]$name) {
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.X, $b.Y, 0, 0, $bmp.Size)
    $bmp.Save((Join-Path $out $name), [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
}

Write-Output '=== 2) 启动客户端 ==='
Get-Process -Name 'Haizeiwang' -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 700
# cmd /c 的 '>' 每次会覆盖日志，无需预删（删不存在的文件会被安全钩子拦截）
[System.IO.File]::WriteAllText($cmdFile, 'boot')
# 与已验证的 verify_crew_breakthrough / pass1b 一致：cmd /c 重定向 stdout+stderr，
# 保证 CCLOG 全部落到 verify_final.log（GUI 子系统 exe 直接 -Redirect 有时拿不到）。
$null = Start-Process -FilePath 'cmd.exe' `
    -ArgumentList @('/c', 'Haizeiwang.exe > verify_final.log 2>&1') `
    -WorkingDirectory $dbg -WindowStyle Normal -PassThru
$cl = $null
for ($i = 0; $i -lt 45; $i++) { $cl = Get-Client; if ($cl) { break }; Start-Sleep -Seconds 1 }
if (-not $cl) { Write-Output 'GLWINDOW_NOT_FOUND'; exit 1 }
Write-Output ("client win L={0} T={1} W={2}" -f $cl.L,$cl.T,$cl.W)
Shot 'final_00_login.png'

Write-Output '=== 3) 登录 -> 主城 ==='
Click $cl 168 303; Start-Sleep -Milliseconds 500
[System.Windows.Forms.SendKeys]::SendWait('heigui'); Start-Sleep -Milliseconds 500
Click $cl 168 260; Start-Sleep -Milliseconds 500
[System.Windows.Forms.SendKeys]::SendWait('123456'); Start-Sleep -Milliseconds 500
Click $cl 168 188
Start-Sleep -Seconds 8
Shot 'final_01_after_login.png'
$cl = Get-Client
if ($cl) { Click $cl 168 100 } else { Write-Output 'WARN: window lost before enter-game click' }
Start-Sleep -Seconds 12
Shot 'final_02_main_city.png'

# 登录成功判据：日志里出现进入主城的关键链路
$loginOk = $false
if (Test-Path $log) {
    $loginOk = [bool](Select-String -Path $log -Pattern 'preEnterMainMenu|MainFrame::|status: 0|showMain|EnterMain' -Quiet)
}
Write-Output "LOGIN_OK=$loginOk"

# 主城横向拖动（问题 1a）
$cl = Get-Client
if ($cl) { Drag $cl 240 120 80 120 }
Start-Sleep -Seconds 2
Shot 'final_03_main_hdrag.png'

Write-Output '=== 4) 逐页 goto + 纵向拖动前后对比 ==='
$pages = @('MemberPage','AdventurePage','HandbookPage','PackPreviewPage','FriendsPage',
           'SettingsPage','EquipPage','SkillPage','DiscipleUpgradePage',
           'FightPage','FightEndRankPage')
$n = 0
foreach ($pg in $pages) {
    $n++
    $cl = Get-Client
    if (-not $cl) { Write-Output "CLIENT_GONE at $pg"; break }
    [System.IO.File]::WriteAllText($cmdFile, "goto:$pg")
    Start-Sleep -Seconds 3
    Shot ("final_{0:00}_{1}_a.png" -f $n,$pg)
    $cl = Get-Client
    if ($cl) { Drag $cl 160 380 160 100 }
    Start-Sleep -Seconds 2
    Shot ("final_{0:00}_{1}_b.png" -f $n,$pg)
    Write-Output ("PAGE {0:00} {1} alive={2}" -f $n,$pg,[bool](Get-Process -Name 'Haizeiwang' -ErrorAction SilentlyContinue))
}

Write-Output '=== 5) 日志取证 ==='
if (Test-Path $log) {
    Write-Output '--- 缺失 sprite frame（去重） ---'
    Select-String -Path $log -Pattern '\[CCB\] sprite frame not found' |
        ForEach-Object { ($_.Line -replace '^.*not found: ','') } | Sort-Object -Unique
    Write-Output '--- shader / 断言 / 连接错误 ---'
    Get-Content $log | Where-Object { $_ -match 'CC_Texture0|shader|ERROR:|Assertion|xtree|connect server error|SendFailed|crash' } |
        Group-Object | Sort-Object Count -Descending | Select-Object -First 20 |
        ForEach-Object { "{0,4} x {1}" -f $_.Count, $_.Name }
    Write-Output '--- 登录链路 ---'
    Get-Content $log | Where-Object { $_ -match 'showEnter|send packet! opcode:1|GM flag|status:|preEnterMainMenu|MainFrame' } | Select-Object -Last 20
}
Write-Output ("FINAL_ALIVE={0}" -f [bool](Get-Process -Name 'Haizeiwang' -ErrorAction SilentlyContinue))
Write-Output '=== DONE ==='
