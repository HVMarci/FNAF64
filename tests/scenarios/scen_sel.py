STEPS = [(40, "SPACE", ""), (41, "", ""), (250, "SPACE", ""), (251, "", ""), (300, "SPACE", ""), (301, "", "")]   # the newspaper of night 1 first, then the monitor up
f = 500
# every camera key (left arrow, 1-9, 0), a repeated key (stays), then CRSR next / previous with the wrap-around
seq = [("ARROW","k_arrow"),("1","k1"),("2","k2"),("3","k3"),("4","k4"),("5","k5"),("6","k6"),("7","k7"),("8","k8"),("9","k9"),("0","k0"),("0","k0b"),("RIGHT","next_wrap"),("LEFT","prev_wrap"),("LEFT","prev2")]
for k,name in seq:
    if k == "LEFT": k = "LEFT"
    STEPS.append((f, k, "")); STEPS.append((f+1, "", "")); STEPS.append((f+130, "", name)); f += 140
