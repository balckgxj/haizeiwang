"""第二轮清理：
1. 修掉上一轮 scriptengine 替换产生的 `cocos2d::((...)` 语法错误
2. CCBScriptContainer 的 _searchChild 也换成 Vector
3. CCBLuaContainer 里 `childern &&` 改成 empty()
4. setScrollViewChild(...) —— 2.x CCMenu 扩展接口，3.x 无 → 整行注释
5. CallFuncN::create(target, callfuncN_selector(Class::func)) → CC_CALLBACK_1
"""
import io
import os
import re

D = r"E:\PCGame\Haizeiwang\client\Classes"

def load(f):
    return io.open(os.path.join(D, f), encoding="gbk", errors="surrogateescape", newline="").read()

def save(f, t):
    io.open(os.path.join(D, f), "w", encoding="gbk", errors="surrogateescape", newline="").write(t)

files = [f for f in os.listdir(D) if f.endswith((".cpp", ".h"))]
stats = {}

calln = re.compile(r"CallFuncN::create\(\s*(.+?)\s*,\s*(?:static_cast<cocos2d::SEL_CallFuncN>\()?callfuncN_selector\((\w+::\w+)\)\)?\s*\)")

for f in files:
    t = load(f)
    orig = t
    t = t.replace("cocos2d::((cocos2d::CCLuaEngine*)", "((cocos2d::CCLuaEngine*)")
    n1 = (orig.count("cocos2d::((cocos2d::CCLuaEngine*)"))

    t2, n2 = calln.subn(lambda m: "cocos2d::CallFuncN::create(CC_CALLBACK_1(%s, %s))" % (m.group(2), m.group(1)), t)

    n3 = 0
    if "setScrollViewChild(" in t2:
        lines = t2.splitlines(True)
        for i, l in enumerate(lines):
            if "setScrollViewChild(" in l and not l.lstrip().startswith("//"):
                indent = re.match(r"\s*", l).group(0)
                lines[i] = indent + "// [migrate] 2.x CCMenu 扩展接口 setScrollViewChild，3.x 无\n"
                n3 += 1
        t2 = "".join(lines)

    if t2 != orig:
        save(f, t2)
        stats[f] = (n1, n2, n3)

print("files changed:", len(stats))
for f, v in stats.items():
    print("  %-36s ns=%d callfuncN=%d setScrollViewChild=%d" % (f, v[0], v[1], v[2]))

# 专项：CCBScriptContainer 的 _searchChild
f = "CCBScriptContainer.cpp"
t = load(f)
t = t.replace("static CCBScriptContainer* _searchChild(cocos2d::CCArray* childern, int tag)",
              "static CCBScriptContainer* _searchChild(const cocos2d::Vector<cocos2d::Node*>& childern, int tag)")
t = t.replace("CCARRAY_FOREACH(childern, child)", "for (auto child : childern)")
save(f, t)
print("CCBScriptContainer.cpp patched")

# 专项：CCBLuaContainer 空判断
f = "CCBLuaContainer.cpp"
t = load(f)
t = t.replace("if(childern && childern.size() > 0)", "if(!childern.empty())")
t = t.replace("if(childern && childern.size()>0)", "if(!childern.empty())")
save(f, t)
print("CCBLuaContainer.cpp patched")
