"""统计老代码里 2.x 的符号使用情况，用于制定迁移规则。"""
import os
import re
import json
from collections import Counter

SRC = r"E:\PCGame\Haizeiwang\client\Classes"
OUT = r"E:\PCGame\Haizeiwang\tools\migrate"

CC_RE = re.compile(r"\bCC[A-Z]\w*")
CALL_RE = re.compile(r"(?:->|\.|::)\s*([a-z]\w*)\s*\(")
INC_RE = re.compile(r'^\s*#\s*include\s*[<"]([^>"]+)[>"]', re.M)

# 2.x 常见静态工厂/单例（方法名层面）
STATIC_HINTS = {
    "sharedDirector", "sharedOpenGLView", "sharedFileUtils", "sharedUserDefault",
    "sharedTextureCache", "sharedSpriteFrameCache", "sharedNotificationCenter",
    "sharedScheduler", "sharedEngine", "sharedAnimationCache", "spriteWithFile",
    "spriteWithSpriteFrameName", "spriteWithSpriteFrame", "labelWithString",
    "labelWithBMFont", "itemWithNormalImage", "itemWithTarget", "node", "initWithFile",
    "initWithSpriteFrameName", "createWithSpriteFrameName", "addSpriteFramesWithFile",
    "createWithFormat", "stringWithFormat", "valueWithBool", "setTarget",
    "scheduleSelector", "unscheduleSelector", "createWithTexture",
    "sharedApplication", "sharedConfiguration",
}


def main():
    cc_counter = Counter()
    call_counter = Counter()
    inc_counter = Counter()
    files = [f for f in os.listdir(SRC) if f.endswith((".cpp", ".h"))]
    for f in files:
        p = os.path.join(SRC, f)
        with open(p, "r", encoding="utf-8", errors="ignore") as fh:
            text = fh.read()
        for m in CC_RE.findall(text):
            cc_counter[m] += 1
        for m in CALL_RE.findall(text):
            if m in STATIC_HINTS or "With" in m or m.startswith("shared"):
                call_counter[m] += 1
        for m in INC_RE.findall(text):
            inc_counter[m] += 1

    print("files=%d distinct CC* symbols=%d" % (len(files), len(cc_counter)))
    print("\n== 出现次数最多的 CC* 类型/宏 (top 60) ==")
    for k, v in cc_counter.most_common(60):
        print("  %-32s %d" % (k, v))

    print("\n== 需要改写的静态工厂/单例调用 (top 40) ==")
    for k, v in call_counter.most_common(40):
        print("  %-32s %d" % (k, v))

    print("\n== include 依赖 (非本工程头文件) ==")
    for k, v in inc_counter.most_common(80):
        print("  %-44s %d" % (k, v))

    with open(os.path.join(OUT, "usage.json"), "w", encoding="utf-8") as fh:
        json.dump({"cc": cc_counter, "calls": call_counter, "includes": inc_counter},
                  fh, ensure_ascii=False, indent=1)
    print("\nwritten usage.json")


if __name__ == "__main__":
    main()
