"""C64 image helpers: palette mapping, hires / multicolor bitmap conversion and
renderers (used both by the asset generator and for visual verification)."""
from PIL import Image

# Pepto palette (the palette the supplied Multipaint assets use)
PALETTE = [
    0x000000, 0xffffff, 0x68372b, 0x70a4b2, 0x6f3d86, 0x588d43, 0x352879, 0xb8c76f,
    0x6f4f25, 0x433900, 0x9a6759, 0x444444, 0x6c6c6c, 0x9ad284, 0x6c5eb5, 0x959595,
]
RGB2IDX = {p: i for i, p in enumerate(PALETTE)}


def rgb(i):
    p = PALETTE[i]
    return (p >> 16) & 255, (p >> 8) & 255, p & 255


def load_indexed(path):
    """Load a 320x200 PNG into a list of 200 rows of 320 colour indices."""
    im = Image.open(path).convert("RGB")
    assert im.size == (320, 200), (path, im.size)
    px = im.load()
    rows = []
    for y in range(200):
        row = []
        for x in range(320):
            p = px[x, y]
            key = (p[0] << 16) | (p[1] << 8) | p[2]
            row.append(RGB2IDX[key])
        rows.append(row)
    return rows


# ----------------------------------------------------------------- hires
def hires_convert(idx):
    """320x200 index image -> (bitmap[8000], screen[1000]).
    Bit set = foreground = high nibble of the screen byte."""
    bmp = bytearray(8000)
    scr = bytearray(1000)
    for cy in range(25):
        for cx in range(40):
            cols = set()
            for y in range(8):
                for x in range(8):
                    cols.add(idx[cy * 8 + y][cx * 8 + x])
            cols = sorted(cols)
            if len(cols) > 2:
                raise ValueError("hires cell %d,%d has %d colours" % (cx, cy, len(cols)))
            if len(cols) == 1:
                bg = fg = cols[0]
            else:
                bg, fg = cols[0], cols[1]
                # keep black as background when present (better compression)
            scr[cy * 40 + cx] = (fg << 4) | bg
            for y in range(8):
                b = 0
                for x in range(8):
                    if idx[cy * 8 + y][cx * 8 + x] == fg and fg != bg:
                        b |= 0x80 >> x
                bmp[(cy * 40 + cx) * 8 + y] = b
    return bmp, scr


def render_hires(bmp, scr):
    im = Image.new("RGB", (320, 200))
    px = im.load()
    for cy in range(25):
        for cx in range(40):
            s = scr[cy * 40 + cx]
            fg, bg = s >> 4, s & 15
            for y in range(8):
                b = bmp[(cy * 40 + cx) * 8 + y]
                for x in range(8):
                    px[cx * 8 + x, cy * 8 + y] = rgb(fg if b & (0x80 >> x) else bg)
    return im


# ------------------------------------------------------------ multicolor
def mc_canvas_from_indexed(idx):
    """320x200 (double-wide pixel) image -> 160x200 canvas of indices."""
    cv = []
    for y in range(200):
        row = []
        for x in range(0, 320, 2):
            assert idx[y][x] == idx[y][x + 1], "not a multicolor image"
            row.append(idx[y][x])
        cv.append(row)
    return cv


def mc_convert(cv, bgcol=0, prev=None):
    """160x200 canvas -> (bitmap[8000], screen[1000], color[1000]).
    %00 = background, %01 = screen high nibble, %10 = screen low nibble,
    %11 = colour RAM."""
    bmp = bytearray(8000)
    scr = bytearray(1000)
    col = bytearray(1000)
    for cy in range(25):
        for cx in range(40):
            cnt = {}
            for y in range(8):
                for x in range(4):
                    c = cv[cy * 8 + y][cx * 4 + x]
                    cnt[c] = cnt.get(c, 0) + 1
            cols = sorted(c for c in cnt if c != bgcol)
            if len(cols) > 3:
                # keep the three most frequent, others map to nearest of those
                keep = sorted(sorted(cols, key=lambda c: -cnt[c])[:3])
                cols = keep
            slots = {}
            for i, c in enumerate(cols):
                slots[c] = i + 1  # %01, %10, %11
            def nearest(c):
                if c == bgcol or c in slots:
                    return c
                best = None
                r0 = rgb(c)
                for k in [bgcol] + cols:
                    r1 = rgb(k)
                    d = sum((a - b) ** 2 for a, b in zip(r0, r1))
                    if best is None or d < best[0]:
                        best = (d, k)
                return best[1]
            for y in range(8):
                b = 0
                for x in range(4):
                    c = nearest(cv[cy * 8 + y][cx * 4 + x])
                    v = 0 if c == bgcol else slots[c]
                    b |= v << (6 - 2 * x)
                bmp[(cy * 40 + cx) * 8 + y] = b
            c1 = cols[0] if len(cols) > 0 else 0
            c2 = cols[1] if len(cols) > 1 else 0
            c3 = cols[2] if len(cols) > 2 else 0
            scr[cy * 40 + cx] = (c1 << 4) | c2
            col[cy * 40 + cx] = c3
    return bmp, scr, col


def render_mc(bmp, scr, col, bgcol=0):
    im = Image.new("RGB", (320, 200))
    px = im.load()
    for cy in range(25):
        for cx in range(40):
            s = scr[cy * 40 + cx]
            pal = [bgcol, s >> 4, s & 15, col[cy * 40 + cx] & 15]
            for y in range(8):
                b = bmp[(cy * 40 + cx) * 8 + y]
                for x in range(4):
                    v = (b >> (6 - 2 * x)) & 3
                    c = rgb(pal[v])
                    px[cx * 8 + x * 2, cy * 8 + y] = c
                    px[cx * 8 + x * 2 + 1, cy * 8 + y] = c
    return im
