"""把 MSVC 编译错误按“文件 + 错误码 + 消息”聚类，便于批量处理。"""
import io
import re
from collections import Counter

LOG = r"E:\PCGame\Haizeiwang\_tools\build_Debug.log"

pat = re.compile(r"^(.*?)\((\d+)(?:,\d+)?\):\s*(?:error|fatal error)\s+(C\d+|LNK\d+|MSB\d+):\s*(.*?)(?:\s*\[|$)")
groups = Counter()
samples = {}
files = Counter()
for line in io.open(LOG, encoding="gbk", errors="replace").read().splitlines():
    m = pat.match(line.strip())
    if not m:
        continue
    f, ln, code, msg = m.group(1), m.group(2), m.group(3), m.group(4)
    name = f.split("\\")[-1]
    key = (code, msg[:110])
    groups[key] += 1
    files[name] += 1
    samples.setdefault(key, "%s:%s" % (name, ln))

print("total = %d" % sum(groups.values()))
for (code, msg), n in groups.most_common(25):
    print("%4d  %-8s %-100s   e.g. %s" % (n, code, msg, samples[(code, msg)]))
print("\nfiles:")
for f, n in files.most_common(15):
    print("  %-40s %d" % (f, n))
