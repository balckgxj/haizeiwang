"""重做 3 个页面的 TouchDispatcher 处理。

直接从老工程重新拷贝这 3 个文件，然后整段删除
    //--begin xinzheng ... 之后跟着的那个大括号代码块
（2.x 用 TouchDispatcher 调 CCScrollView 的吃触摸行为，3.x 没有这个 API，
  改由遮罩层/事件冒泡处理）
"""
import io
import os
import shutil

OLD = r"E:\BaiduNetdiskDownload\(SY-096)草M船Z\src\src\client\Game\Classes"
NEW = r"E:\PCGame\Haizeiwang\client\Classes"
FILES = ["AdventureContinuePage.cpp", "AdventureInvitePage.cpp", "LevelUpRewardPage.cpp"]
MARK = "//--begin xinzheng"

for f in FILES:
    src, dst = os.path.join(OLD, f), os.path.join(NEW, f)
    shutil.copyfile(src, dst)
    lines = io.open(dst, encoding="gbk", errors="surrogateescape", newline="").readlines()
    idx = [i for i, l in enumerate(lines) if MARK in l]
    if not idx:
        print(f + ": no marker")
        continue
    start = idx[0]
    # 找到紧随其后的 '{'
    j = start + 1
    while j < len(lines) and lines[j].strip() != "{":
        j += 1
    depth, end = 0, None
    for k in range(j, len(lines)):
        depth += lines[k].count("{") - lines[k].count("}")
        if depth == 0 and k > j:
            end = k
            break
    if end is None:
        print(f + ": unbalanced, skip")
        continue
    new = lines[:start] + ["\t// [migrate] 删除 2.x TouchDispatcher 逻辑（3.x 无此 API，改由遮罩层处理）\n"] + lines[end + 1:]
    io.open(dst, "w", encoding="gbk", errors="surrogateescape", newline="").writelines(new)
    print("%s: removed lines %d-%d" % (f, start + 1, end + 1))
