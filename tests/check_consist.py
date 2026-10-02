#!/usr/bin/env python3
"""After tests/scenarios/scen_consist.py: verify the office bitmap in C64 memory equals what the
door/light state says it should be (uses the memory dumps and ZP state dump from the run)."""
import os, re, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import gen_assets as g
log = open(os.path.join(ROOT, "build", "vice.log")).read()
m = re.search(r">C:0017\s+((?:[0-9a-f]{2}\s+)+)", log)
rows = re.findall(r"^>C:([0-9a-f]{4})\s+((?:[0-9a-f]{2}\s+){1,16})", log, re.M)
zp = {}
for a, bs in rows:
    for i, b in enumerate(bs.split()):
        zp[int(a, 16) + i] = int(b, 16)
dstate = [zp[0x30], zp[0x31]]
lwant = [zp[0x36], zp[0x37]]
print("door states", dstate, "light", lwant, "mode", zp[0x17])
bmp = open(os.path.join(ROOT, "build", "mem_bmp.bin"), "rb").read()[2:]
scr = open(os.path.join(ROOT, "build", "mem_scr.bin"), "rb").read()[2:]
normal, light, closed = g.office_state("normal"), g.office_state("doorlight"), g.office_state("door_2")
anim = g.office_state("animatronics")
lit = {0: normal, 1: light, 4: anim}
eb, es = bytearray(normal[0]), bytearray(normal[1])
for side, col0 in enumerate((2, 29)):
    door = closed if dstate[side] == 2 else lit[lwant[side]]
    win = lit[lwant[side]]
    # door cells: left cols 2-6, right cols 33-37; window cells: left 9-10, right 29-30
    cells = [(c, door) for c in ((2, 3, 4, 5, 6) if side == 0 else (33, 34, 35, 36, 37))] + \
            [(c, win) for c in ((9, 10) if side == 0 else (29, 30))]
    for r in range(3, 25):
        for cx, src in cells:
            eb[(r * 40 + cx) * 8:(r * 40 + cx) * 8 + 8] = src[0][(r * 40 + cx) * 8:(r * 40 + cx) * 8 + 8]
            es[r * 40 + cx] = src[1][r * 40 + cx]
lamp = {r * 40 + c for r in range(5) for c in range(17, 23)}      # lamp flicker cells vary
hud = set(range(80)) | {r * 40 + c for r in range(11, 16) for c in range(19, 24)}      # + the animated fan                                                    # rows 0-1: power / clock text
ok = all(bytes(bmp[i * 8:i * 8 + 8]) == bytes(eb[i * 8:i * 8 + 8]) for i in range(1000) if i not in hud) and \
     all(scr[i] == es[i] for i in range(1000) if i not in lamp and i not in hud)
print("office buffer consistent:", ok)
if not ok:
    badc = [(i // 40, i % 40) for i in range(1000) if i not in hud and (bytes(bmp[i * 8:i * 8 + 8]) != bytes(eb[i * 8:i * 8 + 8]) or (i not in lamp and scr[i] != es[i]))]
    print("differing cells (row, col):", badc[:40], len(badc))
sys.exit(0 if ok else 1)
