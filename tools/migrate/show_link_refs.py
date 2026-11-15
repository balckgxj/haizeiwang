"""看未解析符号是谁引用的：引擎内部不一致，还是游戏代码在调用。"""
import io
from collections import Counter

LOG = r"E:\PCGame\Haizeiwang\_tools\build_Debug.log"
ref = Counter()
for line in io.open(LOG, encoding="gbk", errors="replace").read().splitlines():
    if "LNK2001" not in line and "LNK2019" not in line:
        continue
    parts = line.split('"')
    if len(parts) < 2:
        continue
    sym = parts[1]
    who = line.split(": error")[0].strip()
    who = who.split("\\")[-1]
    ref[(who, sym[:70])] += 1

print("total lines", sum(ref.values()))
for (who, sym), c in ref.most_common(20):
    print("%4d  %-28s %s" % (c, who, sym))
