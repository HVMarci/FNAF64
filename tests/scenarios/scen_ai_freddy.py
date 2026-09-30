# Freddy (AI 20) walks to the east hall corner while the monitor is down, enters when it is up on another camera
NIGHT = 1
AI = (20, 0, 0, 0)
POS = (0, 1, 1, 0)
DUMP = "0f00 0f2f"
STEPS = [(f, "", "a%04d" % f) for f in range(200, 1500, 100)]
STEPS += [(1500, "SPACE", ""), (1501, "", "")]
STEPS += [(f, "", "b%04d" % f) for f in range(1600, 2400, 100)]
STEPS += [(2400, "SPACE", ""), (2401, "", "")]
STEPS += [(f, "", "c%04d" % f) for f in range(2500, 4500, 250)]
