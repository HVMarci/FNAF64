#!/usr/bin/env python3
"""wavstat.py file.wav [window_s] - prints RMS and a rough dominant frequency for each window."""
import sys, wave, struct
w = wave.open(sys.argv[1]); win = float(sys.argv[2]) if len(sys.argv) > 2 else 0.5
rate, n, ch = w.getframerate(), w.getnframes(), w.getnchannels()
data = struct.unpack("<%dh" % (n * ch), w.readframes(n))[::ch]
step = int(rate * win)
for i in range(0, len(data) - step, step):
    seg = data[i:i + step]
    m = sum(seg) / len(seg)
    rms = (sum((v - m) ** 2 for v in seg) / len(seg)) ** 0.5
    zc = sum(1 for a, b in zip(seg, seg[1:]) if (a - m) * (b - m) < 0)
    print("%6.1fs rms %7.1f  ~%5d Hz" % (i / rate, rms, zc / 2 / win))
