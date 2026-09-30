# Bonnie gets in; raising and lowering the monitor is fatal
NIGHT = 1
AI = (0, 20, 0, 0)
DUMP = "0010 0030"
STEPS = [(2400, "", "pre"), (2401, "SPACE", ""), (2402, "", ""), (2600, "", "cam"), (2601, "SPACE", ""), (2602, "", "")]
STEPS += [(2602 + d, "", "sc%03d" % d) for d in (10, 20, 30, 40, 55, 70, 90, 100, 110, 150, 200, 260, 330, 420, 470, 520, 560)]
