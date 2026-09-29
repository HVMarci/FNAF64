#!/usr/bin/env python3
"""Scripted emulator test.

usage: runtest.py scenario.py [outdir]

scenario.py defines  STEPS = [(frame, keys, 'snapname'), ...]
keys is a string of key names held from that frame on:
  A S K L (doors/lights)  SPACE  1-7  RIGHT LEFT  JL JR JF JU JD
A snapshot named 'snapname' (or '' for none) is taken at that frame.
"""
import os, re, subprocess, sys, shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KA = {"A": 0x01, "S": 0x02, "K": 0x04, "L": 0x08, "SPACE": 0x10, "LEFT": 0x20, "RIGHT": 0x40}
KB = {str(i): 1 << (i - 1) for i in range(1, 8)}
KC = {"JL": 1, "JR": 2, "JF": 4, "JU": 8, "JD": 16}


def keys_to_bytes(s):
    a = b = c = 0
    for k in s.split():
        if k in KA: a |= KA[k]
        elif k in KB: b |= KB[k]
        elif k in KC: c |= KC[k]
        else: raise SystemExit("bad key " + k)
    return a, b, c


def main():
    scen = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "build", "shots")
    os.makedirs(out, exist_ok=True)
    ns = {}
    exec(open(scen).read(), ns)
    steps = ns["STEPS"]
    extra = ns.get("EXTRA_CYCLES", 0)
    snaps = []
    lines = ["test_script:"]
    for frame, keys, name in steps:
        a, b, c = keys_to_bytes(keys)
        sid = 0
        if name:
            snaps.append(name)
            sid = len(snaps)
        lines.append("  .word %d\n  .byte %d,%d,%d,%d" % (frame, a, b, c, sid))
    lines.append("  .word $ffff\n  .byte 0,0,0,0")
    open(os.path.join(ROOT, "build", "test_script.asm"), "w").write("\n".join(lines) + "\n")
    env = dict(os.environ)
    if ns.get("TITLE"): env["TITLE"] = "1"
    else: env.pop("TITLE", None)
    subprocess.check_call([os.path.join(ROOT, "build.sh"), "test"], stdout=subprocess.DEVNULL, env=env)
    sym = open(os.path.join(ROOT, "build", "main.sym")).read()
    m = re.search(r"\.label snapstubs=\$([0-9a-f]+)", sym)
    base = int(m.group(1), 16)
    mon = []
    cp = 0
    for i, name in enumerate(snaps):
        cp += 1
        mon.append("break %04x" % (base + i))
        mon.append('command %d "screenshot \\"%s/%s.png\\" 2"' % (cp, out, name))
        for (path, a, b) in ns.get("SAVES", {}).get(name, []):
            cp += 1
            mon.append("break %04x" % (base + i))
            mon.append('command %d "save \\"%s\\" 0 %04x %04x"' % (cp, path, a, b))
        if ns.get("DUMP"):
            cp += 1
            mon.append("break %04x" % (base + i))
            mon.append('command %d "m %s"' % (cp, ns["DUMP"]))
    monf = os.path.join(ROOT, "build", "mon.txt")
    open(monf, "w").write("\n".join(mon) + "\n")
    lastframe = max(f for f, k, n in steps)
    for f in os.listdir(out):
        if f.endswith(".png"): os.remove(os.path.join(out, f))
    cycles = 90_000_000 + lastframe * 19656 + extra
    cmd = ("yes x | timeout 600 %s %s -console -nativemonitor -warp -drive8truedrive +virtualdev8 "
           "-moncommands %s -limitcycles %d +sound -autostart %s > %s 2>&1" %
           (os.environ.get("EMU", "x64sc"), ("-ntsc" if os.environ.get("NTSC") else ""), monf, cycles, os.path.join(ROOT, "build", "fnaf64_test.d64"), os.path.join(ROOT, "build", "vice.log")))
    subprocess.call(cmd, shell=True)
    got = sorted(os.listdir(out))
    print("snapshots:", got)
    missing = [n for n in snaps if n + ".png" not in got]
    if missing: print("MISSING:", missing)


main()
