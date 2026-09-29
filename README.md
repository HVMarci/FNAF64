# Five Nights at Freddy's – Commodore 64

A port of the first *Five Nights at Freddy's* to the C64. This first milestone implements the
**basic office mechanics** with a lot of attention on the visuals:

* the office with two **doors** and two **hall lights**,
* the **security camera monitor** that flips up/down over the office,
* **11 camera posts** (1A–7) with a clickable-style camera map,
* camera **static / noise / signal glitches**, door slide animation, screen shake, lamp flicker,
* SID sound effects and background hum,
* a title screen (from `assets/lobby.png`).

Animatronic movement, night clock, power, jump-scares and the game end are **not** in yet
(the art for them is in `assets/` and the camera frames are already converted by the build).

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

### Controls

| Key | Action |
|---|---|
| `SPACE` | start game (title) / raise and lower the camera monitor |
| `A` / `L` | toggle left / right **door** |
| `S` / `K` | hold left / right **light** |
| `1`–`7` | camera post: `1` cycles 1A/1B/1C, `2` cycles 2A/2B, `4` cycles 4A/4B, `3`, `5`, `6` (kitchen, audio only), `7` |
| `CRSR →` / `SHIFT+CRSR` | next / previous camera |
| Joystick port 2 | fire = camera, left/right = doors (office) or prev/next camera, up/down = left/right light |

The key letters are printed on the button icons next to the doors.
Switching a camera streams the new picture from disk, which takes about a second – the
monitor shows static meanwhile. Re-opening the monitor on the camera that is already loaded is
instant.

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
(9 cells wide × 22 rows, 81 bytes per row record) stored in bank 2. A door closing is a
row-by-row sweep of the closed patch over the open one with a hazard-stripe edge that follows
the sweep; opening runs it backwards; lights swap a patch variant. The main loop does the
copying (`DoorStep`, `LightRender`), the frame IRQ only advances the logic.
Door and window are separate cell ranges of each patch: the door follows the door state, the window follows the light alone, so a lit window shows through even with the door shut. Buttons are sprites (ring + lit overlay). Extras: door-slam **screen shake** (`$d011` scroll),
flickering ceiling lamp (colour cells), light flicker.

### Cameras and the HUD
Each camera picture is converted to a multicolor bitmap with the **HUD baked in** (title text and
camera map with the selected post highlighted), so switching cameras is one Sparkle bundle
(`$6000` bitmap, `$4000` screen, `$d800` colour RAM, loaded straight to the destination).
`REC` is a blinking sprite.

### Sound
SID voice 1: fan rumble through the low-pass filter. Voice 2: 100 Hz light buzz / camera hiss.
Voice 3: door servo + thump, monitor whoosh, camera blip, static bursts.

### Memory map
```
$0160-$03ff Sparkle resident code + buffer
$0400 office colours   $0800 sprites   $0c00 tables   $1000 code
$2000 office bitmap    $4000 camera colours  $4800 sprites  $4c00 code  $6000 camera bitmap
$8000 door/light patches  $ac00 code+tables
$c000.. noise/bar screens (also under I/O), $c800 sprites, $e000 noise bitmap
```
`tools/check_layout.py` runs on every build and fails if any of these overlap.

## Repository layout

```
assets/            the supplied Multipaint art (used as is)
Sparkle3.3/        Sparkle distribution (unchanged; tools/sparkle is a copy of the Linux binary)
src/               6510 source (KickAssembler): main.asm, defs.asm, sound.asm, test.asm
tools/             asset pipeline (gen_assets.py, c64img.py, mksls.py), KickAss, sparkle, test runner
build/             generated files (converted assets in build/gen, disk images)
dist/fnaf64.d64    the game
tests/             scripted emulator tests
```

The build: `gen_assets.py` converts PNGs (hires office + patches, multicolor cameras with HUD,
sprites, title with key legend) → KickAssembler builds 3 code segments → `mksls.py` writes the
Sparkle script → `sparkle` builds the disk (~160 blocks of 664).

## Testing

`./build.sh test` adds a small harness (`src/test.asm`): a frame-timed key script and snapshot
hooks. `tools/runtest.py scenario.py [outdir]` builds that, runs VICE headless (monitor
breakpoints take screenshots at chosen frames) and collects the PNGs; `tools/shotview.py` tiles them.

```
tests/run_all.sh [x64sc|x64]          # every scenario in tests/scenarios/ (NTSC=1 for NTSC)
python3 tests/fuzz.py 3 2500          # random input, then checks the office bitmap in C64
                                      # memory equals what the door/light state requires
```
The suite was run on VICE `x64sc` and `x64`, PAL and NTSC.

## Known limitations / next steps
* Camera switch ≈ 1 s (1541 random access + decompression); more RAM would allow caching pictures.
* No animatronics yet – all camera frames are already converted (`build/gen/cam_<cam>_<frame>.*`),
  only frame 0 of each camera is on the disk for now.
* The row-IRQ timing (`ROW_DELAY` in `src/defs.asm`) is tuned for VICE; a real machine may show a
  one-line glitch at row boundaries during transitions if it is off by a few cycles.

## How this was made

This whole project – the 6510 source, the asset conversion pipeline, the build and the emulator
test tooling, and this README – was written by **Claude (Sonnet 5.5, high effort)** in
**1 h 4 min 4 s**, working autonomously from a single starting prompt, testing everything in VICE
and debugging as it went.

The starting prompt, verbatim:

> Help me port the famous game Five Nights at Freddie's to the all time retro computer, the Commodore 64! Implement only the basics of the game mechanics first. When started, the user should be able to open the camera, switch camera posts, flash the door lights and close doors. You can ignore animatronic movement yet, menus and the game's end (death or win in the morning) aren't important by now. If you need fastloading, I recommend to use Sparkle, it's well documented and worked very well in the past! It's downloaded in the Sparkle3.3 directory. Put a big effort in visual effects (camera screen up/down, camera noise, door open/close), and maybe sound effects and background noise, but sound is way less important, than visuals! If you are unsure, how the game works, look it up online! The assets folder contains PNGs created with Multipaint, an app used to draw C64 images, so they are already C64 (I think multicolor) compatible, you can freely use them. If you need any other assets, generate them, or search the web for them! Please test the app, if it has bugs or issues, try to debug it! There are lots of C64 coding tutorials and manuals online (for 6502 assembly, VIC-II, SID, CIA chips), if you don't know something, free feel to surf the net, or if you need additional software, you can install anything, you want!
