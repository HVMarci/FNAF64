# Beating night 6 unlocks night 7: the title afterwards offers "1-7 CHOOSE NIGHT" (before: "1-6", see the first shot).
# AI held at 0 so that nobody interferes (the 2-4 AM bumps give at most level 1-2).
NIGHT = 6
AI = (0, 0, 0, 0)
DEFINES = ["FASTHOUR"]
STEPS = [(1300, "", "h2"), (3590, "", "h5")] + [(3600 + d, "", "w%04d" % d) for d in (100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1300)]
