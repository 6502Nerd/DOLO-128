"""Minimal FAT16 writer for the DOLO-128 SD card image.

Usage: python sdput.py <image> <local file> </DIR/SUBDIR/NAME.EXT>

Creates any missing directories and replaces the file if it already exists.
Only 8.3 names are supported (which is all the DOLO-128 file system uses).
"""
import struct
import sys

ATTR_DIR = 0x10


class Fat16:
    def __init__(self, path):
        self.f = open(path, 'r+b')
        mbr = self.read(0, 512)
        self.base = struct.unpack('<I', mbr[454:458])[0] * 512
        bs = self.read(self.base, 512)
        (self.bps, self.spc, res, self.nfats, self.rootents,
         _tot16, _media, self.spf) = struct.unpack('<HBHBHHBH', bs[11:24])
        self.fat_off = self.base + res * self.bps
        self.root_off = self.fat_off + self.nfats * self.spf * self.bps
        self.data_off = self.root_off + self.rootents * 32
        self.csize = self.spc * self.bps
        self.fat = bytearray(self.read(self.fat_off, self.spf * self.bps))
        self.nclusters = len(self.fat) // 2

    def read(self, off, n):
        self.f.seek(off)
        return self.f.read(n)

    def write(self, off, data):
        self.f.seek(off)
        self.f.write(data)

    # --- FAT helpers ---
    def get(self, c):
        return struct.unpack_from('<H', self.fat, c * 2)[0]

    def put(self, c, v):
        struct.pack_into('<H', self.fat, c * 2, v)

    def chain(self, c):
        out = []
        while 2 <= c < 0xFFF8:
            out.append(c)
            c = self.get(c)
        return out

    def free_chain(self, c):
        for x in self.chain(c):
            self.put(x, 0)

    def alloc(self, n):
        free = [c for c in range(2, self.nclusters) if self.get(c) == 0][:n]
        if len(free) < n:
            raise RuntimeError('disk full')
        for a, b in zip(free, free[1:]):
            self.put(a, b)
        if free:
            self.put(free[-1], 0xFFFF)
        return free

    def coff(self, c):
        return self.data_off + (c - 2) * self.csize

    def flush(self):
        for i in range(self.nfats):
            self.write(self.fat_off + i * self.spf * self.bps, bytes(self.fat))
        self.f.flush()

    # --- directory helpers: a dir is None (root) or a start cluster ---
    def dir_slots(self, d):
        if d is None:
            return [self.root_off + i * 32 for i in range(self.rootents)]
        return [self.coff(c) + i * 32 for c in self.chain(d)
                for i in range(self.csize // 32)]

    def find(self, d, name):
        for off in self.dir_slots(d):
            e = self.read(off, 32)
            if e[0] == 0:
                break
            if e[0] != 0xE5 and e[11] != 0x0F and e[:11] == name:
                return off, e
        return None, None

    def free_slot(self, d):
        for off in self.dir_slots(d):
            if self.read(off, 1)[0] in (0, 0xE5):
                return off
        if d is None:
            raise RuntimeError('root directory full')
        last = self.chain(d)[-1]
        c = self.alloc(1)[0]
        self.put(last, c)
        self.write(self.coff(c), bytes(self.csize))
        return self.coff(c)

    @staticmethod
    def entry(name, attr, cluster, size):
        # time/date: 12:00 1-Jan-2026
        t, dt = 12 << 11, ((2026 - 1980) << 9) | (1 << 5) | 1
        return struct.pack('<11sBBBHHHHHHHI', name, attr, 0, 0, t, dt, dt, 0,
                           t, dt, cluster, size)

    def mkdir(self, parent, name):
        c = self.alloc(1)[0]
        blk = bytearray(self.csize)
        blk[0:32] = self.entry(b'.          ', ATTR_DIR, c, 0)
        blk[32:64] = self.entry(b'..         ', ATTR_DIR, parent or 0, 0)
        self.write(self.coff(c), bytes(blk))
        self.write(self.free_slot(parent), self.entry(name, ATTR_DIR, c, 0))
        return c

    def putfile(self, d, name, data):
        off, e = self.find(d, name)
        if e is not None:
            self.free_chain(struct.unpack_from('<H', e, 26)[0])
        else:
            off = self.free_slot(d)
        n = (len(data) + self.csize - 1) // self.csize
        cl = self.alloc(n)
        for i, c in enumerate(cl):
            chunk = data[i * self.csize:(i + 1) * self.csize]
            self.write(self.coff(c), chunk.ljust(self.csize, b'\0'))
        self.write(off, self.entry(name, 0x20, cl[0] if cl else 0, len(data)))


def name83(s):
    s = s.upper()
    base, _, ext = s.partition('.')
    if not (1 <= len(base) <= 8 and len(ext) <= 3):
        raise ValueError('not an 8.3 name: ' + s)
    return (base.ljust(8) + ext.ljust(3)).encode('ascii')


def main():
    img, local, target = sys.argv[1:4]
    parts = [p for p in target.replace('\\', '/').split('/') if p]
    fs = Fat16(img)
    d = None
    for p in parts[:-1]:
        nm = name83(p)
        _, e = fs.find(d, nm)
        if e is None:
            d = fs.mkdir(d, nm)
        elif e[11] & ATTR_DIR:
            d = struct.unpack_from('<H', e, 26)[0]
        else:
            raise RuntimeError(p + ' is not a directory')
    with open(local, 'rb') as fh:
        fs.putfile(d, name83(parts[-1]), fh.read())
    fs.flush()
    print('wrote', local, '->', target)


if __name__ == '__main__':
    main()
