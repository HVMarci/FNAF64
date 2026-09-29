#!/usr/bin/env python3
"""Fails the build if anything that lives in RAM at the same time overlaps.

Persistent = code, office assets, patches, sprites and the fixed RAM areas the
program builds at run time. The title screen and camera bundles share the camera
buffer on purpose but must not touch anything persistent."""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
B = os.path.join(ROOT, "build")

persistent = [
    ("zero page vars", 0x0010, 0x0070),
    ("stack + Sparkle resident + loader buffer", 0x0100, 0x0400),
    ("RAM tables + sound vars", 0x0c00, 0x0d00),
    ("noise screen 0", 0xc000, 0xc400),
    ("noise screen 1", 0xc400, 0xc800),
    ("dark bar screen", 0xcc00, 0xd000),
    ("noise screen 2", 0xd000, 0xd400),
    ("noise screen 3", 0xd400, 0xd800),
    ("white bar screen", 0xd800, 0xdc00),
    ("grey bar screen", 0xdc00, 0xe000),
    ("noise bitmap (bank 3)", 0xe000, 0x10000),
]
def prg(path):
    d = open(path, "rb").read()
    a = d[0] | d[1] << 8
    return a, a + len(d) - 2
for c in ("code1.prg", "code2.prg", "code3.prg"):
    a, e = prg(os.path.join(B, c))
    persistent.append((c, a, e))

transient = []          # (bundle, name, start, end)
bundle = "?"
sls = open(os.path.join(B, [f for f in os.listdir(B) if f.endswith(".sls")][0])).read().splitlines()
for line in sls:
    m = re.match(r"<< (.*) >>", line)
    if m: bundle = m.group(1)
    m = re.match(r'File:\t"([^"]+)"\t([0-9a-f]+)', line)
    if m:
        n = os.path.getsize(os.path.join(B, m.group(1)))
        a = int(m.group(2), 16)
        (transient if ("camera" in bundle or "title" in bundle) else persistent).append((m.group(1), a, a + n))

def overlap(x, y):
    return x[1] < y[2] and y[1] < x[2]
bad = 0
for i, x in enumerate(persistent):
    for y in persistent[i + 1:]:
        if overlap(x, y):
            print("OVERLAP: %s $%04x-$%04x  <->  %s $%04x-$%04x" % (x[0], x[1], x[2] - 1, y[0], y[1], y[2] - 1)); bad += 1
for t in transient:
    if t[1] >= 0xd000 and t[1] < 0xe000: continue      # colour RAM
    for y in persistent:
        if overlap(t, y):
            print("OVERLAP: %s $%04x-$%04x  <->  %s $%04x-$%04x" % (t[0], t[1], t[2] - 1, y[0], y[1], y[2] - 1)); bad += 1
if bad: sys.exit("layout check failed")
print("layout check ok (%d persistent regions)" % len(persistent))
