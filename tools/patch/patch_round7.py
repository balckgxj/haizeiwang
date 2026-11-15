"""第七轮：收尾。"""
import io
import os
import re

D = r"E:\PCGame\Haizeiwang\client\Classes"
B = r"E:\PCGame\Haizeiwang\platform_bridge"

def load(p):
    return io.open(p, encoding="gbk", errors="surrogateescape", newline="").read()

def save(p, t):
    io.open(p, "w", encoding="gbk", errors="surrogateescape", newline="").write(t)

# 1) 平台桥接文件强制带上 windows.h（Win32 MessageBox）
for f in ["libPlatform\\win32\\lib91.cpp", "libPlatform\\win32\\libAG.cpp",
          "libPlatform\\win32\\libPP.cpp", "libPlatform\\win32\\libTB.cpp",
          "libOS\\win32\\libOS.cpp"]:
    p = os.path.join(B, f)
    if not os.path.exists(p):
        continue
    t = load(p)
    if "#include <windows.h>" not in t:
        save(p, "#include <windows.h>\n" + t)
        print("windows.h ->", f)

# 2) ContinueLoginPage 的 CallFuncN lambda：目标就是 this（CardContent）
p = os.path.join(D, "ContinueLoginPage.cpp")
t = load(p)
t, n = re.subn(r"\(\(([^()]+)\)->(\w+)::(\w+)\(haizeiNode\);",
               r"this->\3(haizeiNode);", t)
save(p, t)
print("ContinueLoginPage lambda fixed:", n)

# 3) LoadingFrame 的 setString(x, bool)
p = os.path.join(D, "LoadingFrame.cpp")
t = load(p)
t2, n = re.subn(r"->setString\(([^,]+),\s*(?:true|false)\)", r"->setString(\1)", t)
save(p, t2)
print("LoadingFrame setString:", n)
