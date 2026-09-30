#!/bin/bash
# Runs the scripted emulator scenarios, prints where the screenshots are and runs the dump checks
# (tests/check_dumps.py) of the scenarios that have one.   tests/run_all.sh [x64sc|x64]   (NTSC=1 for NTSC)
cd "$(dirname "$0")/.."
export EMU=${1:-x64sc}
fail=0
for s in tests/scenarios/scen_*.py; do
  n=$(basename $s .py); n=${n#scen_}
  echo "== $n ($EMU)"
  python3 tools/runtest.py $s build/shots/$n 2>&1 | tail -1
  python3 tests/check_dumps.py $n || fail=1
done
exit $fail
