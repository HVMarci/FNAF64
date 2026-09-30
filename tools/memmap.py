#!/usr/bin/env python3
"""Prints the C64 memory map of the last build: every region, the gaps between them and the headroom
of each code segment.   tools/memmap.py [--all]     (--all also lists transient bundles)

Persistent regions come from tools/layout.py (shared with check_layout.py), the code from build/code*.prg and
the segment limits from the .segmentdef lines in src/main.asm."""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import layout

ROOT = layout.ROOT
regions, transient = layout.collect()          # (name, start, end)  end exclusive

# transient bundles (camera / title / jumpscare / newspaper / phone text) reuse the same buffers: show them merged,
# and keep them out of the "free" count. Colour RAM loads ($d800) are skipped like in check_layout.
spans = sorted((a, e) for b, n, a, e in transient if not 0xd000 <= a < 0xe000)
merged = []
for a, e in spans:
    if merged and a <= merged[-1][1]: merged[-1][1] = max(merged[-1][1], e)
    else: merged.append([a, e])
trans_regions = [("(transient: camera / title / jumpscare / phone bundles)", a, e) for a, e in merged]

segs = {}
for m in re.finditer(r"\.segmentdef\s+(\w+)\s*\[start=\$([0-9a-f]+),\s*max=\$([0-9a-f]+)", open(os.path.join(ROOT, "src", "main.asm")).read()):
    segs[m.group(1)] = (int(m.group(2), 16), int(m.group(3), 16))

print("code segments (size / limit, headroom = bytes it can still grow before its limit or the next region)")
tot = 0
for i, n in enumerate(sorted(segs), 1):
    a, e = layout.prg(os.path.join(layout.B, "code%d.prg" % i))
    lo, hi = segs[n]
    nxt = min([hi + 1] + [r[1] for r in regions + trans_regions if r[1] >= e and not r[0].startswith("code")])
    room = nxt - e
    tot += room
    print("  %-6s $%04x-$%04x  %5d bytes   limit $%04x   headroom %5d" % (n, a, e - 1, e - a, hi, room))
print("  total headroom in code segments: %d bytes\n" % tot)

rows = sorted((r for r in regions + trans_regions if r[2] > 0x0200), key=lambda r: r[1])
print("map ($0200-$ffff; I/O window $d000-$dfff is shown as used: colour RAM / screens hide under it)")
cur = 0x0200
free = 0
for name, a, e in rows:
    if a > cur:
        print("  $%04x-$%04x  %5d  .. free .." % (cur, a - 1, a - cur))
        free += a - cur
    if e > cur:
        print("  $%04x-$%04x  %5d  %s" % (max(a, cur), e - 1, e - max(a, cur), name))
    cur = max(cur, e)
if cur < 0x10000:
    print("  $%04x-$ffff  %5d  .. free .." % (cur, 0x10000 - cur)); free += 0x10000 - cur
print("\nfree RAM in total (every gap above, counting only what no bundle ever uses): %d bytes" % free)
if "--all" in sys.argv:
    print("\ntransient bundles (share the camera buffer / colour RAM)")
    for b, n, a, e in transient:
        print("  $%04x-$%04x  %-24s %s" % (a, e - 1, n, b))
