#!/bin/bash
# Save test: beat night 1 on a fresh disk, check that the game wrote the save onto the .d64, boot the same disk again
# and check the title offers night 2 (g_night = 2, g_maxnight = 2 in the dump of the second run's title).
cd "$(dirname "$0")/.."
S=tests/scenarios/scen_save.py
python3 tools/runtest.py $S build/save1 > build/save1.log 2>&1 || exit 1
d1=$(grep -a -m1 "^>C:0f00" build/vice.log | cut -c10-14)
[ "$d1" = "01 01" ] || { echo "CHECK FAILED (save): blank disk should start at night 1, got [$d1]"; exit 1; }
python3 - <<'PY' || exit 1
d = open("build/fnaf64_test.d64", "rb").read()
assert d.count(b"\xfd\x02\xa5") == 1, "save record (Sparkle stores the page reversed: fd 02 a5) not found on the disk after night 1"
print("disk holds the save record after night 1")
PY
NOBUILD=1 python3 tools/runtest.py $S build/save2 > build/save2.log 2>&1 || exit 1
d2=$(grep -a -m1 "^>C:0f00" build/vice.log | cut -c10-14)
[ "$d2" = "02 02" ] || { echo "CHECK FAILED (save): second boot should offer night 2, got [$d2]"; exit 1; }
echo "second boot starts at night 2: save loaded from disk"
