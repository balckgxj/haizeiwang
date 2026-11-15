# -*- coding: utf-8 -*-
"""
逐页功能对照表生成器（老 2.1.3 / 新 3.17.2）。

对每个 REGISTER_PAGE 页面，统计：
  - 归属源文件、按钮/交互分支数、ccbi 资源数、成员函数数、协议 handler 数
  - 两端「功能点集合」是否一致（页面注册/按钮/跳转/资源/方法/字符串）
  - 115 页运行时巡检结果（_tools/page_audit_result.txt）
  - 本轮真实点击路径覆盖情况

产出：_tools/parity_pages.json 与 _tools/parity_table.md（可直接粘进文档）
用法：python tools/audit_page_parity.py
"""
from __future__ import print_function

import os
import re
import json
import collections

OLD = r"E:\BaiduNetdiskDownload\(SY-096)草M船Z\src\src\client\Game\Classes"
NEW = r"E:\PCGame\Haizeiwang\client\Classes"
OUT = r"E:\PCGame\Haizeiwang\_tools"
AUDIT = os.path.join(OUT, "page_audit_result.txt")

# 本轮真实点击路径覆盖到的页面（tools/verify_clickpath.ps1 / verify_fight_real.ps1）
CLICK_COVERED = {
    "MainPage", "MemberPage", "CrewPage", "AdventurePage", "CareerPage",
    "EquipPage", "SkillPage", "DisciplePage", "SettingsPage", "PackagePage",
    "HandBookPage", "HandbookPage", "ArenaPage", "FightPage", "FightEndPage",
    "FightResultPage", "ChapterPage", "LoginPage",
}

RE_REGISTER = re.compile(r'REGISTER_PAGE\s*\(\s*"([^"]+)"\s*,\s*([A-Za-z_]\w*)')
RE_BUTTON = re.compile(r'itemName\s*==\s*"([^"]+)"')
RE_CCBI = re.compile(r'"([A-Za-z0-9_/\-]+\.ccbi?)"')
RE_METHOD = re.compile(r'^\s*[\w:<>,\*&\s]+?\b([A-Za-z_]\w*)::([A-Za-z_]\w*)\s*\([^;]*?\)\s*(?:const\s*)?\{', re.M)
RE_HANDLER = re.compile(r'(?:NEW_)?DEFINE_CREATE_REGISTER_HANDLER\s*\(\s*([A-Za-z_]\w*)')
RE_STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')
RE_JUMP = re.compile(r'(?:pageName|Msg\w+Page)\s*=\s*"([A-Za-z0-9_]+Page)"')


def rd(p):
    return open(p, "r", encoding="utf-8", errors="replace").read()


def strip_comments(src):
    out = []
    i, n, st = 0, len(src), "c"
    while i < n:
        c = src[i]
        nx = src[i + 1] if i + 1 < n else ""
        if st == "c":
            if c == '"': st = "s"; out.append(c)
            elif c == "'": st = "q"; out.append(c)
            elif c == "/" and nx == "/": st = "l"; i += 1
            elif c == "/" and nx == "*": st = "b"; i += 1
            else: out.append(c)
        elif st == "s":
            out.append(c)
            if c == "\\" and i + 1 < n: out.append(src[i + 1]); i += 1
            elif c == '"': st = "c"
        elif st == "q":
            out.append(c)
            if c == "\\" and i + 1 < n: out.append(src[i + 1]); i += 1
            elif c == "'": st = "c"
        elif st == "l":
            if c == "\n": out.append(c); st = "c"
        elif st == "b":
            if c == "*" and nx == "/": st = "c"; i += 1
            elif c == "\n": out.append(c)
        i += 1
    return "".join(out)


def features(src):
    e = strip_comments(src)
    return {
        "page": set(RE_REGISTER.findall(e)),
        "button": set(RE_BUTTON.findall(e)),
        "jump": set(RE_JUMP.findall(e)),
        "ccbi": set(RE_CCBI.findall(e)),
        "method": set("%s::%s" % (a, b) for a, b in RE_METHOD.findall(e)),
        "handler": set(RE_HANDLER.findall(e)),
        "string": set(s for s in RE_STRING.findall(e)
                      if len(s) > 2 and (re.search(r'\.(ccbi|png|plist|fnt|mp3|txt|cfg)|/|Page|on[A-Z]', s))),
    }


def scan(root):
    d = {}
    for dp, dn, fn in os.walk(root):
        for f in fn:
            if os.path.splitext(f)[1].lower() not in (".cpp", ".h"):
                continue
            p = os.path.join(dp, f)
            d[os.path.relpath(p, root).replace("\\", "/")] = p
    return d


def main():
    oc, nc = scan(OLD), scan(NEW)
    # 页面注册
    pages = {}
    for rel, p in nc.items():
        if not rel.endswith(".cpp"):
            continue
        src = rd(p)
        for name, cls in RE_REGISTER.findall(strip_comments(src)):
            pages[name] = {"class": cls, "main": rel}
    print("registered pages: %d" % len(pages))

    # 巡检结果
    audit = {}
    if os.path.isfile(AUDIT):
        for ln in rd(AUDIT).replace("\ufeff", "").splitlines():
            parts = ln.split()
            if len(parts) >= 2:
                audit[parts[0]] = parts[-1]

    # 页面关联文件：主 .cpp 对应的 .h + 同名前缀的分拆 .cpp
    rows = []
    for name in sorted(pages):
        info = pages[name]
        main = info["main"]
        stem = os.path.splitext(os.path.basename(main))[0]
        group = [rel for rel in nc
                 if os.path.basename(rel).startswith(stem + ".")
                 or os.path.basename(rel) == stem + "_part.cpp"]
        # 显式补上同名分拆文件
        group += [rel for rel in nc
                  if rel.startswith(os.path.dirname(main) + "/") is False
                  and os.path.basename(rel).startswith(stem + "_")
                  and rel.endswith(".cpp")]
        group = sorted(set(group))
        oldf = collections.defaultdict(set)
        newf = collections.defaultdict(set)
        diff_files = []
        for rel in group:
            if rel not in oc:
                continue
            a, b = rd(oc[rel]), rd(nc[rel])
            if a == b:
                for k, v in features(b).items():
                    oldf[k] |= v; newf[k] |= v
                continue
            diff_files.append(rel)
            oa, nb = features(a), features(b)
            for k in oa:
                oldf[k] |= oa[k]; newf[k] |= nb[k]
        missing = {k: sorted(oldf[k] - newf[k]) for k in oldf if oldf[k] - newf[k]}
        added = {k: sorted(newf[k] - oldf[k]) for k in newf if newf[k] - oldf[k]}

        # 归一化：以下差异属于「2.x→3.x 接口改名」或工具正则误报，不是功能缺失
        # 1) 引擎头文件路径（particle_nodes/X.h -> 2d/X.h、support/... -> cocos2d.h）
        for k in ("string",):
            if k in missing:
                missing[k] = [x for x in missing[k] if not (
                    x.endswith(".h") and ("/" in x or x.startswith("2d")))]
                if not missing[k]: del missing[k]
            if k in added:
                added[k] = [x for x in added[k] if not (
                    x.endswith(".h") and ("/" in x or x.startswith("2d")))]
                if not added[k]: del added[k]
        # 2) copyWithZone/clone、draw/drawShader 是同一接口的 2.x/3.x 名称
        api_eq = {"NumberChangeAction::copyWithZone", "SpriteShader::draw"}
        api_new = {"NumberChangeAction::clone", "SpriteShader::drawShader"}
        # 3) "Class::create(...)" 被方法正则误判为成员函数定义
        def noise(x):
            return x in api_new or "::create" in x or x.startswith(
                ("LoginPage::", "MainFrame::_", "SeverConsts::_"))
        if "method" in missing:
            missing["method"] = [x for x in missing["method"] if x not in api_eq and "::create" not in x]
            if not missing["method"]: del missing["method"]
        if "method" in added:
            added["method"] = [x for x in added["method"] if not noise(x)]
            if not added["method"]: del added["method"]
        rows.append({
            "page": name, "class": info["class"], "files": group,
            "buttons": sorted(newf["button"]), "button_count": len(newf["button"]),
            "ccbi": sorted(newf["ccbi"]), "ccbi_count": len(newf["ccbi"]),
            "methods": len(newf["method"]), "handlers": sorted(newf["handler"]),
            "changed_files": diff_files,
            "missing": missing, "added": added,
            # 「一致」= 老工程的功能点一个都没丢；新增项单列，不算不一致
            "static_parity": not missing,
            "has_additions": bool(added),
            "runtime": audit.get(name, "n/a"),
            "clickpath": name in CLICK_COVERED,
        })

    with open(os.path.join(OUT, "parity_pages.json"), "w", encoding="utf-8") as f:
        json.dump({"total": len(rows), "rows": rows}, f, ensure_ascii=False, indent=2)

    # Markdown 表格
    md = ["| # | 页面 | 按钮分支 | ccbi | 方法 | 代码改动 | 老→新无缺失 | 新增项 | 115页巡检 | 真实点击 |",
          "|---:|---|---:|---:|---:|---|---|---|---|---|"]
    for i, r in enumerate(rows, 1):
        md.append("| %d | `%s` | %d | %d | %d | %s | %s | %s | %s | %s |" % (
            i, r["page"], r["button_count"], r["ccbi_count"], r["methods"],
            ("%d 文件" % len(r["changed_files"])) if r["changed_files"] else "—",
            "✅" if r["static_parity"] else "⚠️",
            "有" if r["has_additions"] else "—",
            "✅" if r["runtime"] == "ok" else r["runtime"],
            "✅" if r["clickpath"] else "—"))
    with open(os.path.join(OUT, "parity_table.md"), "w", encoding="utf-8") as f:
        f.write("\n".join(md))

    ok = sum(1 for r in rows if r["static_parity"])
    runok = sum(1 for r in rows if r["runtime"] == "ok")
    print("static parity: %d/%d" % (ok, len(rows)))
    print("runtime ok   : %d/%d" % (runok, len(rows)))
    print("total buttons: %d" % sum(r["button_count"] for r in rows))
    print("total ccbi   : %d" % sum(r["ccbi_count"] for r in rows))
    print("pages with feature diff:")
    for r in rows:
        if not r["static_parity"]:
            print("  * %s missing=%s added=%s" % (
                r["page"],
                {k: v[:6] for k, v in r["missing"].items()},
                {k: v[:6] for k, v in r["added"].items()}))
    print("[JSON] " + os.path.join(OUT, "parity_pages.json"))
    print("[MD]   " + os.path.join(OUT, "parity_table.md"))


if __name__ == "__main__":
    main()
