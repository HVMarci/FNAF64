# Foxy at AI 20 with the left door closed early: he should run, bang on the door, steal power and go back
NIGHT = 1
AI = (0, 0, 0, 20)
DUMP = "0f00 0f2f"
STEPS = [(1400, "A", ""), (1401, "", "")]
STEPS += [(f, "", "s%04d" % f) for f in range(400, 5000, 250)]
