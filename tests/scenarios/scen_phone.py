# Night 1 phone call: ring, subtitles in the office and in the camera, then muting with M
NIGHT = 1
PHONE = 1
STEPS = [(60, "", "wait"), (170, "", "ring1"), (250, "", "ring2")]
STEPS += [(400 + 100 * i, "", "t%02d" % i) for i in range(8)]
STEPS += [(1250, "SPACE", ""), (1251, "", ""), (1400, "", "cam_sub"), (1500, "", "cam_sub2")]
STEPS += [(1600, "M", ""), (1601, "", ""), (1650, "", "muted")]
