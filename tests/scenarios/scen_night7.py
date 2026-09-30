# Night 7 (custom night): choose it on the title screen, see the "7TH NIGHT" card, all four animatronics at level 20.
# tools/aidump.py build/vice.log shows the AI levels (ai_lvl = game variables +12..+15) from the dumps.
TITLE = True
DUMP = "0f00 0f2f"
STEPS = [(10, "", "title7_before"), (40, "7", ""), (42, "", ""), (60, "", "title7"),
         (70, "SPACE", ""), (71, "", ""), (120, "", "card7"), (520, "", "office7"), (900, "", "office7b")]
