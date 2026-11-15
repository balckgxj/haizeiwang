"""引擎补丁 #1：3.17.2 的 win32 EditBox 用了 Windows SDK 10 已移除的 GWL_WNDPROC/GWL_USERDATA。
   改为 GWLP_*（64 位下才是正确的 SetWindowLongPtr 参数）。"""
import io
import os

p = r"E:\PCGame\Haizeiwang\engine\cocos2d-x\cocos\ui\UIEditBox\UIEditBoxImpl-win32.cpp"
with io.open(p, "r", encoding="utf-8", newline="") as fh:
    text = fh.read()
before = text
text = text.replace("GWL_WNDPROC", "GWLP_WNDPROC").replace("GWL_USERDATA", "GWLP_USERDATA")
if text != before:
    with io.open(p, "w", encoding="utf-8", newline="") as fh:
        fh.write(text)
    print("patched:", p)
else:
    print("no change:", p)
