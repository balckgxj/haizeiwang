"""更准确地检查 3.17.2 里符号的存在形式：真正的类 / 别名 / 完全消失。"""
import os
import re

ENGINE = r"E:\PCGame\Haizeiwang\engine\cocos2d-x"
SCAN_DIRS = [os.path.join(ENGINE, "cocos"), os.path.join(ENGINE, "extensions")]

CLASS_RE = re.compile(r"\b(?:class|struct)\s+(?:CC_DLL\s+|CC_EX_DLL\s+)?(\w+)\s*(?::|\{)", re.M)
ALIAS_RE = re.compile(r"(?:#\s*define\s+|typedef\s+[^;\n]*?\s+)(CC\w+)", re.M)

def main():
    classes, aliases = set(), {}
    for root in SCAN_DIRS:
        for dirpath, _, files in os.walk(root):
            for f in files:
                if not f.endswith((".h", ".hpp", ".inl")):
                    continue
                p = os.path.join(dirpath, f)
                try:
                    with open(p, "r", encoding="utf-8", errors="ignore") as fh:
                        text = fh.read()
                except OSError:
                    continue
                classes.update(CLASS_RE.findall(text))
                for m in ALIAS_RE.finditer(text):
                    aliases.setdefault(m.group(1), os.path.relpath(p, ENGINE))

    print("classes=%d aliases=%d" % (len(classes), len(aliases)))
    check = ["LabelTTF", "LabelBMFont", "MenuItem", "MenuItemImage", "MenuItemSprite",
             "MenuItemLabel", "MenuItemToggle", "Menu", "TableViewCell", "Control",
             "__NotificationCenter", "UserDefault", "AnimationCache", "ProgressTo",
             "Point", "Color3B", "Scale9Sprite", "ScrollView", "CCBReader", "EditBox"]
    print("\n== 3.x 真实类名检查 ==")
    for c in check:
        print(("  OK   " if c in classes else "  MISS ") + c)

    print("\n== 2.x 别名的落点（前 80 条） ==")
    for k in sorted(aliases)[:80]:
        print("  %-28s -> %s" % (k, aliases[k]))

if __name__ == "__main__":
    main()
