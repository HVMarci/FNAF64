#!/usr/bin/env python3
"""Generates all binary assets for the C64 FNaF port into build/gen/.

  office.bmp/.scr        hires office (base state)
  patches.bin            door / light patches for both sides (see PATCH layout), then the 4 buttons x 2 states
  sprites.bin            sprite image (REC indicator)
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
    ',': ["000", "000", "000", "010", "100"],
    '!': ["010", "010", "010", "000", "010"],
    '-': ["000", "000", "111", "000", "000"],
    ':': ["000", "010", "000", "010", "000"],
    "'": ["010", "010", "000", "000", "000"],
    '<': ["001", "011", "111", "011", "001"],       # the left arrow key (camera 0, the show stage), like the triangle on the map
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
# key label (the C64 key that selects the camera: left arrow, 1-9, 0; '<' is the arrow), asset dir, title.
# The order is the camera index used by the game (src/game.asm) and equals the order of the keys on the keyboard.
CAMS = [
    ("<", "stage", "SHOW STAGE"),
    ("1", "party_room", "DINING AREA"),
    ("2", "foxy_stage", "PIRATE COVE"),
    ("3", "left_hallway", "WEST HALL"),
    ("4", "left_corner", "W. HALL CORNER"),
    ("5", "cabinet", "SUPPLY CLOSET"),
    ("6", "right_hallway", "EAST HALL"),
    ("7", "right_corner", "E. HALL CORNER"),
    ("8", "service_room", "BACKSTAGE"),
    ("9", None, "KITCHEN"),
    ("0", "restroom", "RESTROOMS"),
]

# The camera map (assets/map.png, 320x200, only the map is drawn) is baked into every camera picture: bottom right,
# straight onto the picture (no plate), with the button of the selected camera lit up. Buttons are 5x7 multicolor pixels; top-left corners
# in the map image (multicolor pixels, same order as CAMS).
MAP_BTN_W, MAP_BTN_H = 5, 7
MAP_BTNS = [(64, 138), (62, 148), (59, 158), (62, 172), (62, 180), (52, 172), (79, 172), (79, 180),
            (52, 143), (93, 172), (93, 148)]
MAP_DX, MAP_DY = 55, -4              # where the map image goes in the camera picture (multicolor pixels)


def draw_plate(cv, col0, row0, cols, rows, color=0):
    for y in range(row0 * 8, (row0 + rows) * 8):
        for x in range(col0 * 4, (col0 + cols) * 4):
            cv[y][x] = color


# Runtime HUD fields in the camera view (cell coordinates; src/main.asm draws text there).
# They are baked as empty black plates so the runtime only has to write glyph pixels.
CAM_HUD_PLATES = [(29, 0, 10, 1), (25, 1, 14, 1), (1, 22, 23, 2)]     # col, row, cols, rows

MAP_IDX = mc_canvas_from_indexed(load_indexed(os.path.join(ASSETS, "map.png")))


def hud_overlay(cv, camidx):
    """Draw label + camera map with the given camera highlighted."""
    name, _, title = CAMS[camidx]
    for (pc, pr, pw, ph) in CAM_HUD_PLATES:
        draw_plate(cv, pc, pr, pw, ph, 0)
    # title plate
    label = "CAM %s - %s" % (name, title)
    cols = len(label)
    draw_plate(cv, 1, 1, cols + 1, 1, 0)
    draw_text(cv, 1 * 4 + 1, 1 * 8 + 1, label, 1)
    # the map, drawn over the camera picture
    m = [row[:] for row in MAP_IDX]
    bx, by = MAP_BTNS[camidx]
    for y in range(by, by + MAP_BTN_H):         # selected: green button, the key label stays white
        for x in range(bx, bx + MAP_BTN_W):
            m[y][x] = {11: 5}.get(m[y][x], m[y][x])
    for y in range(200):
        for x in range(160):
            c = m[y][x]
            ty, tx = y + MAP_DY, x + MAP_DX
            if c and 0 <= ty < 200 and 0 <= tx < 160:
                cv[ty][tx] = c


def kitchen_canvas():
    cv = [[0] * 160 for _ in range(200)]
    s = "AUDIO ONLY"
    w = (len(s) * 4 - 1) * 3
    draw_text(cv, (160 - w) // 2 - 1, 90, s, 12, scale=3, sx=3)
    draw_text(cv, (160 - text_width("CAMERA DISABLED")) // 2, 120, "CAMERA DISABLED", 11)
    return cv


def gen_cams():
    files = []
    for ci, (name, adir, title) in enumerate(CAMS):
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


def frame_counts():
    n = []
    for name, adir, title in CAMS:
        if adir is None:
            n.append(1)
        else:
            n.append(len(glob.glob(os.path.join(ASSETS, "camera", adir, "[0-9].png"))))
    return n


def gen_frames_asm():
    n = frame_counts()
    first, acc = [], 0
    for c in n:
        first.append(acc)
        acc += c
    with open(os.path.join(OUT, "frames.asm"), "w") as f:
        f.write("cam_first: .byte %s\n" % ",".join(map(str, first)))
        f.write("cam_nfr:   .byte %s\n" % ",".join(map(str, n)))
        f.write(".const NUM_FRAMES = %d\n" % acc)


# ---------------------------------------------------------------- office
PATCH_ROW0, PATCH_ROWS, PATCH_COLS = 3, 22, 9
LEFT_COL0, RIGHT_COL0 = 2, 29
# Only 7 of the 9 cells in a patch's span are ever copied: 5 door cells and 2 window cells (the 2 between
# them stay as they are), so a packed record is 7*8 bitmap + 7 screen bytes = 63 (src/defs.asm, CopyRec).
PATCH_CELLS = {LEFT_COL0: (0, 1, 2, 3, 4, 7, 8),       # door, then window
               RIGHT_COL0: (0, 1, 4, 5, 6, 7, 8)}      # window, then door
REC_SIZE = len(PATCH_CELLS[LEFT_COL0]) * 9              # 63


def office_state(name):
    return hires_convert(load_indexed(os.path.join(ASSETS, "office", "office_%s.png" % name)))


def patch_records(state, col0, rows=None):
    bmp, scr = state
    recs = []
    for r in (rows if rows is not None else range(PATCH_ROW0, PATCH_ROW0 + PATCH_ROWS)):
        b = bytearray()
        for c in PATCH_CELLS[col0]:
            cx = col0 + c
            b += bmp[(r * 40 + cx) * 8:(r * 40 + cx) * 8 + 8]
        s = bytes(scr[r * 40 + col0 + c] for c in PATCH_CELLS[col0])
        recs.append(bytes(b) + s)
    return recs


# The door / light buttons are part of the office pictures, two cells (16 pixel rows) each, in the column next to the door
# patches. Drawn at run time as 4 independent buttons: L door, L light, R door, R light (src/main.asm ButtonRender).
BUTTONS = [(1, 10), (1, 13), (38, 10), (38, 13)]       # (text column, upper text row)


def cell_data(state, col, row):
    bmp, scr = state
    return (b"".join(bytes(bmp[(r * 40 + col) * 8:(r * 40 + col) * 8 + 8]) for r in (row, row + 1))
            + bytes(scr[r * 40 + col] for r in (row, row + 1)))


def button_records(normal, light, closed):
    """4 buttons x (off, lit) x 18 bytes: bitmap of the upper cell, of the lower cell, their 2 screen bytes.
    A door button is lit (green) in the closed-door picture, a light button in the light-on picture; the same cells
    must look like in the normal picture in the other state, so the two buttons of a side are independent."""
    out = b""
    for i, (col, row) in enumerate(BUTTONS):
        door = i % 2 == 0
        off = cell_data(normal, col, row)
        on = cell_data(closed if door else light, col, row)
        assert on != off
        assert cell_data(light if door else closed, col, row) == off, "button %d depends on the other button" % i
        out += off + on
    return out


# The hazard strip of the door animation is a straight 2-row rectangle, but the top of the doorway is slanted: at the first
# two patch rows part of the strip's cells belongs to the frame and must stay hidden. Those four (row, strip row) cases
# get their own pre-masked records (per side 4 x 63 bytes, strip_msk in Code3): pixels outside the opening (black in
# the open office) keep the frame, the opening shows the strip. A cell that ends up with more than two colours keeps the
# frame colours plus black and the strip pixels become black (the stripes are cut off along the frame edge).
MASK_ROWS = 2
DOOR_CELLS = {LEFT_COL0: range(0, 5), RIGHT_COL0: range(4, 9)}


def masked_strip_records(normal_idx, half_idx, col0):
    recs = []
    for r in range(MASK_ROWS):
        for s in range(2):
            cv = [row[:] for row in normal_idx]
            for c in DOOR_CELLS[col0]:
                cx = col0 + c
                y0 = (PATCH_ROW0 + r) * 8
                ys = 88 + 8 * s                  # strip rows: text rows 11 / 12 of the half-closed picture
                cells = [[(normal_idx[y0 + y][cx * 8 + x], half_idx[ys + y][cx * 8 + x]) for x in range(8)] for y in range(8)]
                inside = lambda n: n == 0
                fcols = {n for row in cells for n, h in row if not inside(n)}
                mcols = [h for row in cells for n, h in row if inside(n)]
                allc = sorted(fcols | set(mcols))
                if len(allc) > 2:
                    keep = sorted(fcols)[:2]
                    if len(keep) < 2:
                        keep.append(0)
                    dark = min(keep, key=lambda k: sum(rgb(k)))
                    near = lambda h: dark
                else:
                    near = lambda h: h
                for y in range(8):
                    for x in range(8):
                        n, h = cells[y][x]
                        cv[y0 + y][cx * 8 + x] = near(h) if inside(n) else n
            st = hires_convert(cv)
            recs.append(patch_records(st, col0, rows=[PATCH_ROW0 + r])[0])
    return recs


def gen_office():
    normal = office_state("normal")
    light = office_state("doorlight")
    closed = office_state("door_2")
    half = office_state("door_1")
    open(os.path.join(OUT, "office.bmp"), "wb").write(normal[0])
    open(os.path.join(OUT, "office.scr"), "wb").write(normal[1])
    anim = office_state("animatronics")
    # patches: per side: N(22) L(22) C(22) S(2) A(22)  -> 90 records of 63 bytes
    # A = light on with Bonnie (left) / Chica (right) standing in the doorway or window
    out = bytearray()
    for col0 in (LEFT_COL0, RIGHT_COL0):
        for st in (normal, light, closed):
            out += b"".join(patch_records(st, col0))
        out += b"".join(patch_records(half, col0, rows=[11, 12]))
        out += b"".join(patch_records(anim, col0))
    out += button_records(normal, light, closed)
    open(os.path.join(OUT, "patches.bin"), "wb").write(out)
    nidx = load_indexed(os.path.join(ASSETS, "office", "office_normal.png"))
    hidx = load_indexed(os.path.join(ASSETS, "office", "office_door_1.png"))
    open(os.path.join(OUT, "strip_msk.bin"), "wb").write(
        b"".join(b"".join(masked_strip_records(nidx, hidx, c0)) for c0 in (LEFT_COL0, RIGHT_COL0)))
    for name, fn in (("dark", "dark"), ("dark_freddy", "darkfreddy")):
        b, sc = office_state(name)
        open(os.path.join(OUT, fn + ".bmp"), "wb").write(b)
        open(os.path.join(OUT, fn + ".scr"), "wb").write(sc)
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


def rec_sprite(dot):
    cv = sprite_canvas()
    if dot:
        sp_disc(cv, 3.5, 10, 3, filled=True)
    sp_text(cv, 9, 8, "REC")
    return sprite_from_rows(["".join(r) for r in cv])


def gen_sprites():
    # the only sprite: the camera view's REC indicator (the office buttons are part of the office pictures)
    open(os.path.join(OUT, "sprites.bin"), "wb").write(rec_sprite(True))


def preview_office(normal):
    render_hires(*normal).resize((640, 400), Image.NEAREST).save(os.path.join(OUT, "prev_office.png"))


def gen_lamp(normal):
    """Colour cells (screen RAM bytes) of the ceiling lamp: normal, dimmed and nearly dark variants."""
    maps = [{}, {1: 10, 10: 2, 8: 9}, {1: 2, 10: 9, 2: 9, 8: 0}]    # the outer orange rim darkens with the inner parts
    out = bytearray()
    for m in maps:
        for r in range(5):
            for c in range(17, 23):
                v = normal[1][r * 40 + c]
                out.append((m.get(v >> 4, v >> 4) << 4) | m.get(v & 15, v & 15))
    open(os.path.join(OUT, "lamp.bin"), "wb").write(bytes(out))


# ------------------------------------------------------------------- fan
# The desk fan is redrawn every few frames: dithered blade wedges (3 blades, 4 steps of 30 degrees)
# sweep across the dark part of the grille. Only cells inside the circle change (5 row segments).
FAN_CX, FAN_CY, FAN_R0, FAN_R1 = 172.5, 107.0, 4.5, 14.5
FAN_ROWS = [(20, 3), (19, 5), (19, 5), (19, 5), (20, 3)]      # (first column, cells) for rows 11..15
FAN_ROW0 = 11


def fan_frames(normal):
    import math
    bmp, scr = normal
    frames = []
    for k in range(4):
        phase = k * 30.0
        data = bytearray()
        scrs = bytearray()
        for ri, (c0, n) in enumerate(FAN_ROWS):
            r = FAN_ROW0 + ri
            bm = bytearray()
            sc = bytearray()
            for c in range(c0, c0 + n):
                s0 = scr[r * 40 + c]
                px = []
                for y in range(8):
                    b = bmp[(r * 40 + c) * 8 + y]
                    px.append([(s0 >> 4) if b & (0x80 >> x) else (s0 & 15) for x in range(8)])
                cols = set(v for row in px for v in row)
                other = sorted(cols - {0})
                blade = 11 if not other else (other[0] if len(other) == 1 else None)
                for y in range(8):
                    for x in range(8):
                        ax, ay = c * 8 + x + 0.5, r * 8 + y + 0.5
                        dx, dy = ax - FAN_CX, ay - FAN_CY
                        d = math.hypot(dx, dy)
                        if blade is not None and FAN_R0 < d < FAN_R1 - 1 and (x + y) % 2 == 0:
                            ang = (math.degrees(math.atan2(dy, dx)) - phase) % 120.0
                            if ang < 55:
                                px[y][x] = blade if px[y][x] == 0 else 0
                cols = sorted(set(v for row in px for v in row))
                assert len(cols) <= 2
                bg, fg = (cols[0], cols[1]) if len(cols) == 2 else (cols[0], cols[0])
                sc.append((fg << 4) | bg)
                for y in range(8):
                    v = 0
                    for x in range(8):
                        if fg != bg and px[y][x] == fg:
                            v |= 0x80 >> x
                    bm.append(v)
            data += bm
            scrs += sc
        # per row: bitmap bytes then screen bytes, interleaved by row segment
        rec = bytearray()
        o8 = o1 = 0
        for (c0, n) in FAN_ROWS:
            rec += data[o8:o8 + 8 * n]
            rec += scrs[o1:o1 + n]
            o8 += 8 * n
            o1 += n
        frames.append(bytes(rec))
    return frames


def gen_fan(normal):
    fr = fan_frames(normal)
    assert len(fr[0]) == 189 and all(len(f) == 189 for f in fr)
    open(os.path.join(OUT, "fan_a.bin"), "wb").write(fr[0] + fr[1])     # -> $be40 (Code3 spare area)
    open(os.path.join(OUT, "fan_b.bin"), "wb").write(fr[2] + fr[3])     # -> $0a40


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
    ("A DOOR   S LIGHT  LEFT", 170),
    ("L DOOR   K LIGHT  RIGHT", 177),
    ("SPACE CAMERA  < 1-0 CAMS", 184),
    ("M MUTE PHONE CALL  P PAUSE", 191),
]


HEAD_X = 144        # Freddy's head starts right of this column (the text ends at x=133, the head begins at x=151)
HEAD_SHIFT = 8      # the glitched title copy has everything right of HEAD_X moved this many pixels to the right (a whole cell keeps the 2-colour cells valid)


def title_overlay(idx):
    hires_plate(idx, 8, 168, 4 * 24, 32)
    for text, y in TITLE_KEYS:
        hires_text(idx, 8, y, text, 15, sx=1, sy=1)


# The disclaimer shown while the game loads (hires, black with white / coloured text; every cell keeps one text colour).
# (text, y, scale, colour): centred; a text of None draws a rule.
DISCLAIMER = [
    ("DISCLAIMER", 8, 3, 10),
    (None, 30, 1, 11),
    ("THIS IS A FAN-MADE FUN PROJECT.", 38, 2, 1),
    ("IT IS NOT CONNECTED TO THE", 52, 2, 1),
    ("ORIGINAL GAME IN ANY WAY.", 66, 2, 1),
    ("ALL RIGHTS TO FIVE NIGHTS AT", 80, 2, 1),
    ("FREDDY'S BELONG TO ITS CREATOR,", 94, 2, 1),
    ("SCOTT CAWTHON.", 108, 2, 1),
    (None, 124, 1, 11),
    ("WARNING!", 134, 3, 7),
    ("THIS GAME CAN CONTAIN FLASHING", 156, 2, 7),
    ("LIGHTS AND JUMPSCARES, JUST LIKE", 170, 2, 7),
    ("IN THE ORIGINAL GAME.", 184, 2, 7),
]


def gen_disclaimer():
    idx = [[0] * 320 for _ in range(200)]
    for text, y, sc, col in DISCLAIMER:
        if text is None:
            for yy in range(y, y + 2):
                for xx in range(16, 304):
                    idx[yy][xx] = col
            continue
        w = (len(text) * 4 - 1) * sc
        assert w <= 320, text
        hires_text(idx, (320 - w) // 2, y, text, col, sx=sc, sy=sc)
    write_hires("disclaimer", idx).resize((640, 400), Image.NEAREST).save(os.path.join(OUT, "prev_disclaimer.png"))


def gen_title():
    idx = load_indexed(os.path.join(ASSETS, "lobby.png"))
    shifted = [row[:HEAD_X] + [row[HEAD_X]] * HEAD_SHIFT + row[HEAD_X:320 - HEAD_SHIFT] for row in idx]
    for name, im in (("title", idx), ("title_h", shifted)):
        title_overlay(im)
        b, s = hires_convert(im)
        open(os.path.join(OUT, name + ".bmp"), "wb").write(b)
        open(os.path.join(OUT, name + ".scr"), "wb").write(s)
        render_hires(b, s).resize((640, 400), Image.NEAREST).save(os.path.join(OUT, "prev_" + name + ".png"))


# ------------------------------------------------------------ jumpscares
# who: 0 Freddy, 1 Bonnie, 2 Chica, 3 Foxy  (two frames each: the scare and a lunge)

def write_hires(name, idx):
    b, sc = hires_convert(idx)
    base = os.path.join(OUT, name)
    open(base + ".bmp", "wb").write(b)
    open(base + ".scr", "wb").write(sc)
    return render_hires(b, sc)


def gen_jumpscares():
    prev = []
    for who, d in enumerate(("freddy", "bonnie", "chica", "foxy")):
        for f in (1, 2):
            idx = load_indexed(os.path.join(ASSETS, "jumpscare", d, "%d.png" % f))
            prev.append(write_hires("js_%d_%d" % (who, f - 1), idx))
    sheet = Image.new("RGB", (640, 800))
    for i, im in enumerate(prev):
        sheet.paste(im.resize((160, 100)), ((i % 4) * 160, (i // 4) * 100))
    sheet.save(os.path.join(OUT, "prev_jumpscares.png"))


# ------------------------------------------------------------- phone calls
# One file per night (loaded at $4a40 when the night starts). Format: chunks of
#   n (1..40) + n screen codes  = one subtitle line,   $80+k = silence for k * 0.4 s,   0 = end.
PHONE = {
    1: ["(PRESS M TO MUTE THE CALL)", "-",
        "UH, HELLO? HELLO? OKAY, IT'S ON.",
        "WELCOME TO FREDDY FAZBEAR'S PIZZA!",
        "I'M CALLING TO SHOW YOU THE ROPES.",
        "-",
        "THE ANIMATRONICS GET A BIT ODD",
        "WHEN THE PLACE GOES QUIET AT NIGHT.",
        "THEY WANDER AROUND, SO CHECK THE",
        "CAMERAS, AND USE THE HALL LIGHTS.",
        "IF SOMEONE IS AT YOUR DOOR, SHUT IT.",
        "-",
        "BUT DOORS, LIGHTS AND CAMERAS ALL",
        "USE POWER, SO DON'T WASTE IT.",
        "OKAY, THAT'S IT. GOOD LUCK!"],
    2: ["HELLO, HELLO! NIGHT TWO, NICE WORK.", "-",
        "SEE THE CURTAIN AT PIRATE COVE?",
        "FOXY LIVES BEHIND IT. HE HATES",
        "BEING IGNORED, SO CHECK THE CAMERAS.",
        "ANY CAMERA KEEPS HIM CALM A WHILE.",
        "-",
        "IF THE CURTAIN IS EMPTY, SHUT THE",
        "LEFT DOOR, AND DO IT FAST!",
        "GOOD LUCK. TALK TO YOU LATER."],
    3: ["HELLO AGAIN! THIRD NIGHT ALREADY.", "-",
        "I HEARD ROBOT LAUGHS FROM THE EAST",
        "HALL LAST NIGHT. THAT'S FREDDY.",
        "HE ONLY MOVES WHEN YOU AREN'T",
        "LOOKING, AND NEVER WHEN YOU WATCH.",
        "-",
        "KEEP YOUR RIGHT DOOR SHUT WHEN YOU",
        "LOOK AWAY FROM THE EAST CORNER.",
        "BEST OF LUCK!"],
    4: ["UH, HELLO. HOW ARE YOU HOLDING UP?", "-",
        "IT GETS ROUGH FROM HERE. THEY ARE",
        "FASTER NOW, AND THEY FIND THE",
        "DOORS MUCH SOONER THAN BEFORE.",
        "-",
        "CHECK THE LIGHTS OFTEN AND STAY",
        "SHARP. YOU'RE DOING GREAT!"],
    5: ["HELLO! LAST BIG NIGHT, HANG IN THERE.", "-",
        "WATCH YOUR POWER AND YOUR DOORS.",
        "IF THE LIGHTS EVER GO OUT, LISTEN",
        "FOR A LITTLE TUNE... AND HOPE.",
        "-",
        "GOOD LUCK, YOU'VE GOT THIS."],
}
SCREEN = {"'": 39, "(": 40, ")": 41, "*": 42, ",": 44, "-": 45, ".": 46, "!": 33, "?": 63, ":": 58, " ": 32}


def screen_code(ch):
    if ch in SCREEN:
        return SCREEN[ch]
    if "A" <= ch <= "Z":
        return ord(ch) - 64
    if "0" <= ch <= "9":
        return ord(ch)
    raise ValueError("phone text: unsupported character %r" % ch)


def gen_phone():
    for night, lines in PHONE.items():
        out = bytearray()
        for ln in lines:
            if ln == "-":
                out.append(0x80 + 2)             # a short pause
                continue
            assert len(ln) <= 40, ln
            out.append(len(ln))
            out += bytes(screen_code(c) for c in ln)
        out.append(0)
        assert len(out) <= 448, (night, len(out))     # $4a40-$4bff
        open(os.path.join(OUT, "phone_%d.bin" % night), "wb").write(bytes(out))


def gen_news():
    write_hires("news", load_indexed(os.path.join(ASSETS, "newspaper.png")))


if __name__ == "__main__":
    gen_frames_asm()
    gen_jumpscares()
    gen_news()
    gen_phone()
    gen_title()
    gen_disclaimer()
    normal = gen_office()
    gen_lamp(normal)
    gen_fan(normal)
    gen_sprites()
    files = gen_cams()
    preview_office(normal)
    print("cam frames:", len(files))
