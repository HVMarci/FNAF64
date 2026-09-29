#!/usr/bin/env python3
"""Writes build/fnaf64.sls (Sparkle loader script) for the current assets."""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from gen_assets import CAMS

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "build")
name = sys.argv[1] if len(sys.argv) > 1 else "fnaf64"
L = []
L.append("Path:\t\"%s.d64\"" % name)
L.append("Header:\tfnaf64")
L.append("ID:\tfnaf1")
L.append("Name:\tfive nights")
L.append("Start:\t1000")
L.append("Tracks:\t40")
L.append("ProdID:\tf4af64")
for k in ("IL0","IL1","IL2","IL3"):
    if os.environ.get(k): L.append("%s:\t%s" % (k, os.environ[k]))
L.append("")
L.append("<< bundle 0: code >>")
for c in ("code1.prg", "code2.prg", "code3.prg"):
    L.append("File:\t\"%s\"" % c)
L.append("")
L.append("<< bundle 1: title screen >>")
L.append("File:\t\"gen/title.bmp\"\t6000")
L.append("File:\t\"gen/title.scr\"\t4000")
L.append("")
L.append("<< bundle 2: office assets >>")
L.append("File:\t\"gen/office.bmp\"\t2000")
L.append("File:\t\"gen/office.scr\"\t0400")
L.append("File:\t\"gen/patches.bin\"\t8000")
for a in ("0800", "4800", "c800"):
    L.append("File:\t\"gen/sprites.bin\"\t%s" % a)
L.append("")
for i in range(len(CAMS)):
    L.append("<< camera %d (%s) >>" % (i, CAMS[i][0]))
    L.append("DirIndex:\t%02x" % (0x10 + i))
    L.append("File:\t\"gen/cam_%02d_0.bmp\"\t6000" % i)
    L.append("File:\t\"gen/cam_%02d_0.scr\"\t4000" % i)
    L.append("File:\t\"gen/cam_%02d_0.col\"\td800" % i)
    L.append("")
open(os.path.join(OUT, name + ".sls"), "w").write("\n".join(L) + "\n")
