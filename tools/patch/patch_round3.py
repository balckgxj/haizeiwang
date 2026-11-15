"""第三轮清理：
1. `CCcocos2d::` → `cocos2d::`（上一轮 callfuncN 规则误伤）
2. SpriteShader：3.x 里 Node::draw 是 final，不能重写 → 改名为 drawShader
3. Language.cpp：LabelBMFont::setString 少一个参数，CCArray::data() 换掉
"""
import io
import os
import re

D = r"E:\PCGame\Haizeiwang\client\Classes"


def load(f):
    return io.open(os.path.join(D, f), encoding="gbk", errors="surrogateescape", newline="").read()


def save(f, t):
    io.open(os.path.join(D, f), "w", encoding="gbk", errors="surrogateescape", newline="").write(t)


# 1) CCcocos2d::
n = 0
for f in os.listdir(D):
    if not f.endswith((".cpp", ".h")):
        continue
    t = load(f)
    if "CCcocos2d::" in t:
        n += t.count("CCcocos2d::")
        save(f, t.replace("CCcocos2d::", "cocos2d::"))
print("CCcocos2d fixed:", n)

# 2) SpriteShader
try:
    h = load("SpriteShader.h")
    c = load("SpriteShader.cpp")
    h2 = h.replace("virtual void draw();", "virtual void drawShader();").replace("void draw();", "void drawShader();")
    c2 = c.replace("void SpriteShader::draw()", "void SpriteShader::drawShader()")
    save("SpriteShader.h", h2)
    save("SpriteShader.cpp", c2)
    print("SpriteShader: draw -> drawShader (h:%s c:%s)" % (h != h2, c != c2))
except FileNotFoundError as e:
    print("SpriteShader missing:", e)

# 3) Language.cpp
t = load("Language.cpp")
lines = t.splitlines(True)
for i, l in enumerate(lines):
    if "setString(" in l and l.count(",") >= 1 and "LabelBMFont" not in l:
        print("Language.cpp:%d  %s" % (i + 1, l.rstrip()))
    if "->data()" in l:
        print("Language.cpp:%d  %s" % (i + 1, l.rstrip()))
