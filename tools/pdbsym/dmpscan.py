import struct, sys
path = sys.argv[1]
data = open(path,'rb').read()
sig, ver, nstreams, dirrva, checksum, ts, flags = struct.unpack_from('<IIIIIIQ', data, 0)
streams = {}
for i in range(nstreams):
    t, sz, rva = struct.unpack_from('<III', data, dirrva + i*12)
    streams[t] = (sz, rva)
if 6 in streams:
    sz, rva = streams[6]
    tid, align = struct.unpack_from('<II', data, rva)
    rec = rva + 8
    code, flg, rec2, addr = struct.unpack_from('<IIQQ', data, rec)
    nparams = struct.unpack_from('<I', data, rec+24)[0]
    print("exception code=0x%08X addr=0x%016X nparams=%d" % (code, addr, nparams))
    for i in range(min(nparams,4)):
        p = struct.unpack_from('<Q', data, rec+32+i*8)[0]
        print("  param[%d]=0x%X" % (i, p))
if 3 in streams:
    sz, rva = streams[3]
    nthr = struct.unpack_from('<I', data, rva)[0]
    off = rva + 4
    mains = []
    for i in range(nthr):
        tid, susp, pcls, prio, teb, st0, st1, stsz, strva, csz, crva, esz, erv = struct.unpack_from('<IIIIIQQIIIIII', data, off)
        off += 48
        # scan stack memory for pointers into Haizeiwang.exe image (0x10000000..0x10200000)
        if strva and stsz:
            mem = data[strva:strva+stsz]
            for j in range(0, len(mem)-7, 4):
                v = struct.unpack_from('<Q', mem, j)[0]
                if 0x10000000 <= v < 0x10200000:
                    mains.append((tid, v-0x10000000))
    print("codeptr count=%d" % len(mains))
    for tid, rva in mains[:40]:
        print("tid=%d RVA=0x%X" % (tid, rva))
