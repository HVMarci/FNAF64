# Foxy sprinting down the west hall while camera 2A is opened: the first picture of his run loads (never 1.png / 2.png), the original
# animation plays (7 steps from RAM), then he arrives (the door is open here: jumpscare)
NIGHT = 1
POS = (0, 0, 0, 3)
STEPS = [(100, "SPACE", ""), (101, "", ""), (300, "3", ""), (301, "", "")]
STEPS += [(f, "", "r%04d" % f) for f in range(470, 540, 4)]
