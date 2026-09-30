#!/usr/bin/env python3
"""tests/fuzz.py SEED [frames] - random key presses, then verifies office buffer consistency."""
import random, subprocess, sys, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
seed = int(sys.argv[1]); frames = int(sys.argv[2]) if len(sys.argv) > 2 else 3000
random.seed(seed)
keys = ["A", "S", "K", "L", "A", "S", "K", "L", "SPACE", "1", "2", "4", "RIGHT", "LEFT", "A S", "K L", "S K"]
steps = []
f = 30
while f < frames and len(steps) < 60:   # the script must fit in the spare RAM after the code
    k = random.choice(keys)
    hold = random.choice([1, 1, 2, 3, 8, 20, 40])
    steps.append((f, k, "")); steps.append((f + hold, "", ""))
    f += hold + random.choice([1, 2, 5, 10, 25, 60])
steps.append((f + 500, "", "final"))
path = os.path.join(ROOT, "build", "fuzz_%d.py" % seed)
open(path, "w").write("STEPS = %r\nDUMP='0017 0040'\nSAVES={'final':[('%s/build/mem_bmp.bin',0x2000,0x3f3f),('%s/build/mem_scr.bin',0x0400,0x07e7)]}\n" % (steps, ROOT, ROOT))
subprocess.check_call([sys.executable, os.path.join(ROOT, "tools", "runtest.py"), path, os.path.join(ROOT, "build", "shots", "fuzz%d" % seed)], stdout=subprocess.DEVNULL)
sys.exit(subprocess.call([sys.executable, os.path.join(ROOT, "tests", "check_consist.py")]))
