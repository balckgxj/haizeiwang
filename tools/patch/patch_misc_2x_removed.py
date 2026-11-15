"""零散的 2.x 接口清理：

1. BoardCastLabel：2.x 用 LabelTTF::setTextureRect 做跑马灯裁剪，3.x 无此接口
   → 先注释掉（跑马灯视觉后续用 ClippingNode 重做）
2. AsyncSprite：TextureCache::addImageAsync 2.x 是 (path, target, selector)，
   3.x 是 (path, std::function, void*) → 改 lambda
3. AppDelegate：Application::purgeCachedData / TextureCache::dumpCachedTextureInfo 已移除
"""
import io
import os
import re

CLASSES = r"E:\PCGame\Haizeiwang\client\Classes"
NOTE = "// [migrate] 2.x 接口在 3.x 已移除"


def load_text(f):
    return io.open(os.path.join(CLASSES, f), encoding="gbk",
                   errors="surrogateescape", newline="").read()


def save_text(f, text):
    io.open(os.path.join(CLASSES, f), "w", encoding="gbk",
            errors="surrogateescape", newline="").write(text)


# ---------------------------------------------------------------- 1
t = load_text("BoardCastLabel.cpp")
lines = t.splitlines(True)
n = 0
for i, l in enumerate(lines):
    if "->setTextureRect(CCRectMake(" in l and not l.lstrip().startswith("//"):
        lines[i] = "\t\t" + NOTE + "（LabelTTF::setTextureRect），待用 ClippingNode 重做\n"
        n += 1
save_text("BoardCastLabel.cpp", "".join(lines))
print("BoardCastLabel.cpp: %d setTextureRect -> noop" % n)

# ---------------------------------------------------------------- 2
t = load_text("AsyncSprite.cpp")
pat = re.compile(r"addImageAsync\(\s*([\w\.\(\)\->]+)\.c_str\(\),\s*this,\s*"
                 r"callfuncO_selector\((\w+)::(\w+)\)\s*\)")
cnt = 0
def repl(m):
    global cnt
    cnt += 1
    path_expr, cls, func = m.group(1), m.group(2), m.group(3)
    return ("addImageAsync(%s, [this](cocos2d::Texture2D* tex) { this->%s((cocos2d::Ref*)tex); }, nullptr)"
            % (path_expr, func))
t = pat.sub(repl, t)
save_text("AsyncSprite.cpp", t)
print("AsyncSprite.cpp: %d addImageAsync -> lambda" % cnt)

# ---------------------------------------------------------------- 3
t = load_text("AppDelegate.cpp")
lines = t.splitlines(True)
n = 0
for i, l in enumerate(lines):
    if "Application::getInstance()->purgeCachedData()" in l:
        lines[i] = "\t" + NOTE + "（Application::purgeCachedData）\n"
        n += 1
    elif "dumpCachedTextureInfo()" in l:
        lines[i] = "\t" + NOTE + "（TextureCache::dumpCachedTextureInfo）\n"
        n += 1
save_text("AppDelegate.cpp", "".join(lines))
print("AppDelegate.cpp: %d lines -> noop" % n)
