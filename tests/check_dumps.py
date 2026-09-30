#!/usr/bin/env python3
"""tests/check_dumps.py SCENARIO - assertions on the game-variable dumps (DUMP = "0f00 0f2f") that the last
run of tests/scenarios/scen_SCENARIO.py left in build/vice.log. Exits 0 for scenarios without a check."""
import os, re, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
name = sys.argv[1]


def blocks():
    log = open(os.path.join(ROOT, "build", "vice.log"), errors="ignore").read()
    out, cur = [], {}
    for m in re.finditer(r"^>C:([0-9a-f]{4})\s+((?:[0-9a-f]{2}\s+){1,16})", log, re.M):
        a = int(m.group(1), 16)
        if a == 0xf00 and cur: out.append(cur); cur = {}
        for i, b in enumerate(m.group(2).split()): cur[a + i] = int(b, 16)
    if cur: out.append(cur)
    return [b for b in out if b.get(0xf07) in (50, 60)]          # g_fps: sanity filter


def g(b, o): return b.get(0xf00 + o, 0)
def hds(b): return g(b, 4) | g(b, 5) << 8
def fail(msg): print("CHECK FAILED (%s): %s" % (name, msg)); sys.exit(1)


if name == "pause":
    # a, p1, p2, r1, r2, cam, cp1, cp2, cr1, cr2
    b = blocks()
    if len(b) != 10: fail("expected 10 dumps, got %d" % len(b))
    a, p1, p2, r1, r2, cam, cp1, cp2, cr1, cr2 = b
    if not (hds(a) > hds(p1) == hds(p2) > hds(r1) > hds(r2)): fail("office: clock not frozen / not resumed %s" % [hds(x) for x in b[:5]])
    if not (hds(cam) > hds(cp1) == hds(cp2) > hds(cr1) > hds(cr2)): fail("camera: clock not frozen / not resumed %s" % [hds(x) for x in b[5:]])
    if g(p1, 52) != 1 or g(r1, 52) != 0: fail("g_pause flag")
elif name in ("night7", "night7_play"):
    b = [x for x in blocks() if g(x, 0) == 7 and g(x, 12) + g(x, 13) + g(x, 14) + g(x, 15) > 0]
    if not b: fail("no night 7 dump with AI levels")
    if any([g(x, 12 + k) for k in range(4)] != [20, 20, 20, 20] and min(g(x, 12 + k) for k in range(4)) < 20 for x in b):
        fail("AI levels below 20: %s" % [[g(x, 12 + k) for k in range(4)] for x in b])
    if name == "night7_play" and not any(any(g(x, 20 + k) for k in range(4)) for x in b): fail("nobody ever moved")
else:
    print("no check for", name)
    sys.exit(0)
print("check ok:", name)
