#!/usr/bin/env python3
"""Generates all binary assets for the C64 FNaF port into build/gen/.

  office.bmp/.scr        hires office (base state)
  patches.bin            door / light patches for both sides (see PATCH layout)
  sprites.bin            sprite images (button icons, REC indicator)
  cam_NN_F.bmp/.scr/.col multicolor camera frames with the HUD baked in
"""
import os
import sys
import glob
from c64img import *

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
OUT = os.path.join(ROOT, "build", "gen")
os.makedirs(OUT, exist_ok=True)

# ---------------------------------------------------------------- font 3x5
FONT = {
    'A': ["010", "101", "111", "101", "101"],
    'B': ["110", "101", "110", "101", "110"],
    'C': ["011", "100", "100", "100", "011"],
    'D': ["110", "101", "101", "101", "110"],
    'E': ["111", "100", "110", "100", "111"],
    'F': ["111", "100", "110", "100", "100"],
    'G': ["011", "100", "101", "101", "011"],
    'H': ["101", "101", "111", "101", "101"],
    'I': ["111", "010", "010", "010", "111"],
    'J': ["001", "001", "001", "101", "010"],
    'K': ["101", "101", "110", "101", "101"],
    'L': ["100", "100", "100", "100", "111"],
    'M': ["101", "111", "111", "101", "101"],
    'N': ["110", "101", "101", "101", "101"],
    'O': ["010", "101", "101", "101", "010"],
    'P': ["110", "101", "110", "100", "100"],
    'Q': ["010", "101", "101", "110", "011"],
    'R': ["110", "101", "110", "101", "101"],
    'S': ["011", "100", "010", "001", "110"],
    'T': ["111", "010", "010", "010", "010"],
    'U': ["101", "101", "101", "101", "111"],
    'V': ["101", "101", "101", "101", "010"],
    'W': ["101", "101", "111", "111", "101"],
    'X': ["101", "101", "010", "101", "101"],
    'Y': ["101", "101", "010", "010", "010"],
    'Z': ["111", "001", "010", "100", "111"],
    '0': ["111", "101", "101", "101", "111"],
    '1': ["010", "110", "010", "010", "111"],
    '2': ["110", "001", "010", "100", "111"],
    '3': ["110", "001", "010", "001", "110"],
    '4': ["101", "101", "111", "001", "001"],
    '5': ["111", "100", "110", "001", "110"],
    '6': ["011", "100", "111", "101", "111"],
    '7': ["111", "001", "010", "010", "010"],
    '8': ["111", "101", "111", "101", "111"],
    '9': ["111", "101", "111", "001", "110"],
    '.': ["000", "000", "000", "000", "010"],
    '-': ["000", "000", "111", "000", "000"],
    ':': ["000", "010", "000", "010", "000"],
    "'": ["010", "010", "000", "000", "000"],
    ' ': ["000", "000", "000", "000", "000"],
}


def text_width(s, scale=1):
    return (len(s) * 4 - 1) * scale


def draw_text(cv, x, y, s, color, scale=1, sx=1):
    """Draw text into a canvas (list of rows). Returns nothing."""
    for ch in s:
        g = FONT.get(ch, FONT[' '])
        for gy, row in enumerate(g):
            for gx, c in enumerate(row):
                if c == '1':
                    for dy in range(scale):
                        for dx in range(sx):
                            xx = x + gx * sx + dx
                            yy = y + gy * scale + dy
                            if 0 <= yy < len(cv) and 0 <= xx < len(cv[0]):
                                cv[yy][xx] = color
        x += 4 * sx


# ------------------------------------------------------------------ cams
# name, asset dir, default frame, (key label), hud grid position (col,row)
CAMS = [
    ("1A", "stage", "SHOW STAGE", (1, 0)),
    ("1B", "party room", "DINING AREA", (1, 1)),
    ("1C", "foxy tage", "PIRATE COVE", (1, 2)),
    ("2A", "left hallway", "WEST HALL", (1, 3)),
    ("2B", "left corner", "W. HALL CORNER", (1, 4)),
    ("3", "cabinet", "SUPPLY CLOSET", (0, 4)),
    ("4A", "right hallway", "EAST HALL", (2, 3)),
    ("4B", "right corner", "E. HALL CORNER", (2, 4)),
    ("5", "service room", "BACKSTAGE", (0, 2)),
    ("6", None, "KITCHEN", (3, 2)),
    ("7", "restroom", "RESTROOMS", (3, 1)),
]

# HUD panel geometry (MC pixel canvas: 160x200; 4 px per cell)
PANEL_COL0, PANEL_ROW0 = 25, 17      # cell coordinates
PANEL_COLS, PANEL_ROWS = 14, 7
BTN_X0, BTN_Y0 = PANEL_COL0 * 4 + 2, PANEL_ROW0 * 8 + 8  # first button top-left
BTN_W, BTN_H = 11, 7
BTN_PX, BTN_PY = 12, 8


def draw_plate(cv, col0, row0, cols, rows, color=0):
    for y in range(row0 * 8, (row0 + rows) * 8):
        for x in range(col0 * 4, (col0 + cols) * 4):
            cv[y][x] = color


def hud_overlay(cv, camidx):
    """Draw label + camera map with the given camera highlighted."""
    name, _, title, _ = CAMS[camidx]
    # title plate
    label = "CAM %s - %s" % (name, title)
    cols = len(label)
    draw_plate(cv, 1, 1, cols + 1, 1, 0)
    draw_text(cv, 1 * 4 + 1, 1 * 8 + 1, label, 1)
    # map plate with outline
    draw_plate(cv, PANEL_COL0, PANEL_ROW0, PANEL_COLS, PANEL_ROWS, 0)
    x0, y0 = PANEL_COL0 * 4, PANEL_ROW0 * 8
    x1, y1 = (PANEL_COL0 + PANEL_COLS) * 4 - 1, (PANEL_ROW0 + PANEL_ROWS) * 8 - 1
    for x in range(x0, x1 + 1):
        cv[y0][x] = 11
        cv[y1][x] = 11
    for y in range(y0, y1 + 1):
        cv[y][x0] = 11
        cv[y][x1] = 11
    for i, (n, _, _, (gc, gr)) in enumerate(CAMS):
        bx = BTN_X0 + gc * BTN_PX
        by = BTN_Y0 + gr * BTN_PY
        sel = (i == camidx)
        fill = 5 if sel else 11       # green when selected, dark grey otherwise
        txt = 0 if sel else 15
        for y in range(BTN_H):
            for x in range(BTN_W):
                cv[by + y][bx + x] = fill
        w = text_width(n)
        tx = bx + (BTN_W - w) // 2
        draw_text(cv, tx, by + 1, n, txt)


def kitchen_canvas():
    cv = [[0] * 160 for _ in range(200)]
    s = "AUDIO ONLY"
    w = (len(s) * 4 - 1) * 3
    draw_text(cv, (160 - w) // 2 - 1, 90, s, 12, scale=3, sx=3)
    draw_text(cv, (160 - text_width("CAMERA DISABLED")) // 2, 120, "CAMERA DISABLED", 11)
    return cv


def gen_cams():
    files = []
    for ci, (name, adir, title, _) in enumerate(CAMS):
        if adir is None:
            frames = [kitchen_canvas()]
        else:
            paths = sorted(glob.glob(os.path.join(ASSETS, "camera", adir, "[0-9].png")))
            frames = [mc_canvas_from_indexed(load_indexed(p)) for p in paths]
        for fi, cv in enumerate(frames):
            cv = [row[:] for row in cv]
            hud_overlay(cv, ci)
            bmp, scr, col = mc_convert(cv)
            base = os.path.join(OUT, "cam_%02d_%d" % (ci, fi))
            open(base + ".bmp", "wb").write(bmp)
            open(base + ".scr", "wb").write(scr)
            open(base + ".col", "wb").write(col)
            files.append((ci, fi))
            if fi == 0:
                render_mc(bmp, scr, col).save(os.path.join(OUT, "prev_cam_%02d.png" % ci))
    return files


# ---------------------------------------------------------------- office
PATCH_ROW0, PATCH_ROWS, PATCH_COLS = 3, 22, 9
LEFT_COL0, RIGHT_COL0 = 2, 29
REC_SIZE = PATCH_COLS * 8 + PATCH_COLS  # 81 bytes: 72 bitmap + 9 screen


def office_state(name):
    return hires_convert(load_indexed(os.path.join(ASSETS, "office", "office %s.png" % name)))


def patch_records(state, col0, rows=None):
    bmp, scr = state
    recs = []
    for r in (rows if rows is not None else range(PATCH_ROW0, PATCH_ROW0 + PATCH_ROWS)):
        b = bytearray()
        for cx in range(col0, col0 + PATCH_COLS):
            b += bmp[(r * 40 + cx) * 8:(r * 40 + cx) * 8 + 8]
        s = bytes(scr[r * 40 + col0:r * 40 + col0 + PATCH_COLS])
        recs.append(bytes(b) + s)
    return recs


def gen_office():
    normal = office_state("normal")
    light = office_state("dorelight")
    closed = office_state("door_2")
    half = office_state("door_1")
    open(os.path.join(OUT, "office.bmp"), "wb").write(normal[0])
    open(os.path.join(OUT, "office.scr"), "wb").write(normal[1])
    # patches: per side: N(22) L(22) C(22) S(2)  -> 68 records of 81 bytes
    out = bytearray()
    for col0 in (LEFT_COL0, RIGHT_COL0):
        for st in (normal, light, closed):
            out += b"".join(patch_records(st, col0))
        out += b"".join(patch_records(half, col0, rows=[11, 12]))
    open(os.path.join(OUT, "patches.bin"), "wb").write(out)
    return normal


# --------------------------------------------------------------- sprites
def sprite_from_rows(rows):
    """rows: list of 21 strings of 24 chars ('#' set) -> 63 bytes (+1 pad)"""
    assert len(rows) == 21
    b = bytearray()
    for r in rows:
        r = r.ljust(24, ".")
        assert len(r) == 24, r
        for i in range(3):
            v = 0
            for k in range(8):
                if r[i * 8 + k] == '#':
                    v |= 0x80 >> k
            b.append(v)
    b.append(0)
    return bytes(b)


def sprite_canvas():
    return [["." for _ in range(24)] for _ in range(21)]


def sp_text(cv, x, y, s):
    for ch in s:
        g = FONT.get(ch, FONT[' '])
        for gy, row in enumerate(g):
            for gx, c in enumerate(row):
                if c == '1':
                    cv[y + gy][x + gx] = '#'
        x += 4


def sp_disc(cv, cx, cy, r, filled=True, ring=2):
    for y in range(21):
        for x in range(24):
            d2 = (x - cx) ** 2 + (y - cy) ** 2
            if filled:
                if d2 <= r * r:
                    cv[y][x] = '#'
            else:
                if (r - ring) ** 2 < d2 <= r * r:
                    cv[y][x] = '#'


def button_sprite(label, filled, key):
    cv = sprite_canvas()
    w = len(label) * 4 - 1
    sp_text(cv, (24 - w) // 2, 0, label)
    sp_disc(cv, 11.5, 13.5, 7, filled=True if filled else False, ring=2)
    if filled:
        # carve the key letter out of the lit disc
        g = FONT[key]
        for gy, row in enumerate(g):
            for gx, c in enumerate(row):
                if c == '1':
                    cv[11 + gy][10 + gx] = '.'
    else:
        sp_text(cv, 10, 11, key)
    return sprite_from_rows(["".join(r) for r in cv])


def rec_sprite(dot):
    cv = sprite_canvas()
    if dot:
        sp_disc(cv, 3.5, 10, 3, filled=True)
    sp_text(cv, 9, 8, "REC")
    return sprite_from_rows(["".join(r) for r in cv])


def gen_sprites():
    # 0 left door ring, 1 left light ring, 2 right door ring, 3 right light ring,
    # 4-7 the same as lit (filled) overlays
    imgs = [
        button_sprite("DOOR", False, "A"),
        button_sprite("LIGHT", False, "S"),
        button_sprite("DOOR", False, "L"),
        button_sprite("LIGHT", False, "K"),
        button_sprite("DOOR", True, "A"),
        button_sprite("LIGHT", True, "S"),
        button_sprite("DOOR", True, "L"),
        button_sprite("LIGHT", True, "K"),
        rec_sprite(True),
    ]
    open(os.path.join(OUT, "sprites.bin"), "wb").write(b"".join(imgs))
    return imgs


def preview_office(normal, imgs):
    from PIL import ImageDraw
    im = render_hires(*normal)
    px = im.load()
    def blit(img, x, y, colr):
        for r in range(21):
            for c in range(24):
                if img[r * 3 + c // 8] & (0x80 >> (c % 8)):
                    if 0 <= x + c < 320 and 0 <= y + r < 200:
                        px[x + c, y + r] = colr
    sys.path.insert(0, os.path.dirname(__file__))
    import layout
    for (x, y, i, col) in layout.OFFICE_SPRITES_PREVIEW(imgs):
        blit(imgs[i], x, y, rgb(col))
    im.resize((640, 400), Image.NEAREST).save(os.path.join(OUT, "prev_office.png"))


def gen_lamp(normal):
    """Colour cells (screen RAM bytes) of the ceiling lamp: normal + dimmed variant."""
    dim = {1: 10, 10: 2}
    n = bytearray()
    m = bytearray()
    for r in range(5):
        for c in range(17, 23):
            v = normal[1][r * 40 + c]
            n.append(v)
            m.append((dim.get(v >> 4, v >> 4) << 4) | dim.get(v & 15, v & 15))
    open(os.path.join(OUT, "lamp.bin"), "wb").write(bytes(n + m))


def hires_plate(idx, x, y, w, h):
    for yy in range((y // 8) * 8, ((y + h + 7) // 8) * 8):
        for xx in range((x // 8) * 8, ((x + w + 7) // 8) * 8):
            if 0 <= yy < 200 and 0 <= xx < 320:
                idx[yy][xx] = 0


def hires_text(idx, x, y, s, color, sx=2, sy=2):
    """Draw text (3x5 font, scaled) into a 320x200 index image (cells must be plated first)."""
    cx = x
    for ch in s:
        g = FONT.get(ch, FONT[' '])
        for gy, row in enumerate(g):
            for gx, c in enumerate(row):
                if c == '1':
                    for dy in range(sy):
                        for dx in range(sx):
                            idx[y + gy * sy + dy][cx + gx * sx + dx] = color
        cx += 4 * sx


TITLE_KEYS = [
    ("A DOOR   S LIGHT  LEFT", 176),
    ("L DOOR   K LIGHT  RIGHT", 184),
    ("SPACE CAMERA  1-7 CAMS", 192),
]


def gen_title():
    idx = load_indexed(os.path.join(ASSETS, "lobby.png"))
    hires_plate(idx, 8, 172, 4 * 24, 26)
    for text, y in TITLE_KEYS:
        hires_text(idx, 8, y - 2, text, 15, sx=1, sy=1)
    b, s = hires_convert(idx)
    open(os.path.join(OUT, "title.bmp"), "wb").write(b)
    open(os.path.join(OUT, "title.scr"), "wb").write(s)
    render_hires(b, s).resize((640, 400), Image.NEAREST).save(os.path.join(OUT, "prev_title.png"))


if __name__ == "__main__":
    gen_title()
    normal = gen_office()
    gen_lamp(normal)
    imgs = gen_sprites()
    files = gen_cams()
    preview_office(normal, imgs)
    print("cam frames:", len(files))
