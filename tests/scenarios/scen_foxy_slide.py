# Foxy's jumpscare frame by frame: the sprite runs in over the office (5 jumps), holds, then 2.png, then static / game over
NIGHT = 1
POS = (0, 0, 0, 3)
STEPS = [(100, "SPACE", ""), (101, "", ""), (300, "3", ""), (301, "", ""), (480, "", "")]
STEPS += [(480 + d, "", "g%03d" % d) for d in range(118, 190, 2)]
