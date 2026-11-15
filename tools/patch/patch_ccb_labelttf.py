#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
[haizei] 幂等补丁：修正 ccbi 文本节点取值时的 dynamic_cast 类型。

根因：3.17 的 CCBReader 里 LabelTTFLoader / LabelBMFontLoader 创建的都是
cocos2d::Label（见 CCLabelTTFLoader.h 的 CREATECCNODE_METHOD(cocos2d::Label)），
而老代码用 deprecated 的独立类 CCLabelTTF 做 dynamic_cast -> 恒为 nullptr，
玩家名 / 名称一直显示 ccbi 里的占位文字（NameName、mPlayerName ...）。

兼容层已把 CCLabelBMFont typedef 到 cocos2d::Label，故这里统一改为 CCLabelBMFont*。

只处理「从 ccbi 变量取值」的 dynamic_cast 行；不动 CCLabelTTF::create 真实实例、
BoardCastLabel / ChatPage / Language 的独立 LabelTTF 用法。
"""
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CLASSES = os.path.join(ROOT, "client", "Classes")
NEEDLE = "dynamic_cast<CCLabelTTF* >("
EXCLUDE = {"Gamelua.cpp"}


def patch_file(path):
    with open(path, "r", encoding="utf-8", errors="surrogateescape") as f:
        lines = f.readlines()
    changed = 0
    out = []
    for line in lines:
        if NEEDLE in line and "CCLabelTTF*" in line:
            new = line.replace("CCLabelTTF*", "CCLabelBMFont*")
            if new != line:
                changed += 1
                line = new
        out.append(line)
    if changed:
        with open(path, "w", encoding="utf-8", errors="surrogateescape", newline="") as f:
            f.writelines(out)
    return changed


def main():
    total_files = 0
    total_lines = 0
    for name in sorted(os.listdir(CLASSES)):
        if not name.endswith(".cpp") or name in EXCLUDE:
            continue
        n = patch_file(os.path.join(CLASSES, name))
        if n:
            total_files += 1
            total_lines += n
            print("  %-38s %d" % (name, n))

    # SkillBookLootPage 成员变量也是同一类型契约
    hdr = os.path.join(CLASSES, "SkillBookLootPage.h")
    with open(hdr, "r", encoding="utf-8", errors="surrogateescape") as f:
        text = f.read()
    if "cocos2d::CCLabelTTF* mPlayerName;" in text:
        text = text.replace("cocos2d::CCLabelTTF* mPlayerName;",
                            "cocos2d::CCLabelBMFont* mPlayerName;")
        with open(hdr, "w", encoding="utf-8", errors="surrogateescape", newline="") as f:
            f.write(text)
        total_files += 1
        total_lines += 1
        print("  %-38s %d" % ("SkillBookLootPage.h", 1))

    print("[OK] patched %d lines in %d files" % (total_lines, total_files))
    return 0


if __name__ == "__main__":
    sys.exit(main())
