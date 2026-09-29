#!/usr/bin/env python3
"""After tests/scenarios/scen_doorlight.py: for every mid-animation memory dump, verify the left door
cells row by row (closed above the edge, light-dependent 'open' rows below it)."""
import re, sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import gen_assets as g
log = open(os.path.join(ROOT, "build", "vice.log")).read()
states, cur = [], {}
for m in re.finditer(r"^>C:([0-9a-f]{4})\s+((?:[0-9a-f]{2}\s+){1,16})", log, re.M):
    a = int(m.group(1), 16)
    if a == 0x17 and cur: states.append(cur); cur = {}
    for i, b in enumerate(m.group(2).split()): cur[a + i] = int(b, 16)
if cur: states.append(cur)
names = ["dl_lit_closing", "dl_unlit_closing", "dl_lit2_closing", "dl_closed_lit", "dl_lit_opening", "dl_unlit_opening", "dl_lit2_opening", "dl_end"]
normal, light, closed = g.office_state("normal"), g.office_state("dorelight"), g.office_state("door_2")
worst = 0
for n, st in zip(names, states):
    p = os.path.join(ROOT, "build", "mem_%s.bin" % n)
    if not os.path.exists(p): continue
    bmp = open(p, "rb").read()[2:]
    kk, lw = st[0x34], st[0x36]
    bad = []
    for pr in range(22):
        if pr <= kk - 3: exp = closed
        elif pr in (kk - 2, kk - 1): continue
        else: exp = light if lw else normal
        r = pr + 3
        for c in range(2, 7):
            if bmp[(r * 40 + c) * 8:(r * 40 + c) * 8 + 8] != exp[0][(r * 40 + c) * 8:(r * 40 + c) * 8 + 8]:
                bad.append(pr); break
    print(n, "ddrawn", kk, "light", lw, "wrong rows", bad)
    worst = max(worst, len(bad))
sys.exit(1 if worst > 1 else 0)     # a snapshot may catch the main loop mid-copy of one row
