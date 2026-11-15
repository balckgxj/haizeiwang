"""第五轮：把宏/常量类问题统一收口。"""
import io
import os
import re

D = r"E:\PCGame\Haizeiwang\client\Classes"

def load(f):
    return io.open(os.path.join(D, f), encoding="gbk", errors="surrogateescape", newline="").read()

def save(f, t):
    io.open(os.path.join(D, f), "w", encoding="gbk", errors="surrogateescape", newline="").write(t)

total = {}
setstr = re.compile(r"->setString\(([^,()]+),\s*(?:true|false)\)")

for f in os.listdir(D):
    if not f.endswith((".cpp", ".h")):
        continue
    t = load(f)
    orig = t
    for a, b in [("cocos2d::kMaxLogLen", "kMaxLogLen"),
                 ("->getChildren()->at(", "->getChildren().at("),
                 ("()->at(", "().at(")]:
        if a in t:
            total[a] = total.get(a, 0) + t.count(a)
            t = t.replace(a, b)
    t2, n = setstr.subn(lambda m: "->setString(%s)" % m.group(1), t)
    if n:
        total["setString 2 args"] = total.get("setString 2 args", 0) + n
        t = t2
    if t != orig:
        save(f, t)

for k, v in total.items():
    print("%-40s %d" % (k, v))
