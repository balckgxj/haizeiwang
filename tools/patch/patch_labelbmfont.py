# -*- coding: utf-8 -*-
"""
定点补丁：把 2.x 的 CCLabelBMFont::create(text, fnt, width) 调用改接到
兼容层的 cocos2d::createLabelBMFontCompat（见 compat/haizei_compat.h）。

幂等：已替换过则跳过。
"""
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "client", "Classes"))
OLD = "CCLabelBMFont::create("
NEW = "cocos2d::createLabelBMFontCompat("

count = 0
for fn in sorted(os.listdir(ROOT)):
    if not fn.lower().endswith((".cpp", ".h")):
        continue
    path = os.path.join(ROOT, fn)
    with open(path, "r", encoding="latin1") as f:
        src = f.read()
    if OLD not in src:
        continue
    n = src.count(OLD)
    src = src.replace(OLD, NEW)
    with open(path, "w", encoding="latin1", newline="") as f:
        f.write(src)
    count += n
    print("%-46s %d" % (fn, n))

print("replaced:", count)
