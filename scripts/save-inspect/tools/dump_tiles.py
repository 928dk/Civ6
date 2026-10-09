#!/usr/bin/env python3
"""Dump the plot array of a .Civ6Save file to a TSV for forensics.
Replicates lucienmaloney/civ6save-editing decompress + tile walk."""
import zlib, struct, sys

def decompress(path):
    data = open(path, 'rb').read()
    modindex = data.rfind(b'MOD_TITLE')
    bufstart = data.index(b'\x78\x9c', modindex)
    bufend = data.rfind(b'\x00\x00\xff\xff')
    blob = data[bufstart:bufend]
    chunk = 64 * 1024
    chunks = []
    pos = 0
    while pos < len(blob):
        chunks.append(blob[pos:pos + chunk])
        pos += chunk + 4
    return zlib.decompress(b''.join(chunks))

def main(path, outpath):
    bin_ = decompress(path)
    sig = b'\x0e\x00\x00\x00\x0f\x00\x00\x00\x06\x00\x00\x00'
    idx = bin_.find(sig)
    if idx < 0:
        print("map signature not found"); return
    n = struct.unpack_from('<I', bin_, idx + 12)[0]
    W = 84 if n == 4536 else 106 if n == 6996 else 60 if n == 2280 else 96 if n == 5760 else 74 if n == 3404 else 44 if n == 1144 else 0
    H = n // W
    m = idx + 16
    rows = []
    for i in range(n):
        num2 = bin_[m + 49]
        num = struct.unpack_from('<I', bin_, m + 51)[0]
        bl = 0
        if num: bl += 24
        if num2 >= 64: bl += 17
        rows.append((
            i, i % W, i // W,
            struct.unpack_from('<I', bin_, m + 12)[0],
            struct.unpack_from('<i', bin_, m + 16)[0],
            bin_[m + 12:m + 20].hex(),
            struct.unpack_from('<h', bin_, m + 20)[0],
            bin_[m + 22:m + 26].hex(),
            bin_[m + 26],
            struct.unpack_from('<I', bin_, m + 27)[0],
            struct.unpack_from('<h', bin_, m + 31)[0],
            bin_[m + 33:m + 37].hex(),
            bin_[m + 37], bin_[m + 38], bin_[m + 39],
            struct.unpack_from('<h', bin_, m + 40)[0],
            bin_[m + 42], bin_[m + 43], bin_[m + 44],
            bin_[m + 45], bin_[m + 46], bin_[m + 47],
            bin_[m + 48:m + 51].hex(),
            num2, num, bl,
            bin_[m + 55:m + 55 + bl].hex(),
        ))
        m += 55 + bl
    hdr = ['i', 'x', 'y', 'terrain32_12', 'feature32_16', 'int8_12_19_hex',
           'i16_20', 'terrain2_22_hex', 'i8_26', 'res32_27', 'resbool_31',
           'goody33_hex', 'i8_37', 'road_38', 'i8b_39', 'appeal_40',
           'i8c_42', 'i8d_43', 'i8e_44', 'river_45', 'rivermap_46', 'cliff_47',
           'q9_48_hex', 'num2_49', 'num_51', 'buflen', 'buf_hex']
    with open(outpath, 'w') as f:
        f.write('\t'.join(hdr) + '\n')
        for r in rows:
            f.write('\t'.join(str(v) for v in r) + '\n')
    print(f"wrote {outpath}: {n} tiles ({W}x{H}), map section end at 0x{m:x}, trailing {len(bin_) - m} bytes")

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])