# P pauses: clock (g_hds), power and door logic freeze, the border is red, P again resumes.
# tools/aidump.py prints hds/power per snapshot: p1 == p2 (paused), r1/r2 keep counting.
# A door key pressed while paused is ignored (the door is still open in "resumed").
DUMP = "0f00 0f3f"
STEPS = [(60, "", "a"),
         (100, "P", ""), (104, "", ""), (150, "", "p1"),
         (160, "A", ""), (200, "", ""), (400, "", "p2"),
         (420, "P", ""), (424, "", ""), (470, "", "r1"), (800, "", "r2"),
         # the same on the camera monitor
         (900, "SPACE", ""), (903, "", ""), (1100, "", "cam"),
         (1110, "P", ""), (1114, "", ""), (1160, "", "cp1"), (1400, "", "cp2"),
         (1420, "P", ""), (1424, "", ""), (1500, "", "cr1"), (1700, "", "cr2")]
