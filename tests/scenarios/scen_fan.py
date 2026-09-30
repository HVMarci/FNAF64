# Fan animation (consecutive frames) and the flashing ceiling lamp
NIGHT = 1
STEPS = [(300 + 3 * i, "", "fan%d" % i) for i in range(4)]
STEPS += [(330 + 2 * i, "", "lamp%02d" % i) for i in range(16)]
