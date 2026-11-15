import struct, sys
path = sys.argv[1]
data = open(path,'rb').read()
sig, ver, nstreams, dirrva, checksum, ts, flags = struct.unpack_from('<IIIIIIQ', data, 0)
streams = {}
for i in range(nstreams):
    t, sz, rva = struct.unpack_from('<III', data, dirrva + i*12)
    streams[t] = (sz, rva)
sz, rva = streams[3]
nthr = struct.unpack_from('<I', data, rva)[0]
off = rva + 4
results = []
for i in range(nthr):
    tid, susp, pcls, prio, teb, st0, st1, stsz, strva, csz, crva, esz, erv = struct.unpack_from('<IIIIIQQIIIIII', data, off)
    off += 48
    if not (strva and stsz): continue
    mem = data[strva:strva+stsz]
    prev = -16
    for j in range(0, len(mem)-7, 4):
        v = struct.unpack_from('<Q', mem, j)[0]
        r = v - 0x10000000
        if 0x1000 <= r < 0x400000 and j > prev+8:  # plausible code addrs, dedup adjacent
            results.append((tid, r, j))
            prev = j
for tid, r, offj in results[:50]:
    print("tid=%d stackoff=0x%X RVA=0x%X" % (tid, offj, r))
