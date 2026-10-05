#!/usr/bin/env python3
"""Fails the build if anything that lives in RAM at the same time overlaps (see tools/layout.py for what is
persistent and what is transient). tools/memmap.py prints the same regions as a map with the free gaps."""
import sys
sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__)))
import layout

persistent, transient = layout.collect(sys.argv[1] if len(sys.argv) > 1 else None)


def overlap(x, y):
    return x[0] < y[1] and y[0] < x[1]      # (start, end) pairs


bad = 0
NOISE_AREAS = ("noise", "dark bar", "white bar", "grey bar")
for i, x in enumerate(persistent):
    for y in persistent[i + 1:]:
        if overlap(x[1:], y[1:]):
            print("OVERLAP: %s $%04x-$%04x  <->  %s $%04x-$%04x" % (x[0], x[1], x[2] - 1, y[0], y[1], y[2] - 1)); bad += 1
for b, n, a, e in transient:
    if 0xd000 <= a < 0xe000: continue      # colour RAM
    for y in persistent:
        if b.startswith("bundle 1") and y[0].startswith(NOISE_AREAS): continue    # the disclaimer sits where the noise screens / bitmap are built later (InitNoise)
        if overlap((a, e), y[1:]):
            print("OVERLAP: %s $%04x-$%04x  <->  %s $%04x-$%04x" % (n, a, e - 1, y[0], y[1], y[2] - 1)); bad += 1
if bad: sys.exit("layout check failed")
print("layout check ok (%d persistent regions)" % len(persistent))
