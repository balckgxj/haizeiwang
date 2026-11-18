# -*- coding: utf-8 -*-
"""通过 UAC 提权添加 Defender 排除项，执行结果写入日志文件供验证"""
import ctypes
import sys

LOG = r'E:\PCGame\Haizeiwang\tools\frp\defender_result.txt'

def main():
    ps_cmd = (
        'try { Add-MpPreference -ExclusionPath "E:\\PCGame\\Haizeiwang\\tools\\frp"; '
        'Add-MpPreference -ExclusionProcess "frpc.exe"; '
        '"OK" | Out-File -FilePath "E:\\PCGame\\Haizeiwang\\tools\\frp\\defender_result.txt" -Encoding utf8 } '
        'catch { $_.Exception.Message | Out-File -FilePath "E:\\PCGame\\Haizeiwang\\tools\\frp\\defender_result.txt" -Encoding utf8 }'
    )
    ret = ctypes.windll.shell32.ShellExecuteW(
        None, 'runas', 'powershell.exe',
        '-NoProfile -Command "' + ps_cmd + '"',
        None, 0
    )
    print('ShellExecuteW ret =', ret, '(>30 表示 UAC 已弹出，请点“是”)')

if __name__ == '__main__':
    main()
