# -*- coding: utf-8 -*-
"""
老工程(2.1.3) / 新工程(3.17.2) 功能入口逐项对照。

按六类功能点分别提取，做老→新双向集合比对：
  page   : REGISTER_PAGE("X")                 页面注册
  button : onMenuItemAction 里的 itemName=="X" 按钮/交互分支
  jump   : pushPage/goto/changePage 等页面跳转目标
  packet : 协议 opcode / send / onMessage 分支
  ccbi   : loadCcbiFile / createAndLoad 加载的界面资源
  method : 类成员函数定义（C++ 方法签名）

另外对每个文件比对「字符串字面量多重集」，可捕获任何资源名、
功能名、常量被改动/删除的情况（API 适配通常不改变字符串）。

用法:
    python tools/audit_function_parity.py            # 打印摘要
    python tools/audit_function_parity.py --json    # 导出 _tools/parity_result.json
    python tools/audit_function_parity.py --diff    # 导出 _tools/parity_full.diff
"""
from __future__ import print_function

import os
import re
import sys
import json
import difflib
import collections

OLD = r"E:\BaiduNetdiskDownload\(SY-096)草M船Z\src\src\client\Game"
NEW = r"E:\PCGame\Haizeiwang\client"
OLD_CLASSES = os.path.join(OLD, "Classes")
NEW_CLASSES = os.path.join(NEW, "Classes")
OLD_RES = os.path.join(OLD, "proj.android", "antbuild", "anzhi", "assets")
NEW_RES = os.path.join(NEW, "Resources")
OUT = r"E:\PCGame\Haizeiwang\_tools"

CODE_EXT = {".cpp", ".h", ".cc"}


def walk(root, exts=None):
    out = {}
    if not os.path.isdir(root):
        return out
    for dp, dn, fn in os.walk(root):
        for f in fn:
            if exts and os.path.splitext(f)[1].lower() not in exts:
                continue
            p = os.path.join(dp, f)
            out[os.path.relpath(p, root).replace("\\", "/")] = p
    return out


def read(p):
    return open(p, "r", encoding="utf-8", errors="replace").read()


# ---------- 功能点提取 ----------

RE_REGISTER = re.compile(r'REGISTER_PAGE\s*\(\s*"([^"]+)"')
RE_BUTTON = re.compile(r'itemName\s*==\s*"([^"]+)"')
RE_BUTTON2 = re.compile(r'==\s*itemName|\.compare\s*\(')  # 仅用于统计
RE_CCBI = re.compile(r'(?:loadCcbiFile|createAndLoad|CCBReader|readNodeGraphFromFile)\s*\([^)]*?"([^"]+\.ccbi?)"')
RE_CCBI_ANY = re.compile(r'"([A-Za-z0-9_/\-]+\.ccbi?)"')
RE_JUMP = re.compile(r'(?:pushPage|gotoPage|changePage|replacePage|popPage|showPage|openPage|switchPage)\s*\([^)]*?"([^"]+)"')
RE_PAGE_LIT = re.compile(r'"([A-Za-z0-9_]+Page)"')
RE_PACKET = re.compile(r'(?:sendPacket|sendMessage|Send|onMessage|handleMessage)\s*\([^;]{0,120}?\b(\d{2,5})\b')
RE_OPCODE = re.compile(r'\b(?:opcode|OPCODE|cmd|CMD|msgId|MSG_ID)\s*[=:]=?\s*(\d{2,5})')
RE_CASE = re.compile(r'case\s+(\d{2,5})\s*:')
RE_METHOD = re.compile(r'^\s*(?:[\w:<>,\*&\s]+?)\b([A-Za-z_]\w*)::([A-Za-z_]\w*)\s*\([^;]*?\)\s*(?:const\s*)?\{', re.M)
RE_STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')
RE_SINGLE = re.compile(r"'((?:[^'\\]|\\.)*)'")

# 纯 API 适配引入的字符串（白名单，不算功能差异）
API_NOISE = {
    "cocos2d", "cocos2d-x", "CCLabelBMFont", "Label", "ui", "Sprite", "Node",
    "ClippingNode", "Stencil", "DrawNode", "GLProgram", "GLProgramState",
    "ccShader_PositionTextureColor_noMVP", "ccShader_PositionTexture",
    "CC_Texture0", "Texture2D", "ui::ScrollView", "ScrollView",
}


def strip_comments(src):
    """去掉 // 行注释与 /* */ 块注释，但保留字符串。用于「生效代码」比对。"""
    out = []
    i = 0
    n = len(src)
    state = "code"
    while i < n:
        c = src[i]
        nx = src[i + 1] if i + 1 < n else ""
        if state == "code":
            if c == '"':
                state = "str"
                out.append(c)
            elif c == "'":
                state = "chr"
                out.append(c)
            elif c == "/" and nx == "/":
                state = "line"
                i += 1
            elif c == "/" and nx == "*":
                state = "block"
                i += 1
            else:
                out.append(c)
        elif state == "str":
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(src[i + 1]); i += 1
            elif c == '"':
                state = "code"
        elif state == "chr":
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(src[i + 1]); i += 1
            elif c == "'":
                state = "code"
        elif state == "line":
            if c == "\n":
                out.append(c); state = "code"
        elif state == "block":
            if c == "*" and nx == "/":
                state = "code"; i += 1
            elif c == "\n":
                out.append(c)
        i += 1
    return "".join(out)


def comment_lines(src):
    """返回被注释掉的老代码行（去掉 // 前缀），用于发现「功能被停用」。"""
    res = []
    for ln in src.splitlines():
        s = ln.strip()
        if s.startswith("//") and not s.startswith("///"):
            body = s[2:].strip()
            if any(k in body for k in ("(", ")", ";", "=", "->")) and len(body) > 12:
                res.append(body)
    return res


def extract(src, path):
    eff = strip_comments(src)
    d = {}
    d["page"] = set(RE_REGISTER.findall(eff))
    d["button"] = set(RE_BUTTON.findall(eff))
    d["jump"] = set(RE_JUMP.findall(eff))
    d["ccbi"] = set(RE_CCBI.findall(eff)) | set(RE_CCBI_ANY.findall(eff))
    d["pagelit"] = set(RE_PAGE_LIT.findall(eff))
    d["packet"] = set(RE_PACKET.findall(eff)) | set(RE_OPCODE.findall(eff)) | set(RE_CASE.findall(eff))
    d["method"] = set("%s::%s" % (a, b) for a, b in RE_METHOD.findall(eff))
    # 字符串：只保留像功能名的（含 / . _ 或 Page/Button/on 前缀），过滤纯文本
    ss = set()
    for s in RE_STRING.findall(eff):
        if len(s) < 2 or s in API_NOISE:
            continue
        if re.search(r'\.(ccbi|png|plist|fnt|mp3|txt|cfg|el|sha)|/|Page|Button|_|on[A-Z]|^\d', s):
            ss.add(s)
    d["string"] = ss
    d["commented"] = set(comment_lines(src))
    return d


def main():
    want_json = "--json" in sys.argv
    want_diff = "--diff" in sys.argv

    oc = walk(OLD_CLASSES, CODE_EXT)
    nc = walk(NEW_CLASSES, CODE_EXT)
    only_old = sorted(set(oc) - set(nc))
    only_new = sorted(set(nc) - set(oc))
    common = sorted(set(oc) & set(nc))

    kinds = ["page", "button", "jump", "ccbi", "pagelit", "packet", "method", "string"]
    old_all = collections.defaultdict(set)
    new_all = collections.defaultdict(set)
    file_diffs = []
    changed = []
    full_diff = []

    for rel in common:
        a, b = read(oc[rel]), read(nc[rel])
        if a == b:
            continue
        changed.append(rel)
        if want_diff:
            full_diff.extend(difflib.unified_diff(
                a.splitlines(), b.splitlines(),
                fromfile="OLD/" + rel, tofile="NEW/" + rel, lineterm="", n=2))
        oa, nb = extract(a, rel), extract(b, rel)
        for k in kinds:
            old_all[k] |= oa[k]
            new_all[k] |= nb[k]
        fd = {}
        for k in kinds:
            miss = sorted(oa[k] - nb[k])
            add = sorted(nb[k] - oa[k])
            if miss or add:
                fd[k] = {"missing": miss, "added": add}
        if fd:
            file_diffs.append({"file": rel, "diff": fd})
        # 被注释掉的功能行（新工程相对老工程新增的注释代码）
        oc_set = oa["commented"]
        nc_set = nb["commented"]
        new_commented = nc_set - oc_set
        if new_commented:
            file_diffs.append({"file": rel, "commented_new": sorted(new_commented)[:20]})

    # 完整集合比对（含未改动文件，确认总量）
    for rel in common:
        if rel in changed:
            continue
        a = read(oc[rel])
        oa = extract(a, rel)
        for k in kinds:
            old_all[k] |= oa[k]
            new_all[k] |= oa[k]
    for rel in only_new:
        nb = extract(read(nc[rel]), rel)
        for k in kinds:
            new_all[k] |= nb[k]

    print("=" * 72)
    print("老工程 : %s" % OLD_CLASSES)
    print("新工程 : %s" % NEW_CLASSES)
    print("=" * 72)
    print("文件: 老 %d / 新 %d / 同名 %d ; 仅老 %d / 仅新 %d / 内容改动 %d / 完全一致 %d"
          % (len(oc), len(nc), len(common), len(only_old), len(only_new),
             len(changed), len(common) - len(changed)))
    if only_old:
        print("  [仅老] " + ", ".join(only_old[:20]))
    if only_new:
        print("  [仅新] " + ", ".join(only_new[:20]))

    print("\n--- 全局功能点集合（老 → 新） ---")
    label = {"page": "页面注册", "button": "按钮/交互分支", "jump": "页面跳转目标",
             "ccbi": "界面资源(ccbi)", "pagelit": "页面名引用", "packet": "协议/opcode/case",
             "method": "成员函数定义", "string": "功能字符串字面量"}
    summary = {}
    for k in kinds:
        o, n = old_all[k], new_all[k]
        miss, add = sorted(o - n), sorted(n - o)
        summary[k] = {"old": len(o), "new": len(n), "missing": miss, "added": add}
        print("  %-14s 老 %5d / 新 %5d | 老有新无 %3d | 新有老无 %3d"
              % (label[k], len(o), len(n), len(miss), len(add)))
        if miss:
            print("      [老有新无] " + ", ".join(str(x) for x in miss[:25]))
        if add:
            print("      [新有老无] " + ", ".join(str(x) for x in add[:25]))

    print("\n--- 逐文件功能点差异 (%d 个文件) ---" % len(file_diffs))
    for fd in file_diffs[:60]:
        print("  * " + fd["file"])
        if "diff" in fd:
            for k, v in fd["diff"].items():
                if v["missing"]:
                    print("      - %s: %s" % (k, ", ".join(v["missing"][:12])))
                if v["added"]:
                    print("      + %s: %s" % (k, ", ".join(v["added"][:12])))
        if "commented_new" in fd:
            print("      [新增注释代码] %d 行" % len(fd["commented_new"]))
            for x in fd["commented_new"][:4]:
                print("        // " + x[:110])

    # 资源文件级覆盖
    ores, nres = walk(OLD_RES), walk(NEW_RES)
    om = set(k.lower() for k in ores)
    nm = set(k.lower() for k in nres)
    print("\n--- 资源文件覆盖 ---")
    print("  老 %d / 新 %d | 老有新无 %d | 新有老无 %d"
          % (len(ores), len(nres), len(om - nm), len(nm - om)))
    for x in sorted(om - nm)[:20]:
        print("      [老有新无] " + x)

    result = {
        "old": OLD_CLASSES, "new": NEW_CLASSES,
        "files": {"old": len(oc), "new": len(nc), "only_old": only_old,
                  "only_new": only_new, "changed": changed,
                  "identical": len(common) - len(changed)},
        "summary": summary, "file_diffs": file_diffs,
        "resources": {"old": len(ores), "new": len(nres),
                      "missing": sorted(om - nm), "added": sorted(nm - om)},
    }
    if want_json:
        p = os.path.join(OUT, "parity_result.json")
        with open(p, "w", encoding="utf-8") as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
        print("\n[JSON] " + p)
    if want_diff:
        p = os.path.join(OUT, "parity_full.diff")
        with open(p, "w", encoding="utf-8") as f:
            f.write("\n".join(full_diff))
        print("[DIFF] " + p + " (%d lines)" % len(full_diff))
    return result


if __name__ == "__main__":
    main()
