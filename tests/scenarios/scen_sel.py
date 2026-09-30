STEPS = [(40, "SPACE", ""), (41, "", ""), (250, "SPACE", ""), (251, "", "")]   # the newspaper of night 1 first
f = 400
seq = [("1","k1"),("1","k1b"),("1","k1c"),("1","k1d"),("2","k2"),("2","k2b"),("3","k3"),("4","k4"),("4","k4b"),("5","k5"),("6","k6"),("7","k7"),("RIGHT","next_wrap"),("LEFT","prev_wrap"),("LEFT","prev2")]
for k,name in seq:
    if k == "LEFT": k = "LEFT"
    STEPS.append((f, k, "")); STEPS.append((f+1, "", "")); STEPS.append((f+130, "", name)); f += 140
