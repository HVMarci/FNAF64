#!/usr/bin/env python3
"""Writes build/fnaf64.sls (Sparkle loader script) for the current assets."""
import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
from gen_assets import CAMS, frame_counts

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
for c in ("code1.prg", "code2.prg", "code3.prg", "code4.prg"):
    L.append("File:\t\"%s\"" % c)
L.append("")
L.append("<< bundle 1: title screen >>")
L.append("DirIndex:\t0f")
L.append("File:\t\"gen/title.bmp\"\t6000")
L.append("File:\t\"gen/title.scr\"\t4000")
L.append("")
L.append("<< bundle 2: office assets >>")
L.append("DirIndex:\t0e")
L.append("File:\t\"gen/office.bmp\"\t2000")
L.append("File:\t\"gen/office.scr\"\t0400")
L.append("File:\t\"gen/patches.bin\"\t8000")
L.append("File:\t\"gen/fan_a.bin\"\tbe40")
L.append("File:\t\"gen/fan_b.bin\"\t0a40")
for a in ("0800", "4800", "c800"):
    L.append("File:\t\"gen/sprites.bin\"\t%s" % a)
L.append("")
gid = 0
for i in range(len(CAMS)):
    for f in range(frame_counts()[i]):
        L.append("<< camera %d (%s) frame %d >>" % (i, CAMS[i][0], f))
        L.append("DirIndex:\t%02x" % (0x10 + gid))
        L.append("File:\t\"gen/cam_%02d_%d.bmp\"\t6000" % (i, f))
        L.append("File:\t\"gen/cam_%02d_%d.scr\"\t4000" % (i, f))
        L.append("File:\t\"gen/cam_%02d_%d.col\"\td800" % (i, f))
        L.append("")
        gid += 1
for who in range(4):
    for f in range(2):
        L.append("<< jumpscare %d frame %d >>" % (who, f))
        L.append("DirIndex:\t%02x" % (0x40 + who * 2 + f))
        L.append("File:\t\"gen/js_%d_%d.bmp\"\t6000" % (who, f))
        L.append("File:\t\"gen/js_%d_%d.scr\"\t4000" % (who, f))
        L.append("")
for n, (fn, di) in enumerate((("dark", 0x48), ("darkfreddy", 0x49))):
    L.append("<< %s office >>" % fn)
    L.append("DirIndex:\t%02x" % di)
    L.append("File:\t\"gen/%s.bmp\"\t2000" % fn)
    L.append("File:\t\"gen/%s.scr\"\t0400" % fn)
    L.append("")
for n in range(1, 6):
    L.append("<< phone call night %d >>" % n)
    L.append("DirIndex:\t%02x" % (0x4f + n))
    L.append("File:\t\"gen/phone_%d.bin\"\t4a40" % n)
    L.append("")
L.append("<< newspaper >>")
L.append("DirIndex:\t4a")
L.append("File:\t\"gen/news.bmp\"\t6000")
L.append("File:\t\"gen/news.scr\"\t4000")
L.append("")
L.append("<< save plugin and save file >>")
L.append("PlgIndex:\t7e")
L.append("Plugin:\tsaver")
L.append("")
L.append("PlgIndex:\t7f")
if os.environ.get("SAVE_NIGHT"):        # disk with a ready-made save (./build.sh unlocked): same record the game writes
    n = int(os.environ["SAVE_NIGHT"])
    open(os.path.join(OUT, "gen", "save.bin"), "wb").write(bytes([0xa5, n, n ^ 0xff]) + bytes(253))
    L.append("HSFile:\t\"gen/save.bin\"\tbd00")
else:
    L.append("HSFile:\tblank\tbd00\t0000\t0100")
L.append("")
open(os.path.join(OUT, name + ".sls"), "w").write("\n".join(L) + "\n")
