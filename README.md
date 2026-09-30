# Five Nights at Freddy's – Commodore 64

A port of the first *Five Nights at Freddy's* to the C64: the office with its doors, hall lights and
camera monitor **and now the actual game** – a night clock, power, four animatronics that follow the
movement rules of the original, jumpscares, power outages, and six nights.

* the office with two **doors** and two **hall lights**,
* the **security camera monitor** that flips up/down over the office,
* **11 camera posts** (1A–7) with a camera map; every picture changes with what is standing in the room,
* **Freddy, Bonnie, Chica and Foxy** moving by the original AI rules (see below),
* **clock (12 AM – 6 AM), power and usage**, power outage sequence, **jumpscares**, game over,
  6 AM win screen, night 1–6 with the original AI level tables,
* camera **static / noise / signal glitches**, door slide animation, screen shake, lamp flicker,
* **Phone Guy**: an automatic call at the start of nights 1–5 – phone ring, subtitles and a synthesised
  mumble instead of speech (`M` mutes it),
* SID sound effects, background hum, Freddy's music box and the 6 AM chime,
* a title screen (from `assets/lobby.png`) with night selection,
* **night 7, the 20/20/20/20 custom night** (unlocked by beating night 6) and a **pause** key (`P`),
* **saving to disk**: the reached night is written to the `.d64` after every night you beat, so the next start offers it again.

Everything is loaded from a single `.d64` using the **Sparkle 3.3** IRQ fast loader.

## Play

```
tools/fetch_tools.sh # once: downloads KickAssembler, copies the Sparkle binary
./build.sh          # builds dist/fnaf64.d64   (needs java, python3 + Pillow)
./run.sh            # starts it in VICE (x64sc) with true drive emulation
```

`dist/fnaf64.d64` also runs on a real C64 with a 1541-compatible drive / 1541 Ultimate
(Sparkle needs a real 1541-style drive; SD2IEC-type devices will not work). The loader needs
**true drive emulation** in VICE (`-drive8truedrive +virtualdev8`, which `run.sh` sets).
Autostart takes a few seconds; the title screen appears once the first files are loaded.
**Progress is saved into the disk image itself** (the `.d64` must not be write-protected, and playing modifies
`dist/fnaf64.d64`; `./build.sh` makes a fresh disk with a blank save).

### Controls

| Key | Action |
|---|---|
| `SPACE` | start the night (title) / raise and lower the camera monitor |
| `1`–`7` on the title | pick a night you have already reached (nights unlock by surviving the previous one; beating night 6 unlocks night 7; the reached night is kept on the disk, see *Saving*) |
| `A` / `L` | toggle left / right **door** |
| `S` / `K` | hold left / right **light** (only one at a time) |
| `M` | mute the phone call |
| `P` | pause / resume (office and monitor only): clock, animatronics, phone and sound stop, the border turns red |
| `1`–`7` | camera post: `1` cycles 1A/1B/1C, `2` cycles 2A/2B, `4` cycles 4A/4B, `3`, `5`, `6` (kitchen, audio only), `7` |
| `CRSR →` / `SHIFT+CRSR` | next / previous camera |
| Joystick port 2 | fire = camera, left/right = doors (office) or prev/next camera, up/down = left/right light |

The key letters are printed on the button icons next to the doors.
Switching a camera streams the new picture from disk, which takes about a second – the
monitor shows static meanwhile. Re-opening the monitor on the camera that is already loaded is
instant.

## How to play

Survive from **12 AM to 6 AM** (an in-game hour is 89.2 s, like the original; a night takes about 9 minutes).

* **Power** starts at 100 %. Standing around costs 1 % per 9.6 s; the monitor, every closed door and every
  lit hall light add to the *usage* (the bars under the power number) and drain it faster. From night 2 on there
  is an extra passive drain. At 0 % the office goes dark: Freddy's music box plays, the lights flicker
  out and he gets you – unless it is 6 AM first.
* **Bonnie** (left) and **Chica** (right) wander through the pizzeria and finally show up in a doorway. Hold the
  hall light to see them and **close the door** – they leave. If the door is open they get in and kill you the
  next time you lower the monitor (if you keep it up they pull it down themselves after a few seconds). While one
  is inside, that side's door and light are dead.
* **Foxy** hides in Pirate Cove (cam 1C) and gets bolder the longer you do *not* use the monitor (any camera
  counts). When the curtain is empty he sprints down the west hall (watch cam 2A) – close the left door.
  He bangs on it and takes 1 %, 6 %, 11 % … of your power each time; an open door means the jumpscare.
* **Freddy** only walks while the monitor is down and stops while you look at him. When he is in the east hall
  corner (4B) he comes in as soon as you look at any *other* camera with the right door open – so keep that
  door closed while you use the monitor away from 4B, and watch 4B. Once he is inside he kills at random
  (25 % per second) while the monitor is down.
* Cameras: the picture shows whoever stands in that room. When somebody moves in the room you are watching the
  feed breaks up for a moment. Chica clatters pots in the kitchen (cam 6 is audio only).

### Animatronic AI (from the FNaF wiki / community AI guides)

Every animatronic gets a **movement opportunity** every 3.02 s (Freddy) or ~5 s (the others). It moves if a
random number 1–20 is ≤ its **AI level**. Levels at 12 AM per night (Freddy / Bonnie / Chica / Foxy):

| night | 1 | 2 | 3 | 4 | 5 | 6 | 7 (custom) |
|---|---|---|---|---|---|---|---|
| start | 0/0/0/0 | 0/3/1/1 | 1/0/5/2 | 1-2/2/4/6 | 3/5/7/5 | 4/10/12/16 | 20/20/20/20 |

Bonnie gets +1 at 2 AM (not on night 2), Bonnie / Chica / Foxy get +1 at 3 AM and again at 4 AM.
Paths: Bonnie 1A → 1B / backstage → west hall / supply closet → west hall corner → left door; Chica 1A → 1B →
restrooms / kitchen → east hall → east hall corner → right door; Freddy the same way as Chica but in a straight
line and only after Bonnie and Chica left the stage; Foxy 1C → west hall. After a closed door Bonnie returns to the
dining area and Chica to the east hall; Foxy returns to his cove.
The AI is in `src/game.asm` (tables at the end of the file).

## How it works

### Display: one raster IRQ per text row
All full-screen pictures are 320×200 bitmaps that live in different VIC banks, and the game
never copies pixels to change the picture. Instead a raster IRQ **switches the VIC bank, the
screen/bitmap pointers and the hires/multicolor mode for every text row** (`IrqRow`, fired on the
last raster line of the previous row). Any row can show any of these layers:

| layer | where | mode |
|---|---|---|
| office | bank 0 (`$2000` bitmap, `$0400` colours) | hires |
| camera | bank 1 (`$6000` bitmap, `$4000` colours, colour RAM) | multicolor |
| title | bank 1 (same buffer, before the first camera is loaded) | hires |
| static | bank 3 (`$e000` random bitmap + 4 random colour screens, random X-scroll per row) | hires |
| edge bars | bank 3 (screens filled with one solid colour) | hires |

Because rows are independent, the effects are just tables of "which layer does row *n* show":

* **monitor flip** – a 3-row shaded edge bar sweeps up (or down) with the camera feed (or static
  while it is still loading) on one side and the office on the other,
* **static burst / dissolve** – all rows noise, then rows switch to the picture in a shuffled order,
* **camera life** – per-row X-scroll jitter, random glitch lines, a rolling static band and
  occasional full-screen static flashes while a camera is up,
* frames without any effect use a single set of registers and no row IRQs.

### Office
The office is one bitmap. The door and light artwork are cut out into small **patches**
(22 rows; a record is the 7 cells of one row that are ever copied – 5 door + 2 window cells, 63 bytes) stored in bank 2. A door closing is a
row-by-row sweep of the closed patch over the open one with a hazard-stripe edge that follows
the sweep; opening runs it backwards; lights swap a patch variant. The main loop does the
copying (`DoorStep`, `LightRender`), the frame IRQ only advances the logic.
Door and window are separate cell ranges of each patch: the door follows the door state, the window follows the light alone, so a lit window shows through even with the door shut. Buttons are sprites (ring + lit overlay). Extras: door-slam **screen shake** (`$d011` scroll),
a flashing ceiling lamp (three brightness levels, colour cells) and a **spinning desk fan** (four prepared frames of
sweeping dithered blades, redrawn every third frame by `FanStep`), light flicker.

### Cameras and the HUD
Each camera picture is converted to a multicolor bitmap with the camera title and map baked in
(selected post highlighted), so switching cameras is one Sparkle bundle (`$6000` bitmap,
`$4000` screen, `$d800` colour RAM, loaded straight to the destination). Every camera has one
bundle **per picture** (31 in total, e.g. the stage has five: all three / no Bonnie / no Chica / only
Freddy / empty); `WantFrame` in `src/game.asm` picks the picture from the animatronic positions, and when
something moves in the room you are watching the feed breaks up and the new picture streams in.
`REC` is a blinking sprite.

The **live HUD** (power, usage bars, clock, night) is plotted at run time by `src/hud.asm`: the 64 uppercase
glyphs are copied from the character ROM at start-up and written straight into the bitmaps – one cell per
character in the hires office, two cells per character (pixel doubled) in the multicolor camera picture. The
camera pictures contain empty black plates for it. Text cards ("12:00 AM – 1ST NIGHT", "5 AM", "6 AM",
"GAME OVER") are drawn the same way with 2x2-cell glyphs into the camera buffer.

### Phone Guy
Digitised speech would need far too much disk space and CPU, so the call is **subtitles plus SID
"mumbling"**: `tools/gen_assets.py` (`PHONE`) holds the text for nights 1–5 and writes one tiny file per night
(≤ 448 bytes: subtitle lines and pauses). Each file is its own Sparkle bundle, loaded to `$4a40` while the
night card is up. `src/phone.asm` does the rest from the frame tick: 3 s of quiet, three rings (pulse wave with
a pitch warble), then one line at a time with a sawtooth blip at a random voice-like pitch every four frames and a
hang-up click. The subtitle is **text row 24 shown as its own display layer** (`LAY_SUB`: bank 1, screen `$4400`,
bitmap `$6000` – the last row of the camera bitmap buffer, which the main loop plots the characters into with the
same ROM font as the HUD), so it appears over the office and over the camera picture without touching either.
The call stops on death, power outage, morning or when muted. The dialogue is my own condensed wording in
Phone Guy's style, not a transcript.

### Saving
Sparkle can overwrite a predefined *hi-score file* on the last track of the disk, which is what the game uses
(`tools/mksls.py`: a saver plugin at directory index `$7e` and a blank one-page `HSFile` at `$7f`, loaded to
`SAVE_BUF` = `$bd00`). At start-up the page is loaded and `ApplySave` reads `magic $a5, night, night EOR $ff`; a blank
disk fails the check, so the game starts at night 1. When a night is beaten and it opens a new one (`AdvanceNight`
sets `g_savereq`), the next bundle load in the main loop (`MainJobs`) first runs `DoSave`: it writes the record into the
page, loads the saver plugin and calls `Sparkle_Save` – the title screen static covers the second or so that the
drive needs. The record lives **inside the disk image**, so the progress stays in the `.d64` you play (VICE writes it
back with true drive emulation; a real 1541 / 1541 Ultimate writes it to the disk), and a rebuild (`./build.sh`) starts
from a blank save again. After night 6 (night 7 unlocked) the next start selects night 1, as it does in a running session.

### Game flow
`mode` in `src/main.asm` is the top-level state; the frame IRQ runs the state machine, the game tick
(`GameTick` → 10 Hz `GameDs`) and the effects. The main loop owns the loader: the IRQ asks it for bundle
loads and text cards through `mjob` / `mbusy`.

```
title → static → night card (office assets load meanwhile) → office ⇄ monitor ⇄ camera switching
   office/camera → power out → dark office → Freddy in the doorway (music box) → blackout → jumpscare
   any animatronic → static → jumpscare frame 1 → static → frame 2 → GAME OVER → title
   6 AM → "5 AM" rolls up and the "6" rolls in from below + chime → (newspaper after night 5, ending card after night 6) → title, next night
```
The 12 AM card is on screen while the office bundle is (re)loaded, which also resets the office picture,
patches and sprites. The dark-office pictures for the power outage replace the office bitmap the same way.
Bonnie and Freddy have no jumpscare art in `assets/`, so they are made from the existing pictures
(`gen_jumpscares` in `tools/gen_assets.py`): the supply-closet close-up and the title-screen face, each plus a 2x zoom.

### Sound
The tunes are plucked (attack/decay envelope, gate off between notes): a pulse-wave bell for the 6 AM chime and a
triangle music box for Freddy. Both follow the original game: the 6 AM chime is the Westminster chime (`E C D G – G D E C`,
played here as `G# E F# B – B F# G# E`), Freddy's music box is the *Toreador March* refrain from Bizet's *Carmen* in F# major
(the key of the original recording; the notes come from FNaF transcriptions and were checked against the pitches of the
game's `Music_box.ogg`). `WAV=out.wav python3 tools/runtest.py scenario.py` records the SID output (real-time,
no warp) and `tools/wavstat.py out.wav` prints level and pitch per second, which is how a stuck tone was found.

SID voice 1: fan rumble through the low-pass filter. Voice 2: 100 Hz light buzz / camera hiss, and the
melody player (6 AM chime, Freddy's music box). Voice 3: one-shot effects – door servo + thump, monitor
whoosh, camera blip, static bursts, footsteps, Freddy's laugh, the doorway sting, the scream, power-down,
pots and pans, groan, Foxy's knocks.

### Memory map
`tools/memmap.py` prints the real map of the last build (every region, the free gaps, the headroom of each code
segment); this is its summary. Bank 2 is never displayed, so it holds plain data and the bulk of the code.
```
$0160-$03ff Sparkle resident code + buffer
$0400 office colours   $0800 sprites   $0a40 fan frames   $0c00 tables   $0d00 font copy   $0f00 game variables
$1000 Code1 (IRQ engine, display, door animation; ~80 bytes spare)   $2000 office bitmap
$4000 camera colours   $4400 Code4 (tables/strings; $47c0 subtitle colours)   $4800 sprites   $4a40 phone text
$4c00 Code2 (state machine, AI, HUD, phone)   $6000 camera bitmap ($7e00 subtitle pixels)
$8000-$ac4b door/light patches (11340 bytes)
$ad00-$bcff Code3 (sound, pause, save, tables, test harness; ~3 KB spare)   $bd00 save page   $be40 fan frames
$c000.. noise/bar screens (also under I/O), $c800 sprites, $e000 noise bitmap
```
`tools/check_layout.py` runs on every build and fails if anything that lives in RAM at the same time overlaps; the
region list lives in `tools/layout.py`. **Where new code goes:** Code3 is the spare segment (`.segment Code3`
before the code); Code1 holds the timing-critical IRQ code and is nearly full.

Memory history: the patch records used to carry the two unused cells between door and window (9 cells, 81 bytes
per record, 14580 bytes in all); packing them to the 7 cells that are copied saved 3240 bytes, and Code3 moved
into that space, which took the spare code room from about 760 to about 4100 bytes. The test harness (with its
long key scripts) moved there too – it used to overflow Code2, which silently broke `scen_consist`.

## Repository layout

```
assets/            the supplied Multipaint art (used as is)
Sparkle3.3/        Sparkle distribution (unchanged; tools/sparkle is a copy of the Linux binary)
src/               6510 source (KickAssembler): main.asm (IRQ, state machine, display), game.asm (AI, clock,
                   power), hud.asm (text), phone.asm, sound.asm, pause.asm, defs.asm, test.asm
tools/             asset pipeline (gen_assets.py, c64img.py, mksls.py), memory tools (layout.py, check_layout.py,
                   memmap.py), KickAss, sparkle, test runner
build/             generated files (converted assets in build/gen, disk images)
dist/fnaf64.d64    the game
tests/             scripted emulator tests
```

The build: `gen_assets.py` converts PNGs (hires office + patches, dark offices, multicolor camera pictures,
jumpscares, sprites, title with key legend) → KickAssembler builds 4 code segments → `mksls.py` writes the
Sparkle script → `sparkle` builds the disk (~460 blocks of 664).

## Testing

`./build.sh test` adds a small harness (`src/test.asm`): a frame-timed key script and snapshot
hooks, and starts straight in the office. `tools/runtest.py scenario.py [outdir]` builds that, runs VICE
headless (monitor breakpoints take screenshots at chosen frames) and collects the PNGs;
`tools/shotview.py` tiles them. A scenario is a Python file with `STEPS = [(frame, "keys", "snapshot"), ...]`
and optional `NIGHT`, `AI = (freddy, bonnie, chica, foxy)` (override the AI levels), `POS = (...)` (start
positions), `POWER`, `DEFINES = ["FASTHOUR"]` (12 s hours) and `DUMP = "0f00 0f2f"` (memory dump per snapshot;
`tools/aidump.py` prints the game variables from it).

```
tests/run_suite.sh                    # THE FULL SUITE (~15 min): the build + layout check, every scenario and its
                                      # dump checks, 3 fuzz seeds, door/light mid-animation, consistency; PASS/FAIL list
BASE=old_shots tests/run_suite.sh     # ... and pixel-compare build/shots with an earlier run (tests/compare_shots.py)
tests/run_all.sh [x64sc|x64]          # every scenario in tests/scenarios/ (NTSC=1 for NTSC)
python3 tools/memmap.py               # memory map and free space of the last build
python3 tests/fuzz.py 3 2500          # random input, then checks the office bitmap in C64
                                      # memory equals what the door/light state requires
python3 tools/runtest.py tests/scenarios/scen_ai_bonnie.py    # e.g. Bonnie walking to the door
```
Scenarios that cover the new game: `scen_flow` (title → night card → office → camera), `scen_ai_*`
(Bonnie, Foxy, Freddy), `scen_scare_bonnie` (jumpscare sequence), `scen_power` (power outage),
`scen_win` (6 AM and the next night), `scen_doorway` (hall lights show Bonnie / Chica), `scen_gallery1-3`
(every camera with different animatronic positions), `scen_night7` / `scen_night7_play` / `scen_unlock7`
(the custom night: title choice, levels, unlock by beating night 6), `scen_pause` (clock and sound freeze, resume).
`tests/check_save.sh` (part of the suite) is the save test: beat night 1 on a fresh disk, check that the save record is on
the `.d64`, boot the *same* disk again (`NOBUILD=1` makes `runtest.py` reuse the last test disk) and check the title offers
night 2. Test builds normally unlock every night; `DEFINES = ["SAVETEST"]` turns that off so the disk decides.
Scenarios with a `tests/check_dumps.py` check fail the suite when the game variables are wrong; the others are
screenshots to look at (random static and disk timing make pixel-exact comparisons differ slightly between runs).

## Known limitations / next steps
* Camera switch ≈ 1 s (1541 random access + decompression); more RAM would allow caching pictures.
* Bonnie's and Freddy's jumpscares are improvised from existing art (no jumpscare pictures were supplied).
* Not implemented: Golden Freddy, a custom night with adjustable levels (night 7 is the fixed 20/20/20/20 one), real speech for the phone calls, score, animatronic art *inside* the office besides Bonnie / Chica in the
  hall-light windows.
* Some details are simplified: Foxy's aggravation level, the exact camera-glitch timings, Freddy's stage-by-stage
  power-out timings (approximated with random 5–20 s phases).
* The row-IRQ timing (`ROW_DELAY` in `src/defs.asm`) is tuned for VICE; a real machine may show a
  one-line glitch at row boundaries during transitions if it is off by a few cycles.

## How this was made

This whole project – the 6510 source, the asset conversion pipeline, the build and the emulator
test tooling, and this README – was written by **Claude (Sonnet 5.5, high effort)** in
**1 h 4 min 4 s**, working autonomously from a single starting prompt, testing everything in VICE
and debugging as it went.

The starting prompt, verbatim:

> Help me port the famous game Five Nights at Freddie's to the all time retro computer, the Commodore 64! Implement only the basics of the game mechanics first. When started, the user should be able to open the camera, switch camera posts, flash the door lights and close doors. You can ignore animatronic movement yet, menus and the game's end (death or win in the morning) aren't important by now. If you need fastloading, I recommend to use Sparkle, it's well documented and worked very well in the past! It's downloaded in the Sparkle3.3 directory. Put a big effort in visual effects (camera screen up/down, camera noise, door open/close), and maybe sound effects and background noise, but sound is way less important, than visuals! If you are unsure, how the game works, look it up online! The assets folder contains PNGs created with Multipaint, an app used to draw C64 images, so they are already C64 (I think multicolor) compatible, you can freely use them. If you need any other assets, generate them, or search the web for them! Please test the app, if it has bugs or issues, try to debug it! There are lots of C64 coding tutorials and manuals online (for 6502 assembly, VIC-II, SID, CIA chips), if you don't know something, free feel to surf the net, or if you need additional software, you can install anything, you want!

The second milestone (everything under "How to play": animatronic movement, clock, power, death / survival and
the six nights) was again written by Claude (Sonnet 5.5) from this prompt, looking up the mechanics online first and
testing every part in VICE:

> The game is amazing! Please continue the developement by adding the main game mechanics! (Animatronic movement, clock, death/survival, etc.) Please look up the exact game mechanics on the fnaf wiki about animatronic movement, and try to follow them! It's not obligatory to create a 1:1 copy of the original game, but try to be as close as possible! After implementation, test the game, and if everything's up and running, commit to git!
