# Working rules for this repository

## Testing
- Do **not** run the full test suite (`tests/run_suite.sh`, `tests/run_all.sh`; 15-20 minutes) after every change.
  Run it only when it is really needed (e.g. a risky change to the display engine, memory layout or loader) or when explicitly asked.
- After a change, build with `./build.sh` (it includes the memory layout check) and, if needed, run only the one or two scenarios
  that touch the changed code: `python3 tools/runtest.py tests/scenarios/scen_<name>.py`.

## Git
- When a change is finished and everything is alright (it builds, the layout check passes, the relevant scenarios look right),
  **always commit and push** it. Do not wait to be asked.
- `dist/fnaf64.d64` is tracked: `./build.sh` rewrites it, so commit the rebuilt disk together with the source change.
