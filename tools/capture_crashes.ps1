# 捕获指定页面的崩溃栈（在崩溃后、重启前拷贝 crash_stack.txt）
$ErrorActionPreference = "SilentlyContinue"
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WP2 {
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint x, uint y, uint d, UIntPtr e);
    public struct RECT { public int L, T, R, B; }
    public struct POINT { public int X, Y; }
}
"@
$root="E:\PCGame\Haizeiwang"; $dbg=Join-Path $root "build\Debug"
$crash=Join-Path $dbg "crash_stack.txt"
$cmdFile="C:\Users\24219\AppData\Local\Haizeiwang\haizei_debug_cmd.txt"
$enc=New-Object System.Text.UTF8Encoding($false)
function Write-Cmd($t){[System.IO.File]::WriteAllText($cmdFile,$t,$enc)}

# 确保服务端
if (-not (Get-Process mysqld -EA 0) -or -not (Get-Process java -EA 0)) { & "$root\tools\start_local_env.ps1" }

function Launch {
    Get-Process Haizeiwang -EA 0 | Stop-Process -Force
    Start-Sleep -Seconds 1
    if (Test-Path $crash){[System.IO.File]::Delete($crash)}
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c","Haizeiwang.exe > verify_run.log 2>&1" -WorkingDirectory $dbg -WindowStyle Normal | Out-Null
    $g=$null
    for($i=0;$i-lt45;$i++){ $g=Get-Process Haizeiwang -EA 0|?{$_.MainWindowHandle -ne 0}|select -first 1; if($g){break}; Start-Sleep 1 }
    if(-not $g){Write-Output "LAUNCH_FAIL"; return $null}
    $h=$g.MainWindowHandle
    [WP2]::ShowWindow($h,9)|Out-Null; [WP2]::SetWindowPos($h,[IntPtr](-1),0,0,0,0,0x0001 -bor 0x0002)|Out-Null; [WP2]::SetForegroundWindow($h)|Out-Null
    Start-Sleep -Milliseconds 800
    $cr=New-Object WP2+RECT; [WP2]::GetClientRect($h,[ref]$cr)|Out-Null
    $pt=New-Object WP2+POINT; $pt.X=0;$pt.Y=0; [WP2]::ClientToScreen($h,[ref]$pt)|Out-Null
    $cw=$cr.R-$cr.L; $ch=$cr.B-$cr.T
    [WP2]::SetCursorPos([int]($pt.X+$cw*0.5),[int]($pt.Y+$ch*0.82))|Out-Null
    Start-Sleep -Milliseconds 250
    [WP2]::mouse_event(2,0,0,0,[UIntPtr]::Zero); [WP2]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
    Start-Sleep -Seconds 16
    return $g
}

$pages=@("BuyPropsCountPage","BuyStoneCountPage","CareerStoryPage")
foreach($name in $pages){
    $g=Launch
    if(-not $g){Write-Output "FAIL $name"; continue}
    Write-Cmd ("goto:"+$name)
    Start-Sleep -Seconds 3
    if(Test-Path $crash){
        $dst=Join-Path $root ("_tools\crash_"+$name+".txt")
        Copy-Item $crash $dst -Force
        Write-Output ("=== $name CRASH captured -> $dst ===")
        Get-Content $crash | Select-Object -First 30 | ForEach-Object { Write-Output $_ }
    } else {
        Write-Output ("=== $name NO CRASH (alive={0}) ===" -f (-not $g.HasExited))
    }
    Write-Cmd ""
}
Write-Output "DONE"
