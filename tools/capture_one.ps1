# 捕获单个页面的崩溃细节：crash_stack.txt 内容 + verify_run.log 中的 assert。
param([string]$pageName)
$ErrorActionPreference = "SilentlyContinue"
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class WP2 {
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
public class WF2 { [DllImport("user32.dll")] public static extern IntPtr FindWindow(string cls, string title); }
"@
$root="E:\PCGame\Haizeiwang"; $dbg=Join-Path $root "build\Debug"
$log=Join-Path $dbg "verify_run.log"; $crash=Join-Path $dbg "crash_stack.txt"
$cmdFile="C:\Users\24219\AppData\Local\Haizeiwang\haizei_debug_cmd.txt"
$enc=New-Object System.Text.UTF8Encoding($false)
function Write-Cmd($t){ [System.IO.File]::WriteAllText($cmdFile,$t,$enc) }
# launch
Get-Process Haizeiwang -EA 0 | Stop-Process -Force; Start-Sleep -Seconds 1
if(Test-Path $crash){[System.IO.File]::Delete($crash)}
Start-Process -FilePath "cmd.exe" -ArgumentList "/c","Haizeiwang.exe > verify_run.log 2>&1" -WorkingDirectory $dbg -WindowStyle Normal | Out-Null
$g=$null
for($i=0;$i-lt45;$i++){ $g=Get-Process Haizeiwang -EA 0 | Where-Object{$_.MainWindowHandle -ne 0} | Select-Object -First 1; if($g){break}; Start-Sleep -Seconds 1 }
if(-not $g){ Write-Output "GAMELAUNCH_FAILED"; exit 1 }
$h=$g.MainWindowHandle
[WP2]::ShowWindow($h,9)|Out-Null; [WP2]::SetWindowPos($h,[IntPtr](-1),0,0,0,0,0x0001 -bor 0x0002)|Out-Null; [WP2]::SetForegroundWindow($h)|Out-Null
Start-Sleep -Milliseconds 800
$cr=New-Object WP2+RECT; [WP2]::GetClientRect($h,[ref]$cr)|Out-Null
$pt=New-Object WP2+POINT; $pt.X=0;$pt.Y=0; [WP2]::ClientToScreen($h,[ref]$pt)|Out-Null
$x=[int]($pt.X+($cr.R-$cr.L)*0.50); $y=[int]($pt.Y+($cr.B-$cr.T)*0.82)
[WP2]::SetCursorPos($x,$y)|Out-Null; Start-Sleep -Milliseconds 250
[WP2]::mouse_event(2,0,0,0,[UIntPtr]::Zero); [WP2]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
Start-Sleep -Seconds 16
# open page
Write-Cmd ("goto:"+$pageName); Start-Sleep -Seconds 3
$alive=-not $g.HasExited; $errDlg=([WF2]::FindWindow("#32770","Microsoft Visual C++ Runtime Library") -ne [IntPtr]::Zero)
Write-Output ("PAGE=$pageName alive=$alive errDlg=$errDlg")
if(Test-Path $crash){ Write-Output "--- crash_stack.txt ---"; Get-Content $crash | Select-Object -First 12 }
else { Write-Output "--- no crash_stack.txt ---" }
# assert in log
$a=Select-String -Path $log -Pattern "Assertion failed|Assert failed|abort" -EA 0 | Select-Object -Last 3
if($a){ Write-Output "--- assert/log ---"; $a | ForEach-Object{ $_.Line } }
# last ccbi
$l=Select-String -Path $log -Pattern "load ccbi file:" -EA 0 | Select-Object -Last 1
if($l){ Write-Output ("lastccbi: "+$l.Line) }
Write-Output "=== END $pageName ==="
# cleanup
Write-Cmd ""; Get-Process Haizeiwang -EA 0 | Stop-Process -Force
