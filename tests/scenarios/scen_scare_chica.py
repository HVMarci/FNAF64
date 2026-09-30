# Chica is in the office; raise and lower the monitor
NIGHT = 1
POS = (0, 0, 12, 0)
STEPS = [(100, "SPACE", ""), (101, "", ""), (250, "SPACE", ""), (251, "", "")]
STEPS += [(251 + d, "", "c%03d" % d) for d in (40, 80, 120, 160, 200, 300)]
