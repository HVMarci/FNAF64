#!/usr/bin/env python3
"""Prints the game variables ($0f00..) from every memory dump in build/vice.log (DUMP = "0f00 0f2f")."""
import re, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
log = open(os.path.join(ROOT, "build", "vice.log"), errors="ignore").read()
blocks, cur = [], {}
for m in re.finditer(r"^>C:([0-9a-f]{4})\s+((?:[0-9a-f]{2}\s+){1,16})", log, re.M):
    a = int(m.group(1), 16)
    if a == 0xf00 and cur: blocks.append(cur); cur = {}
    for i, b in enumerate(m.group(2).split()): cur[a + i] = int(b, 16)
if cur: blocks.append(cur)
for i, b in enumerate(blocks):
    if b.get(0xf07) not in (50, 60): continue
    g = lambda o: b.get(0xf00 + o, 0)
    print("night", g(0), "hr", g(3), "hds", g(4) | g(5) << 8, "pw", g(8), "use", g(11), "ai", [g(12 + k) for k in range(4)],
          "pos", [g(20 + k) for k in range(4)], "fxrun", g(24), "frz", g(25), "hits", g(26), "pkill", g(29),
          "ps", g(37), "ptm", g(38), "hud", g(39), "fwant", g(40))
