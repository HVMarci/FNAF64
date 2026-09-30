#!/bin/bash
# Build the C64 FNaF disk image.   ./build.sh [test|unlocked]
#   test      adds the scripted test harness
#   unlocked  builds dist/fnaf64_all_nights.d64: a disk whose save says every night (1-7) is open
set -e
cd "$(dirname "$0")"
DEFS=""
NAME=fnaf64
if [ "$1" = "unlocked" ]; then NAME=fnaf64_all_nights; export SAVE_NIGHT=7; fi
if [ "$1" = "test" ]; then DEFS="-define TEST $KADEFS"; NAME=fnaf64_test; if [ -z "$TITLE" ]; then DEFS="$DEFS -define SKIPTITLE"; fi; fi
mkdir -p build
python3 tools/gen_assets.py
if [ "$1" != "test" ]; then : > build/test_script.asm; fi
java -jar tools/kickass/KickAss.jar src/main.asm -odir ../build -symbolfile $DEFS > build/kickass.log 2>&1 || { cat build/kickass.log; exit 1; }
grep -A12 "Memory Map" build/kickass.log
python3 tools/mksls.py $NAME
python3 tools/check_layout.py $NAME
tools/sparkle build/$NAME.sls | grep -E "Final|Error|error"

if [ "$1" = "unlocked" ]; then mkdir -p dist && cp build/$NAME.d64 dist/$NAME.d64 && echo "-> dist/$NAME.d64"
elif [ "$1" != "test" ]; then mkdir -p dist && cp build/$NAME.d64 dist/fnaf64.d64 && echo "-> dist/fnaf64.d64"; fi
