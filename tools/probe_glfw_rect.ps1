# 探测 GLFW30 游戏窗口精确矩形 + 鼠标位置换算参考
Add-Type @'
using System;
using System.Text;
using System.Runtime.InteropServices;
public class WP {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  public struct RECT { public int L, T, R, B; }
  public struct POINT { public int X, Y; }
}
'@
$found = $false
$cb = [WP+EnumProc]{
    param($h, $l)
    $sb = New-Object System.Text.StringBuilder 256
    [void][WP]::GetClassNameW($h, $sb, 256)
    if ($sb.ToString() -eq 'GLFW30' -and [WP]::IsWindowVisible($h)) {
        $r = New-Object WP+RECT; [void][WP]::GetWindowRect($h, [ref]$r)
        $cr = New-Object WP+RECT; [void][WP]::GetClientRect($h, [ref]$cr)
        $pt = New-Object WP+POINT; $pt.X = 0; $pt.Y = 0; [void][WP]::ClientToScreen($h, [ref]$pt)
        Write-Output ("GLFW30 hwnd={0} WINRECT=({1},{2})-({3},{4}) size={5}x{6}" -f $h, $r.L, $r.T, $r.R, $r.B, ($r.R-$r.L), ($r.B-$r.T))
        Write-Output ("  CLIENT size={0}x{1} clientOrigin=({2},{3})" -f $cr.R, $cr.B, $pt.X, $pt.Y)
        $script:found = $true
    }
    return $true
}
[void][WP]::EnumWindows($cb, [IntPtr]::Zero)
if (-not $found) { Write-Output 'GLFW30_NOT_FOUND' }
