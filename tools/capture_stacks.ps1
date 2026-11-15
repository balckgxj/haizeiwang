# 捕获 15 个崩溃页各自的崩溃栈 / 断言文本
$ErrorActionPreference="SilentlyContinue"
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type @"
using System;using System.Runtime.InteropServices;
public class WP4{
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
$log=Join-Path $dbg "verify_run.log"
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
 [WP4]::ShowWindow($h,9)|Out-Null;[WP4]::SetWindowPos($h,[IntPtr](-1),0,0,0,0,0x1 -bor 0x2)|Out-Null;[WP4]::SetForegroundWindow($h)|Out-Null
 Start-Sleep -Milliseconds 800
 $cr=New-Object WP4+RECT;[WP4]::GetClientRect($h,[ref]$cr)|Out-Null
 $pt=New-Object WP4+POINT;$pt.X=0;$pt.Y=0;[WP4]::ClientToScreen($h,[ref]$pt)|Out-Null
 [WP4]::SetCursorPos([int]($pt.X+($cr.R-$cr.L)*0.5),[int]($pt.Y+($cr.B-$cr.T)*0.82))|Out-Null
 Start-Sleep -Milliseconds 250
 [WP4]::mouse_event(2,0,0,0,[UIntPtr]::Zero);[WP4]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
 Start-Sleep -Seconds 16
 return $g
}
$pages=@("AboutPage","DiscipleRecruitPage","FightPage","MemberPage","NewActivePromptPage","NewActivePromptToolPage","PlayerInfPage","SkillChangePage","StoneInlaidPage","TeacherTeachResultPage","TeamBuffUpgradePage","TitleGetNewPage","TitleLVUpPage","TranExpPreviewPage","WorldBossRankPage")
foreach($name in $pages){
 $g=Launch; if(-not $g){Write-Output "FAIL $name";continue}
 if(Test-Path $crash){[System.IO.File]::Delete($crash)}
 Start-Sleep -Seconds 1
 $t0=Get-Date
 WC ("goto:"+$name)
 Start-Sleep -Seconds 4
 $alive=(-not $g.HasExited)
 $fresh=$false; if(Test-Path $crash){ if((Get-Item $crash).LastWriteTime -gt $t0){$fresh=$true} }
 # 抓日志尾部（断言文本）
 $tail=""
 if(Test-Path $log){ $tail=(Get-Content $log -Tail 25 -Encoding utf8 -EA 0) -join "`n" }
 $assert=($tail -split "`n" | Where-Object { $_ -match "Assert|abort|failed" }) -join "`n"
 # 保存
 if($fresh){ Copy-Item $crash (Join-Path $root ("_tools\stack_"+$name+".txt")) -Force; Write-Output ("=== $name : UNHANDLED (stack saved) alive=$alive ===") }
 elseif(-not $alive){ Write-Output ("=== $name : ABORT/CRASH process exited alive=$alive ===") }
 else { Write-Output ("=== $name : NO CRASH (alive=$alive) ===") }
 if($assert){ $assert | Out-File (Join-Path $root ("_tools\assert_"+$name+".txt")) -Encoding utf8 }
 WC ""
}
Write-Output "DONE"
