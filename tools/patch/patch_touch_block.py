"""把 3 个页面里“取 TouchDispatcher 再 dynamic_cast”的整段代码块整体注释掉。

3.x 已经没有 CCTouchDispatcher，模态层屏蔽触摸改为由遮罩 Layer 处理。
"""
import io
import os

CLASSES = r"E:\PCGame\Haizeiwang\client\Classes"
FILES = ["AdventureContinuePage.cpp", "AdventureInvitePage.cpp", "LevelUpRewardPage.cpp"]
MARK = "[migrate] 3.x 无 TouchDispatcher"

for f in FILES:
    p = os.path.join(CLASSES, f)
    if not os.path.exists(p):
        print("skip", f)
        continue
    lines = io.open(p, encoding="gbk", errors="surrogateescape", newline="").readlines()
    idx = [i for i, l in enumerate(lines) if MARK in l]
    if not idx:
        print(f + ": no marker")
        continue
    i = idx[0]
    # 往上找到本块的起始 '{'
    start = i
    while start > 0 and lines[start].strip() != "{":
        start -= 1
    depth = 0
    end = None
    for j in range(start, len(lines)):
        depth += lines[j].count("{") - lines[j].count("}")
        if depth <= 0 and j > start:
            end = j
            break
    if end is None:
        print(f + ": unbalanced, skip")
        continue
    block = ("\t/* [migrate] 3.x 无 TouchDispatcher：原代码把 CCScrollView 的触摸"
             "屏蔽掉，3.x 由遮罩层处理\n" + "".join(lines[start:end + 1]) + "\t*/\n")
    new_lines = lines[:start] + [block] + lines[end + 1:]
    io.open(p, "w", encoding="gbk", errors="surrogateescape", newline="").writelines(new_lines)
    print("%s: commented lines %d-%d" % (f, start + 1, end + 1))
