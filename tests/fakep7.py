import sys
src, dst = sys.argv[1], sys.argv[2]
data = bytearray(open(src, "rb").read())
head = data[:4 * 1024 * 1024]
# DOVIDecoderConfigurationRecord P8.1, level 6, rpu+bl: 01 00 10 35 10
rec = bytes([0x01, 0x00, 0x10, 0x35, 0x10])
i = head.find(rec)
t = head.find(b"dvvC")
typ = head.find(bytes([0x64, 0x76, 0x76, 0x43]))
print("record at", i, "dvvC string at", t, "type at", typ)
if i < 0:
    sys.exit("record not found")
# Profil 7 (data[2] = 7<<1 | level>>5), level 6, rpu+el+bl, compat 6
data[i:i + 5] = bytes([0x01, 0x00, 0x0E, 0x37, 0x60])
# BlockAddIDType 'dvvC' -> 'dvcC' (uint 0x64766343)
if typ >= 0:
    data[typ:typ + 4] = b"dvcC"
open(dst, "wb").write(data)
print("ok")
