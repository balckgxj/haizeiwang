# 严格复测：发送 goto 之前清除陈旧崩溃栈，并以时间戳判定是否为本次真实崩溃
$ErrorActionPreference="SilentlyContinue"
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type @"
using System;using System.Runtime.InteropServices;
public class WP3{
 [DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr h,int c);
 [DllImport("user32.dll")]public static extern bool SetWindowPos(IntPtr h,IntPtr a,int x,int y,int cx,int cy,uint f);
 [DllImport("user32.dll")]public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")]public static extern bool GetClientRect(IntPtr h,out RECT r);
 [DllImport("user32.dll")]public static extern bool ClientToScreen(IntPtr h,ref POINT p);
 [DllImport("user32.dll")]public static extern bool SetCursorPos(int x,int y);
 [DllImport("user32.dll")]public static extern void mouse_event(uint f,uint x,uint y,uint d,UIntPtr e);
 public struct RECT{public int L,T,R,B;} public struct POINT{public int X,Y;}
}
"@
$root="E:\PCGame\Haizeiwang";$dbg=Join-Path $root "build\Debug"
$crash=Join-Path $dbg "crash_stack.txt"
$cmdFile="C:\Users\24219\AppData\Local\Haizeiwang\haizei_debug_cmd.txt"
$enc=New-Object System.Text.UTF8Encoding($false)
function WC($t){[System.IO.File]::WriteAllText($cmdFile,$t,$enc)}
if(-not(Get-Process mysqld -EA 0)-or -not(Get-Process java -EA 0)){& "$root\tools\start_local_env.ps1"}
function Launch{
 Get-Process Haizeiwang -EA 0|Stop-Process -Force; Start-Sleep 1
 if(Test-Path $crash){[System.IO.File]::Delete($crash)}
 Start-Process -FilePath "cmd.exe" -ArgumentList "/c","Haizeiwang.exe > verify_run.log 2>&1" -WorkingDirectory $dbg -WindowStyle Normal|Out-Null
 $g=$null
 for($i=0;$i-lt45;$i++){$g=Get-Process Haizeiwang -EA 0|?{$_.MainWindowHandle -ne 0}|select -first 1;if($g){break};Start-Sleep 1}
 if(-not $g){Write-Output "LAUNCH_FAIL";return $null}
 $h=$g.MainWindowHandle
 [WP3]::ShowWindow($h,9)|Out-Null;[WP3]::SetWindowPos($h,[IntPtr](-1),0,0,0,0,0x1 -bor 0x2)|Out-Null;[WP3]::SetForegroundWindow($h)|Out-Null
 Start-Sleep -Milliseconds 800
 $cr=New-Object WP3+RECT;[WP3]::GetClientRect($h,[ref]$cr)|Out-Null
 $pt=New-Object WP3+POINT;$pt.X=0;$pt.Y=0;[WP3]::ClientToScreen($h,[ref]$pt)|Out-Null
 [WP3]::SetCursorPos([int]($pt.X+($cr.R-$cr.L)*0.5),[int]($pt.Y+($cr.B-$cr.T)*0.82))|Out-Null
 Start-Sleep -Milliseconds 250
 [WP3]::mouse_event(2,0,0,0,[UIntPtr]::Zero);[WP3]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
 Start-Sleep -Seconds 16
 return $g
}
$pages=@("BuyPropsCountPage","BuyStoneCountPage","CareerStoryPage")
foreach($name in $pages){
 $g=Launch; if(-not $g){Write-Output "FAIL $name";continue}
 # 清除陈旧崩溃栈
 if(Test-Path $crash){[System.IO.File]::Delete($crash)}
 Start-Sleep -Seconds 1
 $t0=Get-Date
 WC ("goto:"+$name)
 Start-Sleep -Seconds 3
 $real=$false
 if(Test-Path $crash){
   $mt=(Get-Item $crash).LastWriteTime
   if($mt -gt $t0){ $real=$true }
 }
 if($real){
   $dst=Join-Path $root ("_tools\crash2_"+$name+".txt")
   Copy-Item $crash $dst -Force
   Write-Output ("=== $name REAL CRASH (fresh) -> $dst ===")
   Get-Content $crash|Select-Object -First 6|ForEach-Object{Write-Output $_}
 } else {
   Write-Output ("=== $name NO_FRESH_CRASH (alive={0}, staleFile={1}) ===" -f (-not $g.HasExited), (Test-Path $crash))
 }
 WC ""
}
Write-Output "DONE"
