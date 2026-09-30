# Foxy is sprinting (stage 4); watching camera 2A speeds him up, the door is open -> jumpscare
NIGHT = 1
POS = (0, 0, 0, 3)
STEPS = [(100, "SPACE", ""), (101, "", ""), (300, "2", ""), (301, "", ""), (480, "", "cam2a")]
STEPS += [(480 + d, "", "f%03d" % d) for d in (60, 120, 160, 200, 240, 300, 400)]
