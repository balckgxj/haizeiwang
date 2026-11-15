# -*- coding: utf-8 -*-
"""[haizei] 把 server_patch/ 下的 Java 补丁增量编译进运行中的 DZM.jar。

用法：
    python tools/gm_admin/apply_server_patch.py            # 仅编译并校验
    python tools/gm_admin/apply_server_patch.py --apply    # 编译 + 备份 + 写入 DZM.jar

注意：--apply 前必须先停掉 DZM 服务端（Windows 会锁住 jar）。
服务端源码目录含中文/括号，javac 无法解析该 classpath，因此脚本先把
DZM.jar 与 lib/*.jar 复制到项目内的纯 ASCII 构建目录再编译。
"""
import glob
import os
import shutil
import subprocess
import sys
import zipfile

PROJ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TOOLS = os.path.join(PROJ, "tools", "gm_admin")
PATCH = os.path.join(TOOLS, "server_patch")
BUILD = os.path.join(PROJ, "_tools", "dzmbuild")
SRV = r"E:\BaiduNetdiskDownload\(SY-096)草M船Z\src\src\server\Code_Server\server"
JAR = os.path.join(SRV, "DZM.jar")
JAVAC = r"E:\Softwares\jdk8u512-b09\bin\javac.exe"

SOURCES = [
    r"com\oldmountain\dzm\util\GmWhitelist.java",
    r"com\oldmountain\dzm\packethandler\LoginHandler.java",
    r"com\oldmountain\dzm\net\packet\PacketHandler.java",
]


def prepare():
    libdir = os.path.join(BUILD, "lib")
    out = os.path.join(BUILD, "out")
    os.makedirs(libdir, exist_ok=True)
    if os.path.isdir(out):
        shutil.rmtree(out)
    os.makedirs(out)
    shutil.copy2(JAR, os.path.join(BUILD, "DZM.jar"))
    for p in glob.glob(os.path.join(SRV, "lib", "*.jar")):
        shutil.copy2(p, os.path.join(libdir, os.path.basename(p)))
    return out


def compile_patch(out):
    jars = [os.path.join(BUILD, "DZM.jar")] + glob.glob(os.path.join(BUILD, "lib", "*.jar"))
    cp = ";".join(jars)
    files = [os.path.join(PATCH, s) for s in SOURCES]
    for f in files:
        if not os.path.isfile(f):
            raise RuntimeError("missing patch source: " + f)
    cmd = [JAVAC, "-encoding", "UTF-8", "-cp", cp, "-d", out] + files
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    txt = r.stdout.decode("utf-8", "replace")
    if r.returncode != 0:
        raise RuntimeError("javac failed:\n" + txt)
    print("javac OK (%d classpath jars)" % len(jars))
    return {
        os.path.relpath(p, out).replace("\\", "/"): open(p, "rb").read()
        for p in glob.glob(os.path.join(out, "**", "*.class"), recursive=True)
    }


def apply(classes):
    bak = JAR + ".haizei_bak"
    if not os.path.isfile(bak):
        shutil.copy2(JAR, bak)
        print("backup:", bak)
    tmp = JAR + ".tmp"
    with zipfile.ZipFile(bak, "r") as zin, zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as zout:
        remaining = dict(classes)
        for item in zin.infolist():
            data = remaining.pop(item.filename, None)
            zout.writestr(item, zin.read(item.filename) if data is None else data)
        for name, data in remaining.items():
            zout.writestr(name, data)
    os.replace(tmp, JAR)
    with zipfile.ZipFile(JAR) as z:
        names = set(z.namelist())
    for name in classes:
        assert name in names, "not in jar: " + name
    print("patched DZM.jar with %d classes:" % len(classes))
    for name in sorted(classes):
        print("  ", name)


def main():
    if not os.path.isfile(JAR):
        raise RuntimeError("DZM.jar not found: " + JAR)
    out = prepare()
    classes = compile_patch(out)
    print("compiled:", ", ".join(sorted(classes)))
    if "--apply" in sys.argv:
        apply(classes)
        print("done. restart DZM server to take effect.")
    else:
        print("dry-run only; pass --apply to write DZM.jar (stop the server first).")


if __name__ == "__main__":
    main()
