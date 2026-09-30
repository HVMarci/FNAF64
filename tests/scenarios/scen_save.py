# Saving to disk. Run twice on the same disk (tests/check_save.sh): the first run starts on a blank disk (night 1),
# beats night 1 and lets the game write the save; the second run (NOBUILD=1) boots the same disk and must offer night 2.
TITLE = True
NIGHT = 1
DEFINES = ["FASTHOUR", "SAVETEST"]
DUMP = "0f00 0f01"
STEPS = [(10, "", "title"), (40, "SPACE", ""), (41, "", ""), (1300, "", "h2"), (3590, "", "h5")]
STEPS += [(3600 + d, "", "w%04d" % d) for d in (100, 300, 500, 800)]
STEPS += [(4500, "", "end")]
