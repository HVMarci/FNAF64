#!/bin/bash
# Start the game in VICE. The Sparkle loader needs true drive emulation.
cd "$(dirname "$0")"
[ -f dist/fnaf64.d64 ] || ./build.sh
exec x64sc -drive8type 1541 -drive8truedrive +virtualdev8 -autostart dist/fnaf64.d64 "$@"
