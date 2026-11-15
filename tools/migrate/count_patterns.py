"""统计剩余 2.x 特征数量。"""
import io
import os

D = r"E:\PCGame\Haizeiwang\client\Classes"
KEYS = ["callfuncN_selector", "callfunc_selector", "callfuncND_selector", "callfuncO_selector",
        "isSingleReference", "->count()", "CCARRAY_FOREACH", "objectForKey", "setObject(",
        "TOLUA_API", "CCLayerColor", "setIsTouchEnabled", "menu_selector", "schedule_selector",
        "kCCScrollView", "CCScale9Sprite", "CCEditBox", "CCTableView", "getFileData"]

cnt = dict((k, 0) for k in KEYS)
files = {}
for f in sorted(os.listdir(D)):
    if not f.endswith((".cpp", ".h", ".cc")):
        continue
    t = io.open(os.path.join(D, f), encoding="gbk", errors="ignore").read()
    hit = 0
    for k in KEYS:
        n = t.count(k)
        if n:
            cnt[k] += n
            hit += n
    if hit:
        files[f] = hit

for k, v in sorted(cnt.items(), key=lambda x: -x[1]):
    if v:
        print("%-24s %d" % (k, v))
print("\nTop files:")
for f, v in sorted(files.items(), key=lambda x: -x[1])[:12]:
    print("  %-40s %d" % (f, v))
