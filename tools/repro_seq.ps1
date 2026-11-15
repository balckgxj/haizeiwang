# -*- coding: utf-8 -*-
# 顺序复现：按给定页面序列依次 goto，逐页报告进程存活 / abort 弹窗 / crash_stack 变化。
# 用于复现「连续 goto 累积 BlackBoard 状态」才出现的崩溃（冷启动单独打开不复现）。
# 用法: powershell -File tools\repro_seq.ps1 -seq FightPage,FortuneComeReward -wait 2
param(
    [string[]]$seq = @("FightPage","FortuneComeReward"),
    [double]$wait = 2,
    [string]$fromList = "",
    [string]$untilPage = ""
)
$ErrorActionPreference = "SilentlyContinue"
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class WP3 {
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
public class WF3 { [DllImport("user32.dll")] public static extern IntPtr FindWindow(string cls, string title); }
"@
$root="E:\PCGame\Haizeiwang"; $dbg=Join-Path $root "build\Debug"
$log=Join-Path $dbg "verify_run.log"; $crash=Join-Path $dbg "crash_stack.txt"
$cmdFile="C:\Users\24219\AppData\Local\Haizeiwang\haizei_debug_cmd.txt"
$enc=New-Object System.Text.UTF8Encoding($false)
function Write-Cmd($t){ [System.IO.File]::WriteAllText($cmdFile,$t,$enc) }
function HasErrDlg { ([WF3]::FindWindow("#32770","Microsoft Visual C++ Runtime Library") -ne [IntPtr]::Zero) }
function LastCcbi { $l=Select-String -Path $log -Pattern "load ccbi file:" -EA 0 | Select-Object -Last 1; if($l){ $l.Line } else { "-" } }
function LaunchGame {
    Get-Process Haizeiwang -EA 0 | Stop-Process -Force; Start-Sleep -Seconds 1
    if(Test-Path $crash){ [System.IO.File]::Delete($crash) }
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c","Haizeiwang.exe > verify_run.log 2>&1" -WorkingDirectory $dbg -WindowStyle Normal | Out-Null
    $g=$null
    for($i=0;$i -lt 45;$i++){
        $g=Get-Process Haizeiwang -EA 0 | Where-Object{$_.MainWindowHandle -ne 0} | Select-Object -First 1
        if($g){break}; Start-Sleep -Seconds 1
    }
    if(-not $g){ return $null }
    $h=$g.MainWindowHandle
    [WP3]::ShowWindow($h,9)|Out-Null
    [WP3]::SetWindowPos($h,[IntPtr](-1),0,0,0,0,0x0001 -bor 0x0002)|Out-Null
    [WP3]::SetForegroundWindow($h)|Out-Null
    Start-Sleep -Milliseconds 800
    $cr=New-Object WP3+RECT; [WP3]::GetClientRect($h,[ref]$cr)|Out-Null
    $pt=New-Object WP3+POINT; $pt.X=0;$pt.Y=0; [WP3]::ClientToScreen($h,[ref]$pt)|Out-Null
    $x=[int]($pt.X+($cr.R-$cr.L)*0.50); $y=[int]($pt.Y+($cr.B-$cr.T)*0.82)
    [WP3]::SetCursorPos($x,$y)|Out-Null; Start-Sleep -Milliseconds 250
    [WP3]::mouse_event(2,0,0,0,[UIntPtr]::Zero); [WP3]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
    Start-Sleep -Seconds 16
    return $g
}

# 可选：从页面清单重放「前缀」，用于复现只有长序列累积状态才出现的崩溃。
if($fromList -ne ""){
    $all = @(Get-Content $fromList -EA 0 | Where-Object { $_.Trim().Length -gt 0 })
    if($untilPage -ne ""){
        $pos = [Array]::IndexOf($all, $untilPage)
        if($pos -ge 0){ $seq = $all[0..$pos] } else { $seq = $all }
    } else {
        $seq = $all
    }
}

$g = LaunchGame
if(-not $g){ Write-Output "GAMELAUNCH_FAILED"; exit 1 }
Write-Output ("=== sequence: {0} pages (wait={1}s) last={2} ===" -f $seq.Count, $wait, $seq[-1])
$crashMtime = $null
foreach($p in $seq){
    Write-Cmd ("goto:"+$p)
    Start-Sleep -Seconds $wait
    $alive = -not $g.HasExited
    $err = HasErrDlg
    $newCrash = $false
    if(Test-Path $crash){
        $mt=(Get-Item $crash).LastWriteTime
        if($crashMtime -eq $null -or $mt -gt $crashMtime){ $newCrash=$true }
        $crashMtime=$mt
    }
    Write-Output ("PAGE={0,-24} alive={1,-5} errDlg={2,-5} newCrash={3,-5} lastccbi={4}" -f $p,$alive,$err,$newCrash,(LastCcbi))
    if($newCrash){
        Write-Output "--- crash_stack.txt ---"
        Get-Content $crash | Select-Object -First 14
    }
    if(-not $alive){
        Write-Output "  -> process exited; relaunching"
        $g=LaunchGame
        if(-not $g){ break }
        $crashMtime=$null
    }
}
Write-Cmd ""
Get-Process Haizeiwang -EA 0 | Stop-Process -Force
Write-Output "=== DONE ==="
