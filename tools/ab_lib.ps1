# ---------------------------------------------------------------------------
# A/B 对照驱动库（老 Game.exe / 新 Haizeiwang.exe 通用）
#
# 之前 verify_*.ps1 的 ToScreen() 把 GetWindowRect() 的虚拟坐标当物理像素用，
# 且假设客户区恒为 335x480 + 30px 标题栏，在 150% DPI 下点击整体偏移。
# 本库统一为物理像素坐标：
#   1) SetProcessDPIAware() 让脚本进程与截图坐标系一致
#   2) GetClientRect + ClientToScreen 精确得到客户区屏幕矩形
#   3) 所有操作用客户区归一化坐标 u,v ∈ [0,1]，两端窗口尺寸不同也能对齐
# ---------------------------------------------------------------------------

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public class AB {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, UIntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, UIntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int idx);
  [DllImport("kernel32.dll")] public static extern IntPtr GetCurrentProcess();

  public struct RECT { public int L, T, R, B; }
  public struct POINT { public int X, Y; }
  public const uint DOWN = 0x0002, UP = 0x0004, MOVE = 0x0001;
  public const uint WM_LBUTTONDOWN = 0x0201, WM_LBUTTONUP = 0x0202, WM_MOUSEMOVE = 0x0200;
  public const uint MK_LBUTTON = 0x0001;

  public static List<IntPtr> WindowsOfPid(uint pid) {
    var list = new List<IntPtr>();
    EnumWindows((h, l) => {
      uint p; GetWindowThreadProcessId(h, out p);
      if (p == pid && IsWindowVisible(h)) list.Add(h);
      return true;
    }, IntPtr.Zero);
    return list;
  }
  public static string Class(IntPtr h) { var s = new StringBuilder(256); GetClassNameW(h, s, 256); return s.ToString(); }
  public static string Title(IntPtr h) { var s = new StringBuilder(512); GetWindowTextW(h, s, 512); return s.ToString(); }
}
'@

# 必须在创建任何 HDC/窗口前调用；返回 false 表示系统已替我们设为 aware
$script:abDpiSet = [AB]::SetProcessDPIAware()

function Get-ABMetrics {
    return @{
        DpiAwareCall = $script:abDpiSet
        ScreenW      = [AB]::GetSystemMetrics(0)
        ScreenH      = [AB]::GetSystemMetrics(1)
        BoundsW      = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
        BoundsH      = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
    }
}

function Find-ABWindow([string]$procName) {
    $procs = @(Get-Process -Name $procName -ErrorAction SilentlyContinue)
    if ($procs.Count -eq 0) { return $null }
    $best = $null; $bestArea = 0
    foreach ($p in $procs) {
        foreach ($h in [AB]::WindowsOfPid([uint32]$p.Id)) {
            $cls = [AB]::Class($h)
            if ($cls -eq 'ConsoleWindowClass' -or $cls -like '*Console*') { continue }
            $r = New-Object AB+RECT
            [void][AB]::GetClientRect($h, [ref]$r)
            $w = $r.R - $r.L; $ht = $r.B - $r.T
            if ($w -lt 100 -or $ht -lt 100) { continue }
            if ($w * $ht -gt $bestArea) {
                $bestArea = $w * $ht
                $best = @{ H = $h; W = $w; H2 = $ht; Cls = $cls; Title = [AB]::Title($h); Pid = $p.Id }
            }
        }
    }
    return $best
}

function Get-ABClient([string]$procName) {
    $w = Find-ABWindow $procName
    if (-not $w) { return $null }
    [void][AB]::SetForegroundWindow($w.H)
    Start-Sleep -Milliseconds 220
    $p = New-Object AB+POINT
    $p.X = 0; $p.Y = 0
    [void][AB]::ClientToScreen($w.H, [ref]$p)
    $wr = New-Object AB+RECT
    [void][AB]::GetWindowRect($w.H, [ref]$wr)
    return @{
        H       = $w.H
        X       = $p.X                 # 客户区左上角：物理屏幕像素
        Y       = $p.Y
        W       = $w.W                 # 客户区宽高：物理像素
        Height  = $w.H2
        WinL    = $wr.L; WinT = $wr.T; WinR = $wr.R; WinB = $wr.B
        Cls     = $w.Cls; Title = $w.Title; Pid = $w.Pid
        Dpi     = [AB]::GetDpiForWindow($w.H)
    }
}

# 归一化坐标 -> 物理屏幕坐标。u,v 为 0..1，v=0 是客户区顶部。
function AB-Screen($c, [double]$u, [double]$v) {
    return @( [int]($c.X + $c.W * $u), [int]($c.Y + $c.Height * $v) )
}
# 设计坐标（左上原点、设计尺寸 dw x dh，y 向下）-> 归一化
function AB-Design($c, [double]$x, [double]$y, [double]$dw, [double]$dh) {
    return @( ($x / $dw), ($y / $dh) )
}

function AB-Click($c, [double]$u, [double]$v) {
    $p = AB-Screen $c $u $v
    [void][AB]::SetCursorPos($p[0], $p[1]); Start-Sleep -Milliseconds 140
    [AB]::mouse_event([AB]::DOWN,0,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 70
    [AB]::mouse_event([AB]::UP,0,0,0,[UIntPtr]::Zero)
    return $p
}

function AB-Drag($c, [double]$u1, [double]$v1, [double]$u2, [double]$v2) {
    $p1 = AB-Screen $c $u1 $v1; $p2 = AB-Screen $c $u2 $v2
    [void][AB]::SetCursorPos($p1[0], $p1[1]); Start-Sleep -Milliseconds 220
    [AB]::mouse_event([AB]::DOWN,0,0,0,[UIntPtr]::Zero); Start-Sleep -Milliseconds 110
    for ($i = 1; $i -le 18; $i++) {
        $nx = [int]($p1[0] + ($p2[0]-$p1[0])*$i/18)
        $ny = [int]($p1[1] + ($p2[1]-$p1[1])*$i/18)
        [void][AB]::SetCursorPos($nx,$ny); Start-Sleep -Milliseconds 35
    }
    Start-Sleep -Milliseconds 180
    [AB]::mouse_event([AB]::UP,0,0,0,[UIntPtr]::Zero)
}

function AB-Key([string]$keys) {
    [System.Windows.Forms.SendKeys]::SendWait($keys)
    Start-Sleep -Milliseconds 120
}

# [haizei] 真正的"鼠标点住→按住拖动→松手"序列：直接给游戏窗口发客户端坐标的
# WM_LBUTTONDOWN / WM_MOUSEMOVE(MK_LBUTTON) / WM_LBUTTONUP。相比 mouse_event+SetCursorPos，
# 这种方式不会被系统的移动合并(coalescing)吃掉中间点，cocos2d-x 的滚动视图能稳定收到
# 每个增量 touchMoved，拖到哪就停哪。坐标用客户区归一化 u,v 换算成客户区像素。
function AB-DragMsg($c, [double]$u1, [double]$v1, [double]$u2, [double]$v2, [int]$steps = 20) {
    $x1 = [int]($c.W * $u1);        $y1 = [int]($c.Height * $v1)
    $x2 = [int]($c.W * $u2);        $y2 = [int]($c.Height * $v2)
    $h  = $c.H
    # 让真实光标也同步到起点，避免任何依赖 GetCursorPos 的代码读错位置
    [void][AB]::SetCursorPos($c.X + $x1, $c.Y + $y1); Start-Sleep -Milliseconds 120
    # 按下（点住）
    [void][AB]::SendMessage($h, [AB]::WM_LBUTTONDOWN, [UIntPtr][AB]::MK_LBUTTON,
                            [IntPtr](($y1 -shl 16) -bor $x1))
    Start-Sleep -Milliseconds 130
    # 按住拖动（每个中间点都带 MK_LBUTTON 的 MOVE）
    for ($i = 1; $i -le $steps; $i++) {
        $xi = [int]($x1 + ($x2 - $x1) * $i / $steps)
        $yi = [int]($y1 + ($y2 - $y1) * $i / $steps)
        [void][AB]::SetCursorPos($c.X + $xi, $c.Y + $yi)
        [void][AB]::SendMessage($h, [AB]::WM_MOUSEMOVE, [UIntPtr][AB]::MK_LBUTTON,
                                [IntPtr](($yi -shl 16) -bor $xi))
        Start-Sleep -Milliseconds 30
    }
    Start-Sleep -Milliseconds 120
    # 松手
    [void][AB]::SendMessage($h, [AB]::WM_LBUTTONUP, [UIntPtr]::Zero,
                            [IntPtr](($y2 -shl 16) -bor $x2))
}

# 只截游戏客户区（不含标题栏/桌面），便于两端逐像素对比
function AB-Shot($c, [string]$path) {
    if (-not $c) { return $false }
    $bmp = New-Object System.Drawing.Bitmap $c.W, $c.Height
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($c.X, $c.Y, 0, 0, $bmp.Size)
    $dir = Split-Path -Parent $path
    if ($dir -and -not (Test-Path $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose(); $bmp.Dispose()
    return $true
}

function AB-Wait([string]$procName, [int]$sec) {
    for ($i = 0; $i -lt $sec; $i++) {
        $c = Get-ABClient $procName
        if ($c) { return $c }
        Start-Sleep -Seconds 1
    }
    return $null
}

function AB-Alive([string]$procName) {
    return [bool](Get-Process -Name $procName -ErrorAction SilentlyContinue)
}

function AB-Stop([string]$procName) {
    Get-Process -Name $procName -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 600
}
