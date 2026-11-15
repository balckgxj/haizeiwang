# -*- coding: utf-8 -*-
# 捕获 FightPage 打开后进程退出的现场：不重启、不截图、完整 dump verify_run.log 末尾。
param([int]$wait = 10)
$ErrorActionPreference = "SilentlyContinue"
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class WP4 {
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
"@
$root="E:\PCGame\Haizeiwang"; $dbg=Join-Path $root "build\Debug"
$log=Join-Path $dbg "verify_run.log"; $crash=Join-Path $dbg "crash_stack.txt"
$cmdFile="C:\Users\24219\AppData\Local\Haizeiwang\haizei_debug_cmd.txt"
$enc=New-Object System.Text.UTF8Encoding($false)
function Write-Cmd($t){ [System.IO.File]::WriteAllText($cmdFile,$t,$enc) }
Get-Process Haizeiwang -EA 0 | Stop-Process -Force; Start-Sleep -Seconds 1
if(Test-Path $crash){ [System.IO.File]::Delete($crash) }
Start-Process -FilePath "cmd.exe" -ArgumentList "/c","Haizeiwang.exe > verify_run.log 2>&1" -WorkingDirectory $dbg -WindowStyle Normal | Out-Null
$g=$null
for($i=0;$i -lt 45;$i++){
    $g=Get-Process Haizeiwang -EA 0 | Where-Object{$_.MainWindowHandle -ne 0} | Select-Object -First 1
    if($g){break}; Start-Sleep -Seconds 1
}
if(-not $g){ Write-Output "GAMELAUNCH_FAILED"; exit 1 }
$h=$g.MainWindowHandle
[WP4]::ShowWindow($h,9)|Out-Null
[WP4]::SetWindowPos($h,[IntPtr](-1),0,0,0,0,0x0001 -bor 0x0002)|Out-Null
[WP4]::SetForegroundWindow($h)|Out-Null
Start-Sleep -Milliseconds 800
$cr=New-Object WP4+RECT; [WP4]::GetClientRect($h,[ref]$cr)|Out-Null
$pt=New-Object WP4+POINT; $pt.X=0;$pt.Y=0; [WP4]::ClientToScreen($h,[ref]$pt)|Out-Null
$x=[int]($pt.X+($cr.R-$cr.L)*0.50); $y=[int]($pt.Y+($cr.B-$cr.T)*0.82)
[WP4]::SetCursorPos($x,$y)|Out-Null; Start-Sleep -Milliseconds 250
[WP4]::mouse_event(2,0,0,0,[UIntPtr]::Zero); [WP4]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
Start-Sleep -Seconds 16
Write-Cmd "goto:FightPage"
for($i=0;$i -lt $wait;$i++){
    Start-Sleep -Seconds 1
    $a = -not $g.HasExited
    Write-Output ("t+{0}s alive={1}" -f ($i+1), $a)
    if(-not $a){ break }
}
Write-Output "=== verify_run.log last 70 lines ==="
Get-Content $log -Tail 70
Write-Output "=== crash_stack? ==="
if(Test-Path $crash){ Get-Content $crash | Select-Object -First 12 } else { Write-Output "none" }
Write-Cmd ""
Write-Output "=== DONE ==="
