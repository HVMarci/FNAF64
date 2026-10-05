# Foxy sprinting down the west hall while camera 2A is watched: the hall shows him running at the camera (third picture of 2A)
NIGHT = 1
POS = (0, 0, 0, 3)
STEPS = [(100, "SPACE", ""), (101, "", ""), (300, "3", ""), (301, "", "")]
STEPS += [(f, "", "r%04d" % f) for f in range(200, 680, 40)]
