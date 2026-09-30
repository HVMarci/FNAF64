#!/usr/bin/env python3
"""tests/compare_shots.py BASE_DIR NEW_DIR [scenario ...]
Pixel-compares the screenshots of two tests/run_all.sh runs (each a directory with one sub-directory per
scenario) and prints, per scenario, how many snapshots are identical and how large the differences are.
Snapshots with random content (static, glitches) can differ slightly between runs; look at the percentage."""
import os, sys
from PIL import Image, ImageChops

base, new = sys.argv[1], sys.argv[2]
names = sys.argv[3:] or sorted(d for d in os.listdir(new) if os.path.isdir(os.path.join(new, d)))
worst = 0
for n in names:
    bd, nd = os.path.join(base, n), os.path.join(new, n)
    if not os.path.isdir(bd):
        print("%-14s no baseline" % n); continue
    same = diff = 0
    lines = []
    for f in sorted(os.listdir(nd)):
        if not f.endswith(".png"): continue
        if not os.path.exists(os.path.join(bd, f)):
            lines.append("   %s: missing in baseline" % f); continue
        a = Image.open(os.path.join(bd, f)).convert("RGB"); b = Image.open(os.path.join(nd, f)).convert("RGB")
        if a.size != b.size:
            lines.append("   %s: size %s vs %s" % (f, a.size, b.size)); diff += 1; continue
        d = ImageChops.difference(a, b).convert("L").point(lambda v: 255 if v else 0)
        pct = 100.0 * sum(1 for v in d.getdata() if v) / (a.size[0] * a.size[1])
        if pct == 0: same += 1
        else:
            diff += 1; worst = max(worst, pct); lines.append("   %s: %.2f%% of pixels differ" % (f, pct))
    miss = [f for f in os.listdir(bd) if f.endswith(".png") and not os.path.exists(os.path.join(nd, f))]
    print("%-14s %3d identical, %3d different%s" % (n, same, diff, (", %d missing" % len(miss)) if miss else ""))
    for l in lines: print(l)
print("largest difference: %.2f%%" % worst)
