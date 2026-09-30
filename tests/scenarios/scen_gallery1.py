# Camera gallery: Freddy 4B, Bonnie 2B, Chica 4A, Foxy peeking
NIGHT = 1
POS = (7, 4, 6, 1)
SEQ = ["2", "2", "3", "4", "4", "5", "6", "7", "1", "1", "1"]
NAMES = ["c2a", "c2b", "c3", "c4a", "c4b", "c5", "c6", "c7", "c1a", "c1b", "c1c"]
STEPS = [(100, "SPACE", ""), (101, "", "")]
t = 300
for k, n in zip(SEQ, NAMES):
    STEPS += [(t, k, ""), (t + 1, "", ""), (t + 170, "", n)]
    t += 200
