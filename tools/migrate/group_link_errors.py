"""统计链接期未解析符号（按符号名聚类）。"""
import io

LOG = r"E:\PCGame\Haizeiwang\_tools\build_Debug.log"
syms = {}
for line in io.open(LOG, encoding="gbk", errors="replace").read().splitlines():
    if "LNK2001" not in line and "LNK2019" not in line and "LNK2005" not in line:
        continue
    parts = line.split('"')
    if len(parts) < 2:
        continue
    key = parts[1]
    syms[key] = syms.get(key, 0) + 1

print("unique =", len(syms))
for s, c in sorted(syms.items(), key=lambda x: -x[1]):
    print("%4d  %s" % (c, s[:150]))
