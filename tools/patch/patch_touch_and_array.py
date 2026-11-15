"""针对性补丁（3.x 已移除的 2.x 接口）：

1. Director::getTouchDispatcher() —— 3.x 改用 EventDispatcher。
   老代码只在这 3 个页面里用它“屏蔽模态层下面的触摸”，
   3.x 里模态层靠遮罩 Layer 拦截事件即可，这里直接注释掉。
2. CCArray* / CCARRAY_FOREACH —— 3.x 用 cocos2d::Vector。
"""
import io
import os
import re

CLASSES = r"E:\PCGame\Haizeiwang\client\Classes"

TOUCH_FILES = ["AdventureContinuePage.cpp", "AdventureInvitePage.cpp", "LevelUpRewardPage.cpp"]

def read(p):
    with io.open(p, "r", encoding="gbk", errors="surrogateescape", newline="") as fh:
        return fh.readlines()

def write(p, lines):
    with io.open(p, "w", encoding="gbk", errors="surrogateescape", newline="") as fh:
        fh.writelines(lines)

def patch_touch():
    for f in TOUCH_FILES:
        p = os.path.join(CLASSES, f)
        if not os.path.exists(p):
            print("skip missing", f)
            continue
        lines = read(p)
        out, i, n = [], 0, 0
        while i < len(lines):
            line = lines[i]
            if "getTouchDispatcher()" in line and not line.lstrip().startswith("//"):
                out.append("    /* [migrate] 3.x 无 TouchDispatcher，模态屏蔽交给遮罩层 */\n")
                j = i
                while j < len(lines) and j < i + 6:
                    cur = lines[j]
                    out.append("    // " + cur.lstrip() if cur.strip() else cur)
                    stop = ("setSwallowsTouches" in cur) or ("pTh" in cur and ";" in cur) or ("pHandler" in cur and ";" in cur)
                    j += 1
                    if stop and j > i + 1:
                        break
                i = j
                n += 1
                continue
            out.append(line)
            i += 1
        if n:
            write(p, out)
        print("%s: patched %d block(s)" % (f, n))

def patch_array():
    p = os.path.join(CLASSES, "CCBLuaContainer.cpp")
    text = "".join(read(p))
    before = text
    text = text.replace("static CCBLuaContainer* _searchChild(cocos2d::CCArray* childern, int tag)",
                        "static CCBLuaContainer* _searchChild(const cocos2d::Vector<cocos2d::Node*>& childern, int tag)")
    text = text.replace("CCARRAY_FOREACH(childern, child)",
                        "for (auto child : childern)")
    if text != before:
        write(p, text.splitlines(True))
        print("CCBLuaContainer.cpp: patched _searchChild")
    else:
        print("CCBLuaContainer.cpp: no change")

if __name__ == "__main__":
    patch_touch()
    patch_array()
