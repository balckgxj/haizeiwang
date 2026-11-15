# -*- coding: utf-8 -*-
# 定向复查：仅重新核对此前崩溃的 15 个页面，验证修复是否生效。
# 复用 audit_all_pages.ps1 的启动/崩溃检测逻辑。
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
$result= Join-Path $root "_tools\recheck_result.txt"
$enc   = New-Object System.Text.UTF8Encoding($false)

# 此前崩溃的 15 个页面（定向复查）
$names = @(
    "AboutPage","FightPage","TeacherTeachResultPage","NewActivePromptPage","NewActivePromptToolPage",
    "MemberPage","PlayerInfPage","SkillChangePage","StoneInlaidPage","DiscipleRecruitPage",
    "TeamBuffUpgradePage","TitleGetNewPage","TitleLVUpPage","TranExpPreviewPage","WorldBossRankPage"
)

function Write-Cmd($txt) { [System.IO.File]::WriteAllText($cmdFile, $txt, $enc) }

function EnsureServers {
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
    $b = [System.Drawing.Bitmap]::new([System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width, [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height)
    $g = [System.Drawing.Graphics]::FromImage($b)
    $g.CopyFromScreen([System.Drawing.Point]::Empty, [System.Drawing.Point]::Empty, $b.Size)
    $b.Save((Join-Path $root ("_tools\recheck_" + $name + ".png")))
    $g.Dispose(); $b.Dispose()
}

function LastCcbi {
    $l = Select-String -Path $log -Pattern "load ccbi file:" -EA 0 | Select-Object -Last 1
    if ($l) { return $l.Line } else { return "-" }
}

function HasErrorDialog {
    # Debug CRT 断言框标题是 "Microsoft Visual C++ Debug Library"，只查 Runtime Library 会漏报。
    $titles = @(
        "Microsoft Visual C++ Runtime Library",
        "Microsoft Visual C++ Debug Library",
        "Debug Assertion Failed!",
        "Assertion Failed"
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
    # Debug CRT 断言写 stderr（xtree(182) : Assertion failed），不生成 crash_stack.txt。
    # 只检查本次 goto 之后的新增日志，避免跨页误判。
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
$total = $names.Count
Write-Output ("=== 定向复查 {0} 个页面 ===" -f $total)

$g = LaunchGame
if (-not $g) { Write-Output "ABORT: 游戏无法启动"; exit 1 }

$crashMtime = if (Test-Path $crash) { (Get-Item $crash).LastWriteTime } else { $null }
$report = @()
$idx = 0
foreach ($name in $names) {
    $idx++
    $logBefore = LogLen
    Write-Cmd ("goto:" + $name)
    Start-Sleep -Seconds 2
    $alive = -not $g.HasExited
    $errDlg = HasErrorDialog
    $logAssert = NewAssertInLog $logBefore
    $crashed = $false
    if (-not $alive) { $crashed = $true }
    elseif ($errDlg) { $crashed = $true }
    elseif ($logAssert) { $crashed = $true }
    elseif (Test-Path $crash) {
        $mt = (Get-Item $crash).LastWriteTime
        if ($crashMtime -eq $null -or $mt -gt $crashMtime) { $crashed = $true }
    }
    $shotName = ("recheck_{0:D2}_{1}" -f $idx, $name)
    Shot $shotName
    if ($crashed) {
        Write-Output ("[{0:D2}/{1}] {2,-28} CRASH (alive={3} errDlg={4} logAssert={5}) lastccbi={6}" -f $idx,$total,$name,$alive,$errDlg,$logAssert,(LastCcbi))
        $report += ("{0,-28} CRASH" -f $name)
        Write-Cmd ""
        $g = LaunchGame
        if (-not $g) { Write-Output "ABORT: 重启失败"; break }
        $crashMtime = if (Test-Path $crash) { (Get-Item $crash).LastWriteTime } else { $null }
    } else {
        Write-Output ("[{0:D2}/{1}] {2,-28} ok     lastccbi={3}" -f $idx,$total,$name,(LastCcbi))
        $report += ("{0,-28} ok" -f $name)
        $crashMtime = if (Test-Path $crash) { (Get-Item $crash).LastWriteTime } else { $null }
    }
}
Write-Output "=== 复查完成 ==="
$report | Out-File -FilePath $result -Encoding utf8
Write-Output ("结果已写入 {0}" -f $result)
$crashes = ($report | Where-Object { $_ -match "CRASH" }).Count
Write-Output ("崩溃页面数: {0} / {1}" -f $crashes, $total)
Get-Content $result
