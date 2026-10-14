"""Write a tileable paper-grain PNG (standard library only)."""
import random
import struct
import zlib


def png(path, w, h, rows):
    def chunk(t, d):
        c = struct.pack('>I', len(d)) + t + d
        return c + struct.pack('>I', zlib.crc32(t + d) & 0xffffffff)
    raw = b''.join(b'\x00' + bytes(r) for r in rows)
    data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
    data += chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    with open(path, 'wb') as f:
        f.write(data)


def make(path, size=256, seed=7):
    rnd = random.Random(seed)
    # value noise at two scales, wrapped so the tile repeats seamlessly
    def lattice(n):
        return [[rnd.random() for _ in range(n)] for _ in range(n)]
    coarse = lattice(32)
    fine = lattice(size)

    def sample(g, n, x, y):
        fx, fy = x * n / size, y * n / size
        x0, y0 = int(fx) % n, int(fy) % n
        x1, y1 = (x0 + 1) % n, (y0 + 1) % n
        tx, ty = fx - int(fx), fy - int(fy)
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = g[y0][x0] + (g[y0][x1] - g[y0][x0]) * tx
        b = g[y1][x0] + (g[y1][x1] - g[y1][x0]) * tx
        return a + (b - a) * ty
    rows = []
    for y in range(size):
        row = []
        for x in range(size):
            v = 0.75 * fine[y][x] + 0.25 * sample(coarse, 32, x, y)
            # dark or light speck depending on the side of the mean; faint alpha
            if v < 0.5:
                g, a = 70, int((0.5 - v) * 2 * 34)
                row += [g, g - 10, g - 22, a]
            else:
                g, a = 255, int((v - 0.5) * 2 * 30)
                row += [g, g - 4, g - 14, a]
        rows.append(row)
    png(path, size, size, rows)




def make_wobble(path, size=256, seed=11, cells=8):
    """Smooth tileable RGB noise used as a displacement map (pencil wobble)."""
    rnd = random.Random(seed)
    gx = [[rnd.random() for _ in range(cells)] for _ in range(cells)]
    gy = [[rnd.random() for _ in range(cells)] for _ in range(cells)]

    def sample(g, x, y):
        fx, fy = x * cells / size, y * cells / size
        x0, y0 = int(fx) % cells, int(fy) % cells
        x1, y1 = (x0 + 1) % cells, (y0 + 1) % cells
        tx, ty = fx - int(fx), fy - int(fy)
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        a = g[y0][x0] + (g[y0][x1] - g[y0][x0]) * tx
        b = g[y1][x0] + (g[y1][x1] - g[y1][x0]) * tx
        return a + (b - a) * ty
    rows = []
    for y in range(size):
        row = []
        for x in range(size):
            row += [int(255 * sample(gx, x, y)), int(255 * sample(gy, x, y)), 128, 255]
        rows.append(row)
    png(path, size, size, rows)


if __name__ == '__main__':
    import sys
    make(sys.argv[1] if len(sys.argv) > 1 else 'grain.png')
