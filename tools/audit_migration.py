# -*- coding: utf-8 -*-
"""
Haizeiwang 升级移植完整性审计工具

对比老工程 (cocos2d-x 2.1.3) 与新工程 (cocos2d-x 3.17.2) 的文件覆盖情况，
输出缺失 / 新增 / 内容变更清单，并扫描新工程中的「功能降级」标记。

用法:
    python tools/audit_migration.py                # 打印摘要
    python tools/audit_migration.py --detail       # 打印完整清单
    python tools/audit_migration.py --json out.json

老工程保持只读，本脚本不会修改任何工程文件。
"""
import os
import sys
import json
import hashlib
import argparse
import collections

OLD = r"E:\BaiduNetdiskDownload\(SY-096)草M船Z\src\src"
NEW = r"E:\PCGame\Haizeiwang"

OLD_GAME = os.path.join(OLD, "client", "Game")
NEW_CLIENT = os.path.join(NEW, "client")

# (名称, 老根, 新根, 参与对比的扩展名集合 or None=全部)
PAIRS = [
    ("Classes",   os.path.join(OLD_GAME, "Classes"),   os.path.join(NEW_CLIENT, "Classes"),   {".cpp", ".h"}),
    ("Protobuf",  os.path.join(OLD_GAME, "Protobuf"),  os.path.join(NEW_CLIENT, "Protobuf"),  {".cc", ".h", ".proto"}),
    ("Platform",  os.path.join(OLD_GAME, "Platform"),  os.path.join(NEW_CLIENT, "Platform"),  {".cpp", ".h"}),
    ("Resources", os.path.join(OLD_GAME, "proj.android", "antbuild", "anzhi", "assets"),
                   os.path.join(NEW_CLIENT, "Resources"), None),
]

# 老工程里另有价值的源码/资产（只做统计，不做一对一对比）
EXTRA_OLD = [
    ("老引擎/扩展(参考)", os.path.join(OLD, "client", "extensions")),
    ("客户端平台层(原)",   os.path.join(OLD, "client", "Game", "Platform")),
    ("Java 层(proj.android/src)", os.path.join(OLD, "client", "Game", "proj.android", "src")),
    ("服务端",             os.path.join(OLD, "server")),
]

# 新工程里明确被降级/排除的文件（相对 NEW）
EXCLUDED_FROM_BUILD = [
    r"client\Classes\Gamelua.cpp",
    r"client\Classes\pb.cpp",
]

# 功能降级特征：命中即认为存在"未完整移植"风险
DEGRADE_PATTERNS = [
    "TODO", "FIXME", "XXX", "HACK",
    "暂时", "暂注释", "暂不", "暂用", "占位", "桩实现", "stub",
    "阶段二", "阶段三", "后续", "待恢复", "待用", "未实现",
    "注释掉", "先注释", "跳过", "关闭", "禁用", "不再", "无碍",
]

CODE_EXTS = {".cpp", ".h", ".cc", ".c", ".mm", ".m", ".py", ".txt", ".md"}


def norm(p):
    return os.path.normpath(p).lower().replace("/", "\\")


def scan(root, exts=None):
    """返回 {相对路径(小写): {path,size,hash}}"""
    out = {}
    if not os.path.isdir(root):
        return out
    for dirpath, dirnames, filenames in os.walk(root):
        # 跳过构建产物/版本控制目录
        dirnames[:] = [d for d in dirnames if d.lower() not in
                       (".git", ".svn", "obj", "debug.win32", "release.win32", ".metadata")]
        for fn in filenames:
            ext = os.path.splitext(fn)[1].lower()
            if exts is not None and ext not in exts:
                continue
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, root)
            try:
                st = os.stat(full)
                with open(full, "rb") as f:
                    h = hashlib.md5(f.read()).hexdigest()
                out[norm(rel)] = {"rel": rel, "path": full, "size": st.st_size, "md5": h}
            except (OSError, IOError):
                pass
    return out


def ext_stat(files):
    c = collections.Counter()
    for k in files:
        ext = os.path.splitext(k)[1].lower() or "(无扩展名)"
        c[ext] += 1
    return c


def compare():
    result = {"pairs": [], "extra": [], "degrade": [], "excluded": []}
    print("=" * 78)
    print("Haizeiwang 升级移植完整性审计")
    print("老工程: " + OLD)
    print("新工程: " + NEW)
    print("=" * 78)

    for name, oroot, nroot, exts in PAIRS:
        o = scan(oroot, exts)
        n = scan(nroot, exts)
        missing = sorted(set(o) - set(n))
        added = sorted(set(n) - set(o))
        changed = sorted(k for k in (set(o) & set(n)) if o[k]["md5"] != n[k]["md5"])
        same = sorted(set(o) & set(n) - set(changed))

        # 对缺失文件再按 basename 兜底匹配（容忍目录重组）
        n_by_base = collections.defaultdict(list)
        for k, v in n.items():
            n_by_base[os.path.basename(k)].append(k)
        relocated = {k: n_by_base[os.path.basename(k)] for k in missing
                     if os.path.basename(k) in n_by_base}
        truly_missing = [k for k in missing if k not in relocated]

        item = {
            "name": name, "old_root": oroot, "new_root": nroot,
            "old_count": len(o), "new_count": len(n),
            "old_ext": dict(ext_stat(o)), "new_ext": dict(ext_stat(n)),
            "missing": [o[k]["rel"] for k in truly_missing],
            "relocated": {o[k]["rel"]: [n[x]["rel"] for x in v] for k, v in relocated.items()},
            "added": [n[k]["rel"] for k in added],
            "changed": [o[k]["rel"] for k in changed],
            "identical": len(same),
            "old_lines": count_lines(o, {".cpp", ".h", ".cc"}),
            "new_lines": count_lines(n, {".cpp", ".h", ".cc"}),
        }
        result["pairs"].append(item)

        print("\n[%s] 老 %d 个 / 新 %d 个文件" % (name, len(o), len(n)))
        print("  完全未迁移(按 basename 也找不到): %d" % len(truly_missing))
        for k in truly_missing[:30]:
            print("     - " + o[k]["rel"])
        if len(truly_missing) > 30:
            print("     ... 另 %d 个" % (len(truly_missing) - 30))
        print("  路径变更但文件存在: %d" % len(relocated))
        print("  内容有改动(API 适配/补丁): %d" % len(changed))
        print("  内容完全一致: %d" % len(same))
        print("  新工程新增: %d" % len(added))
        for k in added[:15]:
            print("     + " + n[k]["rel"])
        if len(added) > 15:
            print("     ... 另 %d 个" % (len(added) - 15))
        print("  扩展名(老): %s" % summarize_ext(ext_stat(o)))
        print("  扩展名(新): %s" % summarize_ext(ext_stat(n)))
        print("  代码行数: 老 %d / 新 %d" % (item["old_lines"], item["new_lines"]))

    print("\n" + "-" * 78)
    print("其它老工程资产（仅统计，未要求一一迁移）")
    for name, path in EXTRA_OLD:
        f = scan(path)
        result["extra"].append({"name": name, "path": path, "count": len(f), "ext": dict(ext_stat(f))})
        print("  %-28s %-6d 个文件  %s" % (name, len(f), summarize_ext(ext_stat(f), 6)))

    print("\n" + "-" * 78)
    print("被排除编译的文件")
    for rel in EXCLUDED_FROM_BUILD:
        p = os.path.join(NEW, rel)
        info = {"rel": rel, "exists": os.path.isfile(p)}
        if info["exists"]:
            info["size"] = os.path.getsize(p)
            info["lines"] = sum(1 for _ in open(p, "rb"))
        result["excluded"].append(info)
        print("  %-45s %s" % (rel, ("存在, %d 行, %d 字节" % (info["lines"], info["size"]))
                                  if info["exists"] else "不存在"))

    print("\n" + "-" * 78)
    print("功能降级标记扫描 (client / compat / platform_bridge / CMakeLists.txt)")
    scan_roots = [os.path.join(NEW_CLIENT, "compat"),
                  os.path.join(NEW_CLIENT, "Classes"),
                  os.path.join(NEW, "platform_bridge"),
                  os.path.join(NEW, "CMakeLists.txt"),
                  os.path.join(NEW_CLIENT, "CMakeLists.txt")]
    hits = []
    for sr in scan_roots:
        files = [sr] if os.path.isfile(sr) else []
        if os.path.isdir(sr):
            for dp, dn, fns in os.walk(sr):
                for fn in fns:
                    if os.path.splitext(fn)[1].lower() in CODE_EXTS:
                        files.append(os.path.join(dp, fn))
        for f in files:
            try:
                lines = open(f, "r", encoding="utf-8", errors="ignore").read().splitlines()
            except OSError:
                continue
            for i, line in enumerate(lines, 1):
                s = line.strip()
                # 只看注释行 / 配置行，避免业务代码里的正常中文
                if not (s.startswith("//") or s.startswith("#") or s.startswith("/*") or s.startswith("*")):
                    continue
                if any(p.lower() in s.lower() for p in DEGRADE_PATTERNS):
                    hits.append({"file": os.path.relpath(f, NEW), "line": i, "text": s[:160]})
    result["degrade"] = hits
    by_file = collections.Counter(h["file"] for h in hits)
    print("  命中 %d 行，分布 %d 个文件:" % (len(hits), len(by_file)))
    for f, c in by_file.most_common(30):
        print("     %-62s %d" % (f, c))

    return result


def count_lines(files, exts):
    total = 0
    for k, v in files.items():
        if os.path.splitext(k)[1].lower() in exts:
            try:
                with open(v["path"], "rb") as f:
                    total += sum(1 for _ in f)
            except OSError:
                pass
    return total


def summarize_ext(c, n=10):
    return ", ".join("%s:%d" % (k, v) for k, v in c.most_common(n))


def print_detail(result):
    print("\n" + "=" * 78)
    print("完整清单")
    for p in result["pairs"]:
        print("\n### %s" % p["name"])
        for key in ("missing", "changed", "added"):
            print("\n-- %s (%d) --" % (key, len(p[key])))
            for x in p[key]:
                print("   " + x)
        if p["relocated"]:
            print("\n-- relocated (%d) --" % len(p["relocated"]))
            for k, v in p["relocated"].items():
                print("   %s -> %s" % (k, ", ".join(v)))
    print("\n### 降级标记明细")
    for h in result["degrade"]:
        print("   %s:%d  %s" % (h["file"], h["line"], h["text"]))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--detail", action="store_true")
    ap.add_argument("--json", default="")
    a = ap.parse_args()
    r = compare()
    if a.detail:
        print_detail(r)
    if a.json:
        with open(a.json, "w", encoding="utf-8") as f:
            json.dump(r, f, ensure_ascii=False, indent=2)
        print("\nJSON 已写入: " + a.json)
