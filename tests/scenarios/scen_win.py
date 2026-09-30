# Night 1 with short hours: survive to 6 AM, then the title shows night 2
NIGHT = 1
DEFINES = ["FASTHOUR"]
STEPS = [(1300, "", "h2"), (3590, "", "h5")]
STEPS += [(3600 + d, "", "w%04d" % d) for d in (20, 60, 100, 160, 260, 400, 520, 650, 800)]
