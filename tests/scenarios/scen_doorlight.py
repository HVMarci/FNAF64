# light switched on/off while the left door is closing and opening
STEPS = [(40, "A", ""), (41, "", ""),
         (48, "S", ""), (52, "S", "dl_lit_closing"), (53, "", ""), (58, "", "dl_unlit_closing"),
         (59, "S", ""), (63, "S", "dl_lit2_closing"),
         (100, "S", "dl_closed_lit"), (101, "", ""),
         (110, "A", ""), (111, "", ""), (114, "S", ""), (120, "S", "dl_lit_opening"), (121, "", ""), (127, "", "dl_unlit_opening"),
         (130, "S", ""), (137, "S", "dl_lit2_opening"), (138, "", ""), (200, "", "dl_end")]
DUMP = "0017 0040"
SAVES = {n: [("/home/hvmarci/Coding/fnaf64/build/mem_%s.bin" % n, 0x2000, 0x3f3f)] for n in ["dl_lit_closing","dl_unlit_closing","dl_lit2_closing","dl_lit_opening","dl_unlit_opening","dl_lit2_opening","dl_end"]}
