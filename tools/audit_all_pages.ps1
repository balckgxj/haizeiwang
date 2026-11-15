# -*- coding: utf-8 -*-
# 全页面功能核对：对 115 个注册页面逐一打开，截图 + 崩溃检测。
# 调试通道：MainFrame 文件轮询器读取
#   C:\Users\24219\AppData\Local\Haizeiwang\haizei_debug_cmd.txt
# 指令: goto:<PageName>  push:<PageName>  pop:<PageName>  back  quit
$ErrorActionPreference = "SilentlyContinue"
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WP {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, UIntPtr e);
    public struct RECT { public int L, T, R, B; }
    public struct POINT { public int X, Y; }
}
public class WF {
    [DllImport("user32.dll")] public static extern IntPtr FindWindow(string cls, string title);
}
"@

$root  = "E:\PCGame\Haizeiwang"
$dbg   = Join-Path $root "build\Debug"
$log   = Join-Path $dbg "verify_run.log"
$crash = Join-Path $dbg "crash_stack.txt"
$cmdFile = "C:\Users\24219\AppData\Local\Haizeiwang\haizei_debug_cmd.txt"
$list  = Join-Path $root "_tools\page_list.txt"
$result= Join-Path $root "_tools\page_audit_result.txt"
$enc   = New-Object System.Text.UTF8Encoding($false)

function Write-Cmd($txt) { [System.IO.File]::WriteAllText($cmdFile, $txt, $enc) }

function EnsureServers {
    # 若 MySQL / Java 服务端未起，启动它们
    $my = Get-Process mysqld -EA 0
    $java = Get-Process java -EA 0
    if (-not $my -or -not $java) {
        & "$root\tools\start_local_env.ps1"
    }
}

function LaunchGame {
    Get-Process Haizeiwang -EA 0 | Stop-Process -Force
    Start-Sleep -Seconds 1
    if (Test-Path $crash) { [System.IO.File]::Delete($crash) }
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c","Haizeiwang.exe > verify_run.log 2>&1" -WorkingDirectory $dbg -WindowStyle Normal | Out-Null
    $g = $null
    for ($i=0; $i -lt 45; $i++) {
        $g = Get-Process Haizeiwang -EA 0 | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
        if ($g) { break }
        Start-Sleep -Seconds 1
    }
    if (-not $g) { Write-Output "GAMELAUNCH_FAILED"; return $null }
    $h = $g.MainWindowHandle
    [WP]::ShowWindow($h, 9) | Out-Null
    [WP]::SetWindowPos($h, [IntPtr](-1), 0, 0, 0, 0, 0x0001 -bor 0x0002) | Out-Null
    [WP]::SetForegroundWindow($h) | Out-Null
    Start-Sleep -Milliseconds 800
    # 进入游戏：点击屏幕中央偏下
    $cr = New-Object WP+RECT; [WP]::GetClientRect($h, [ref]$cr) | Out-Null
    $pt = New-Object WP+POINT; $pt.X=0; $pt.Y=0; [WP]::ClientToScreen($h, [ref]$pt) | Out-Null
    $cw = $cr.R - $cr.L; $ch = $cr.B - $cr.T
    $x = [int]($pt.X + $cw*0.50); $y = [int]($pt.Y + $ch*0.82)
    [WP]::SetCursorPos($x,$y) | Out-Null
    Start-Sleep -Milliseconds 250
    [WP]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
    [WP]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
    Write-Output ("entered game, waiting for main city (pid={0})" -f $g.Id)
    Start-Sleep -Seconds 16
    return $g
}

function Shot($name) {
    $p = Get-Process Haizeiwang -EA 0 | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if ($p) { [WP]::SetForegroundWindow($p.MainWindowHandle) | Out-Null }
    Start-Sleep -Milliseconds 350
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $bmp = New-Object System.Drawing.Bitmap $b.Width, $b.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($b.Location, [System.Drawing.Point]::Empty, $b.Size)
    $bmp.Save((Join-Path $root ("_tools\page_" + $name + ".png")))
    $g.Dispose(); $bmp.Dispose()
}

function LastCcbi {
    $l = Select-String -Path $log -Pattern "load ccbi file:" -EA 0 | Select-Object -Last 1
    if ($l) { return $l.Line } else { return "-" }
}

function HasErrorDialog {
    # 捕获 CRT 断言/abort 模态框。注意：Debug CRT 的标题是
    # "Microsoft Visual C++ Debug Library"（不是 Runtime Library），历史脚本只查后者会漏报。
    $titles = @(
        "Microsoft Visual C++ Runtime Library",
        "Microsoft Visual C++ Debug Library",
        "Debug Assertion Failed!",
        "Assertion Failed",
        "Microsoft Visual C++ Debug Assertion"
    )
    foreach ($t in $titles) {
        if ([WF]::FindWindow("#32770", $t) -ne [IntPtr]::Zero) { return $true }
    }
    return $false
}

function LogLen {
    if (Test-Path $log) { return (Get-Item $log).Length } else { return 0 }
}

function NewAssertInLog($offset) {
    # 只检查本次 goto 之后新写入的日志，避免把上一页的断言误判到当前页。
    # Debug CRT 断言走 stderr（"xtree(182) : Assertion failed"），不写 crash_stack.txt，
    # 且弹窗标题与 Runtime Library 不同 —— 仅靠进程存活/弹窗/crash_stack 会漏报。
    if (-not (Test-Path $log)) { return $false }
    try {
        $fs = [System.IO.File]::Open($log, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $len = $fs.Length
        if ($len -le $offset) { $fs.Close(); return $false }
        $fs.Seek($offset, [System.IO.SeekOrigin]::Begin) | Out-Null
        $n = [int]($len - $offset)
        $buf = New-Object byte[] $n
        $read = $fs.Read($buf, 0, $n)
        $fs.Close()
        if ($read -le 0) { return $false }
        $txt = [System.Text.Encoding]::Default.GetString($buf, 0, $read)
        return ($txt -match "Assertion failed|Debug Assertion|xtree\(\d+\)|abort\(\) has been called")
    } catch { return $false }
}

# ---------- 主流程 ----------
EnsureServers
$names = Get-Content $list -EA 0 | Where-Object { $_.Trim().Length -gt 0 }
$total = $names.Count
Write-Output ("=== 开始核对 {0} 个页面 ===" -f $total)

$g = LaunchGame
if (-not $g) { Write-Output "ABORT: 游戏无法启动"; exit 1 }

$crashMtime = if (Test-Path $crash) { (Get-Item $crash).LastWriteTime } else { $null }
$report = @()
$idx = 0
foreach ($name in $names) {
    $idx++
    $attempt = 0
    do {
        $attempt++
        $logBefore = LogLen
        Write-Cmd ("goto:" + $name)
        Start-Sleep -Seconds 2
        $alive = -not $g.HasExited
        $errDlg = HasErrorDialog
        $logAssert = NewAssertInLog $logBefore
        $newStack = $false
        if (Test-Path $crash) {
            $mt = (Get-Item $crash).LastWriteTime
            if ($crashMtime -eq $null -or $mt -gt $crashMtime) { $newStack = $true }
        }
        # 硬崩溃证据：断言弹窗 / 日志断言 / 新写入的崩溃栈 —— 绝不重试，直接记录。
        $hardCrash = $errDlg -or $logAssert -or $newStack
        # 静默退出（无崩溃证据）多为环境性：长时运行时窗口最小化触发的移动端后台 exit(0) 等。
        # 只重测一次，且重测仍失败会照常记为 CRASH，不掩盖真实问题。
        $silentExit = (-not $alive) -and (-not $hardCrash)
        $crashed = $hardCrash -or $silentExit
        $retry = $false
        if ($silentExit -and $attempt -lt 2) {
            Write-Output ("   -> {0} 静默退出且无崩溃证据，重启后重测一次" -f $name)
            Write-Cmd ""
            $g = LaunchGame
            if (-not $g) { Write-Output "ABORT: 重启失败"; break }
            $crashMtime = if (Test-Path $crash) { (Get-Item $crash).LastWriteTime } else { $null }
            $retry = $true
        }
    } while ($retry)
    $shotName = ("{0:D3}_{1}" -f $idx, $name)
    Shot $shotName
    if ($crashed) {
        # 备份崩溃栈：后续 LaunchGame 会删除 crash_stack.txt，不备份就丢失证据。
        if (Test-Path $crash) {
            Copy-Item $crash (Join-Path $root ("_tools\crash_{0:D3}_{1}.txt" -f $idx, $name)) -Force
            $top = (Get-Content $crash | Select-Object -First 3) -join " | "
            Write-Output ("   -> stack: {0}" -f $top)
        }
        Write-Output ("[{0:D3}/{1}] {2,-28} CRASH (alive={3} errDlg={4} logAssert={5}) lastccbi={6}" -f $idx,$total,$name,$alive,$errDlg,$logAssert,(LastCcbi))
        $report += ("{0,-28} CRASH" -f $name)
        # 重启游戏继续
        Write-Output "   -> 重启游戏继续..."
        Write-Cmd ""
        $g = LaunchGame
        if (-not $g) { Write-Output "ABORT: 重启失败"; break }
        $crashMtime = if (Test-Path $crash) { (Get-Item $crash).LastWriteTime } else { $null }
    } else {
        Write-Output ("[{0:D3}/{1}] {2,-28} ok     lastccbi={3}" -f $idx,$total,$name,(LastCcbi))
        $report += ("{0,-28} ok" -f $name)
        $crashMtime = if (Test-Path $crash) { (Get-Item $crash).LastWriteTime } else { $null }
    }
}
Write-Output "=== 核对完成 ==="
$report | Out-File -FilePath $result -Encoding utf8
Write-Output ("结果已写入 {0}" -f $result)
$crashes = ($report | Where-Object { $_ -match "CRASH" }).Count
Write-Output ("崩溃页面数: {0} / {1}" -f $crashes, $total)
Get-Content $result
