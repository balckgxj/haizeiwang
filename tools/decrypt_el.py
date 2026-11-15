# -*- coding: utf-8 -*-
"""
导出老工程加密 Lua 脚本 (.el) 为明文 .lua。

加密算法来自老工程:
    client/scripting/lua/cocos2dx_support/Cocos2dxLuaLoader.cpp  decBuffer()
    1) 整个文件按 "youaiABC" 循环异或
    2) 第 0 字节是压缩块数标记，跳过
    3) 其余字节为 zlib 流，uncompress 得到 Lua 源码

与配置表 (*.txt) 的区别: 配置表额外有 0xEF 0xFE 两字节头，.el 没有。

输出: tools/lua_plain/*.lua （工具产物，不参与 CMake 构建）
用法: python tools/decrypt_el.py [--out DIR]
"""
import os
import sys
import zlib
import argparse
import json

KEY = b"youaiABC"
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "client", "Resources", "lua")


def decrypt(path):
    data = bytearray(open(path, "rb").read())
    for i in range(len(data)):
        data[i] ^= KEY[i % len(KEY)]
    if len(data) < 2:
        raise ValueError("too short")
    return zlib.decompress(bytes(data[1:]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(ROOT, "tools", "lua_plain"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)

    ok, fail, total_lines = 0, [], 0
    index = []
    for fn in sorted(os.listdir(SRC)):
        if not fn.lower().endswith(".el"):
            continue
        src = os.path.join(SRC, fn)
        try:
            plain = decrypt(src)
        except Exception as e:
            fail.append((fn, str(e)))
            continue
        out = os.path.join(a.out, fn[:-3] + ".lua")
        with open(out, "wb") as f:
            f.write(plain)
        text = plain.decode("utf-8", errors="replace")
        lines = text.count("\n") + 1
        total_lines += lines
        reqs = []
        for line in text.splitlines():
            s = line.strip()
            if s.startswith('require '):
                reqs.append(s.split('"')[1] if '"' in s else s)
        index.append({"file": fn[:-3] + ".lua", "bytes": len(plain),
                      "lines": lines, "require": reqs})
        ok += 1

    with open(os.path.join(a.out, "_index.json"), "w", encoding="utf-8") as f:
        json.dump({"count": ok, "total_lines": total_lines,
                   "failed": fail, "files": index}, f, ensure_ascii=False, indent=2)

    print("解密成功: %d / 失败: %d" % (ok, len(fail)))
    print("明文总行数: %d" % total_lines)
    print("输出目录: %s" % a.out)
    for fn, err in fail:
        print("  FAIL %s: %s" % (fn, err))
    print("\n脚本引用关系 (require 其它模块的文件):")
    for it in index:
        if it["require"]:
            print("  %-38s -> %s" % (it["file"], ", ".join(it["require"][:4])))


if __name__ == "__main__":
    sys.stdout.reconfigure(encoding="utf-8")
    main()
