"""统计老代码里 CCScrollView 的实际 API 面积，用于写 2.x 兼容壳。"""
import os
import re
from collections import Counter

SRC = r"E:\PCGame\Haizeiwang\client\Classes"

METHODS = ["setContainer", "getContainer", "setViewSize", "getViewSize", "setContentOffset",
           "getContentOffset", "setContentOffsetInDuration", "setContentOffsetEaseIn",
           "setDirection", "getDirection", "setDelegate", "getDelegate", "setBounceable",
           "setBounces", "setClippingToBounds", "setTouchEnabled", "setZoomScale",
           "getZoomScale", "updateInset", "setContentSize", "getContentSize",
           "resizeInParent", "setContentOffsetToTop", "maxContainerOffset",
           "minContainerOffset", "isDragging", "isTouchMoved", "setSlackOffset"]

def main():
    var_re = re.compile(r"CCScrollView\s*\*\s*(\w+)")
    hits = Counter()
    files = 0
    for f in os.listdir(SRC):
        p = os.path.join(SRC, f)
        if not f.endswith((".cpp", ".h")):
            continue
        with open(p, "r", encoding="utf-8", errors="ignore") as fh:
            text = fh.read()
        if "CCScrollView" not in text:
            continue
        files += 1
        vars_ = set(var_re.findall(text)) | {"CCScrollView"}
        for v in vars_:
            for m in METHODS:
                n = len(re.findall(re.escape(v) + r"\s*(?:\.|->|::)\s*" + m + r"\s*\(", text))
                if n:
                    hits[m] += n
        for m in ["kCCScrollViewDirectionHorizontal", "kCCScrollViewDirectionVertical", "kCCScrollViewDirectionBoth", "kCCScrollViewDirectionNone"]:
            hits[m] += text.count(m)
    print("files referencing CCScrollView = %d" % files)
    for k, v in hits.most_common():
        print("  %-34s %d" % (k, v))

if __name__ == "__main__":
    main()
