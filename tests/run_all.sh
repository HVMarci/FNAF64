#!/bin/bash
# Runs the scripted emulator scenarios and prints where the screenshots are.
#   tests/run_all.sh [x64sc|x64]      (default x64sc; set NTSC=1 for NTSC)
cd "$(dirname "$0")/.."
export EMU=${1:-x64sc}
for s in tests/scenarios/scen_*.py; do
  n=$(basename $s .py); n=${n#scen_}
  echo "== $n ($EMU)"
  python3 tools/runtest.py $s build/shots/$n | tail -1
done
