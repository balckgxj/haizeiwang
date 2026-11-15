# UI 修复实跑验证 · 第一轮：登录 -> 主城 -> 逐页截图采集
# 覆盖：问题1(主城) 问题2(阵容MemberPage) 问题4(冒险AdventurePage) 问题5(纵向滚动各页) 问题3(FightPage)
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
using System.Runtime.InteropServices;
public class U5 {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  public struct RECT { public int L, T, R, B; }
  public struct POINT { public int X, Y; }
  public const uint DOWN = 0x0002, UP = 0x0004;
}
'@

function Get-Client {
    $g = Get-Process Haizeiwang -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if (-not $g) { return $null }
    $h = $g.MainWindowHandle
    [void][U5]::SetForegroundWindow($h)
    Start-Sleep -Milliseconds 400
    $cr = New-Object U5+RECT; [void][U5]::GetClientRect($h, [ref]$cr)
    $pt = New-Object U5+POINT; $pt.X = 0; $pt.Y = 0
    [void][U5]::ClientToScreen($h, [ref]$pt)
    return @{ H = $h; X = $pt.X; Y = $pt.Y; W = $cr.R; Ht = $cr.B }
}
# 设计坐标(320x480, 左下原点) -> 屏幕坐标
function ToScreen($c, [int]$dx, [int]$dy) { return @( ($c.X + $dx), ($c.Y + ($c.Ht - $dy)) ) }
function Click($c, [int]$dx, [int]$dy) {
    $p = ToScreen $c $dx $dy
    [void][U5]::SetCursorPos($p[0], $p[1]); Start-Sleep -Milliseconds 150
    [U5]::mouse_event([U5]::DOWN,0,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 80
    [U5]::mouse_event([U5]::UP,0,0,0,[UIntPtr]::Zero)
    Write-Output ("CLICK design=({0},{1}) screen=({2},{3})" -f $dx,$dy,$p[0],$p[1])
}
function Drag($c, [int]$x1, [int]$y1, [int]$x2, [int]$y2) {
    $p1 = ToScreen $c $x1 $y1; $p2 = ToScreen $c $x2 $y2
    [void][U5]::SetCursorPos($p1[0], $p1[1]); Start-Sleep -Milliseconds 200
    [U5]::mouse_event([U5]::DOWN,0,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 120
    for ($i = 1; $i -le 12; $i++) {
        $nx = $p1[0] + ($p2[0]-$p1[0]) * $i / 12
        $ny = $p1[1] + ($p2[1]-$p1[1]) * $i / 12
        [void][U5]::SetCursorPos([int]$nx, [int]$ny); Start-Sleep -Milliseconds 40
    }
    Start-Sleep -Milliseconds 150
    [U5]::mouse_event([U5]::UP,0,0,0,[UIntPtr]::Zero)
    Write-Output ("DRAG ({0},{1})->({2},{3})" -f $x1,$y1,$x2,$y2)
}
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

# ---- 启动 ----
Get-Process Haizeiwang -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 700
Remove-Item $log -ErrorAction SilentlyContinue
Start-Process -FilePath 'cmd.exe' -ArgumentList '/c','Haizeiwang.exe > verify_run.log 2>&1' `
    -WorkingDirectory $dbg -WindowStyle Normal | Out-Null
$cl = $null
for ($i = 0; $i -lt 45; $i++) { $cl = Get-Client; if ($cl) { break }; Start-Sleep -Seconds 1 }
if (-not $cl) { Write-Output 'GLWINDOW_NOT_FOUND'; exit 1 }
Write-Output ("CLIENT origin=({0},{1}) size={2}x{3}" -f $cl.X,$cl.Y,$cl.W,$cl.Ht)

# ---- 登录（账号密码表单）----
Click $cl 168 303; Start-Sleep -Milliseconds 400
[System.Windows.Forms.SendKeys]::SendWait('heigui'); Start-Sleep -Milliseconds 400
Click $cl 168 260; Start-Sleep -Milliseconds 400
[System.Windows.Forms.SendKeys]::SendWait('123456'); Start-Sleep -Milliseconds 400
Click $cl 168 188
Start-Sleep -Seconds 9
Shot 'ui_01_after_login.png'

# ---- 进入游戏 ----
$cl = Get-Client
Click $cl 168 100
Start-Sleep -Seconds 10
Shot 'ui_02_main_city.png'

# ---- 问题1：点击主城上阵人物 -> 应跳阵容页 ----
$cl = Get-Client
Click $cl 160 100        # 主城布阵按钮/人物区（第一轮先采状态）
Start-Sleep -Seconds 4
Shot 'ui_03_main_click_crew.png'

# ---- 逐页采集 ----
foreach ($pg in @('MemberPage','AdventurePage','HandbookPage','PackPreviewPage','FriendsPage','SettingsPage','FightPage')) {
    $cl = Get-Client
    [System.IO.File]::WriteAllText($cmdFile, "goto:$pg")
    Write-Output "CMD: goto:$pg"
    Start-Sleep -Seconds 4
    Shot ("ui_pg_{0}.png" -f $pg)
}

Write-Output '=== LOG key lines ==='
if (Test-Path $log) {
    Get-Content $log | Where-Object { $_ -match 'goto|LoginPage|showEnter|Battle|Fight|SpriteFrame null|not find|MISS' } | Select-Object -Last 60
}
Write-Output "ALIVE: $((Get-Process Haizeiwang -ErrorAction SilentlyContinue) -ne $null)"
