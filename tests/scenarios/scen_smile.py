# F in the office: Freddy smiles on the poster while his nose honks (SFX_HONK, 21 frames), then the poster is back.
# A second honk is cut by a door (the door's effect takes voice 3): the smile goes at once.
# F with the monitor up does nothing. DUMP: sndvars ($0cb9 sfx_id, $0cba sm_t).
DUMP = "0ca0 0cbf"
STEPS = [(280, "", "before"),
         (300, "F", ""), (302, "", "s02"), (312, "", "s12"), (320, "", "s20"), (323, "", "s23"),
         (400, "F", ""), (402, "", "t02"), (405, "A", "t05"), (407, "", "t07"),
         (500, "SPACE", ""), (503, "", ""), (700, "F", ""), (703, "", "cam"), (720, "SPACE", ""), (723, "", ""),
         (780, "", "back")]
