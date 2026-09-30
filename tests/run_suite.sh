#!/bin/bash
# The full test suite: the game build (incl. the memory layout check; every scenario builds the test harness itself), every scenario with its dump checks,
# three fuzz seeds (office bitmap vs door/light state), the door+light mid-animation check.
# Optional: BASE=dir  -> afterwards pixel-compares build/shots with an earlier run (tests/compare_shots.py).
#   tests/run_suite.sh            about 15-20 minutes
cd "$(dirname "$0")/.."
log=build/suite.log; : > $log
res=()
step() { local name=$1; shift; echo "--- $name"; if "$@" >> $log 2>&1; then res+=("PASS  $name"); else res+=("FAIL  $name"); fi; }

step "build (game + layout check)" ./build.sh
tests/run_all.sh >> $log 2>&1; ra=$?
for s in tests/scenarios/scen_*.py; do n=$(basename $s .py); n=${n#scen_}; grep -A1 "^== $n " $log | tail -1 | grep -q "^snapshots" && ok=1 || ok=0
  grep -q "CHECK FAILED ($n)" $log && ok=0; [ $ok = 1 ] && res+=("PASS  scenario $n") || res+=("FAIL  scenario $n"); done
for seed in 1 2 3; do step "fuzz seed $seed (office buffer consistent)" python3 tests/fuzz.py $seed 2500; done
step "door/light mid-animation rows" bash -c "python3 tools/runtest.py tests/scenarios/scen_doorlight.py >/dev/null && python3 tests/check_midanim.py"
step "save to disk (beat night 1, reboot the same disk)" tests/check_save.sh
step "consistency scenario" bash -c "python3 tools/runtest.py tests/scenarios/scen_consist.py >/dev/null && python3 tests/check_consist.py"
[ -n "$BASE" ] && python3 tests/compare_shots.py "$BASE" build/shots $(ls tests/scenarios | sed 's/scen_//;s/\.py//') >> $log 2>&1

echo; printf '%s\n' "${res[@]}"
echo; echo "$(printf '%s\n' "${res[@]}" | grep -c ^PASS) passed, $(printf '%s\n' "${res[@]}" | grep -c ^FAIL) failed   (full log: $log)"
printf '%s\n' "${res[@]}" | grep -q ^FAIL && exit 1 || exit 0
