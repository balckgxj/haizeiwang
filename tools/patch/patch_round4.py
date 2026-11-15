"""第四轮：批量处理剩余 2.x 差异。"""
import io
import os
import re

D = r"E:\PCGame\Haizeiwang\client\Classes"

def load(f):
    return io.open(os.path.join(D, f), encoding="gbk", errors="surrogateescape", newline="").read()

def save(f, t):
    io.open(os.path.join(D, f), "w", encoding="gbk", errors="surrogateescape", newline="").write(t)

REPL = [
    # 3.x Action 的 protected 成员改名
    ("m_pTarget", "_target"),
    # 3.x Sprite 的 quad 改成 getter
    ("m_sQuad", "getQuad()"),
    # Vector 接口
    ("->objectAtIndex(", "->at("),
    (".objectAtIndex(", ".at("),
    # 2.x 已移除的全局
    ("cocos2d::Application::getInstance()->purgeCachedData()", "(void)0"),
    ("addSpriteFramesNameWithFile(", "addSpriteFramesWithFile("),
    # LabelBMFont::setString 只接受 1 个参数
    ("->setString(str.c_str(),true)", "->setString(str.c_str())"),
    ("->setString(str.c_str(), true)", "->setString(str.c_str())"),
    ("->setString(str.c_str(),false)", "->setString(str.c_str())"),
    ("->setString(str.c_str(), false)", "->setString(str.c_str())"),
]

total = {}
for f in os.listdir(D):
    if not f.endswith((".cpp", ".h")):
        continue
    t = load(f)
    orig = t
    for a, b in REPL:
        if a in t:
            total[a] = total.get(a, 0) + t.count(a)
            t = t.replace(a, b)
    if t != orig:
        save(f, t)

for k, v in total.items():
    print("%-56s %d" % (k, v))

# 打印两个待确认位置
for f, nums in {"EmbattlePage.h": [71, 72, 73, 74], "PopupPage.cpp": [195, 196, 197, 198, 199]}.items():
    lines = io.open(os.path.join(D, f), encoding="gbk", errors="replace").read().splitlines()
    print("===== " + f)
    for n in nums:
        if 1 <= n <= len(lines):
            print("%4d| %s" % (n, lines[n - 1]))
