//==============================================================================
// Five Nights at Freddy's - C64 port
// Definitions: memory map, zero page, constants
//==============================================================================
//
// Memory map (VIC banks are switched per raster row by the IRQ engine)
//
//  bank 0  $0400 office screen RAM        $0800 sprite images
//          $1000 code                     $2000 office hires bitmap
//  bank 1  $4000 camera screen RAM        $4800 sprite images
//          $4c00 code                     $6000 camera multicolor bitmap
//  bank 2  (never displayed) $8000 door/light patches, $ad00 code + data
//  bank 3  $c000.. noise / bar screens    $c800 sprite images
//          $e000 noise bitmap
//
// Sparkle loader lives at $0160-$03ff (stack limited to $0100-$015f).

.const OFF_SCR      = $0400
.const OFF_BMP      = $2000
.const CAM_SCR      = $4000
.const CAM_BMP      = $6000
.const NZ_BMP       = $e000
.const NZ_SCR0      = $c000     // noise screens: $c000 $c400 $cc00 $d000 $d400
.const SPR_DATA     = $0800     // offset $0800 in every bank -> pointer $20+n
.const SPR_PTR      = $20

.const PATCHES      = $8000
// Patch records: one text row of one side, packed to the 7 cells that are ever copied (5 door + 2 window cells;
// the 2 cells between them are not): 56 bitmap bytes + 7 screen bytes. Layout per side (tools/gen_assets.py):
//   N(22) L(22) C(22) S(2) A(22) records.  Left record:  door bmp 0-39, window bmp 40-55, door scr 56-60, window scr 61-62
//                                          Right record: window bmp 0-15, door bmp 16-55, window scr 56-57, door scr 58-62
.const REC_SZ       = 63
.const SIDE_SZ      = 90*REC_SZ
.const P_N          = 0
.const P_L          = 22*REC_SZ
.const P_C          = 44*REC_SZ
.const P_S          = 66*REC_SZ
.const P_A          = 68*REC_SZ    // light on + Bonnie / Chica in the doorway
// Button cells (the buttons are part of the office picture), after the two sides: 4 buttons (L door, L light, R door,
// R light) x 2 states (off, lit) x 18 bytes = bitmap of the upper cell, of the lower cell, their 2 screen bytes
.const BTN_DATA     = PATCHES + 2*SIDE_SZ
.const BTN_SZ       = 18

// Foxy's jumpscare (src/foxy.asm) lives in the door patch area, which is free from the moment someone dies until the next night's
// office bundle reloads it. It arrives with Foxy's bundle: the sprite (tools/gen_assets.py gen_foxy_sprite) and the code; the strip
// of the office he runs over is copied to FX_BG when the scare starts.
.const FX_BG        = $8000     // office columns 0-14, rows 2-24: per row 120 bitmap bytes (23 rows)
.const FX_BGS       = $8ac8     // ... then 15 colour bytes per row
.const FX_SPB       = $8d00     // sprite bitmap: 23 rows x 12 cells x 8 bytes (his cells; the rest is 0)
.const FX_SPS       = $95a0     // sprite colours: 23 rows x 29 bytes: 3 + 12 + 14, a transparent cell has the colour byte $ff
.const FX_CODE      = $9a00

// layers (row sources)
.const LAY_OFFICE   = 0
.const LAY_CAM      = 1
.const LAY_NOISE    = 2
.const LAY_BARW     = 3
.const LAY_BARG     = 4
.const LAY_BARD     = 5
.const LAY_TITLE    = 6
.const LAY_SUB      = 7         // subtitle row: text row 24 from bank 1 (screen $4400, bitmap $6000)

// modes
.const M_OFFICE     = 0
.const M_CAM        = 1
.const M_UP         = 2
.const M_DOWN       = 3
.const M_SWITCH     = 4
.const M_TITLE      = 5
.const M_START      = 6
.const M_CARD       = 7         // night intro card, office assets load meanwhile
.const M_POWER      = 8         // power outage sequence
.const M_SCARE      = 9         // jumpscare
.const M_OVER       = 10        // game over card
.const M_WIN        = 11        // 5 AM -> 6 AM
.const M_TOTITLE    = 12        // back to the title screen
.const M_NEWS       = 13        // the newspaper before the first night

// door states
.const DS_OPEN      = 0
.const DS_CLOSING   = 1
.const DS_CLOSED    = 2
.const DS_OPENING   = 3

// key bits
.const KA_LD        = $01
.const KA_LL        = $02
.const KA_RL        = $04
.const KA_RD        = $08
.const KA_CAM       = $10
.const KA_PREV      = $20
.const KA_NEXT      = $40
.const KA_MUTE      = $80
.const KC_JL        = $01
.const KC_JR        = $02
.const KC_JF        = $04
.const KC_JU        = $08
.const KC_JD        = $10
// events
.const EV_LD        = $01
.const EV_RD        = $02
.const EV_CAM       = $04
.const EV_PREV      = $08
.const EV_NEXT      = $10
.const EV_MUTE      = $20

.const NUM_CAMS     = 11
.const NIGHTS       = 7         // 1-6 the story, 7 = custom night (every animatronic at level 20)

// zero page ------------------------------------------------------------------
.label zsa          = $10
.label zsx          = $11
.label zsy          = $12
.label zt           = $13
.label rng          = $5c   // 2 bytes
.label frame        = $15
.label frameh       = $16
.label mode         = $17
.label tph          = $18
.label tcnt         = $19
.label cam_cur      = $1a
.label cam_loaded   = $1b
.label can_load     = $1c
.label rowcur       = $1d
.label ka_now       = $1e
.label ka_prev      = $1f
.label kb_now       = $20
.label kb_prev      = $21
.label kc_now       = $22
.label kc_prev      = $23
.label ev           = $24
.label evdigit      = $25
.label zsrc         = $26   // 2
.label zdb          = $28   // 2
.label zds          = $2a   // 2
.label zside        = $2c
.label zvar         = $2d
.label zrow         = $2e
.label zt2          = $2f
.label dstate       = $30   // 2  (left, right)
.label dedge        = $32   // 2  (0..24 = edge position + 2)
.label ddrawn       = $34   // 2
.label lwant        = $36   // 2
.label ldrawn       = $38   // 2
.label lvar         = $3a   // 2  variant used for the "open" rows (0 normal / 1 lit)
.label lflick       = $3c   // 2
.label sprmode      = $3e   // 0 none, 1 office, 2 camera
.label glitch_row   = $3f
.label glitch_cnt   = $40
.label glitch_x     = $41
.label band_row     = $42
.label band_wait    = $43
.label band_wait_h  = $44
.label keyraw       = $45   // 16 bytes ($45-$54)
.label joy          = $55
.label rev_cnt      = $56
.label flash        = $57
.label snd_flags    = $58
.label tsp          = $59   // test script pointer (2)

// RAM tables (bank 0, $0c00+; $0800-$0a3f holds the sprite images) -------------------------------------------------
.label rowlayer     = $0c00 // 25
.label rowxs        = $0c20 // 25
.label tab_d018     = $0c40 // 25
.label tab_dd02     = $0c60 // 25
.label tab_d016     = $0c80 // 25
.label sndvars      = $0ca0 // 32 bytes for the sound engine
.label chain_on     = $5b
.label lastf        = $5e
.label ztx          = $5f
.label mt           = $60   // main-loop temporaries (never touched by IRQ code)
.label mt2          = $61

.const ROW_DELAY    = 7

// sound effects
.const SFX_DOOR     = 0
.const SFX_FLIP     = 1
.const SFX_BLIP     = 2
.const SFX_STATIC   = 3
.label wlow         = $62
.label revlay       = $63
.label shake        = $64
.label lamp_cnt     = $65
.label lamp_wait    = $66
.label lamp_cur     = $67
.const SFX_SERVO    = 4
.const SFX_STEP     = 5
.const SFX_LAUGH    = 6
.const SFX_STING    = 7
.const SFX_SCREAM   = 8
.const SFX_POWER    = 9
.const SFX_CLATTER  = 10
.const SFX_GROAN    = 11
.const SFX_KNOCK    = 12
.const SFX_RING     = 13
.const SFX_CLICK    = 14
.const SFX_CLANG    = 15        // kitchen: pot ding (loud), then the quiet versions of both sounds
.const SFX_CLATTERQ = 16
.const SFX_CLANGQ   = 17
.const MEL_CHIME    = 1
.const MEL_BOX      = 2
.const MEL_KITCHEN  = 3        // Freddy in the kitchen: the music box, loud on camera 6, quiet everywhere else
.label zwin          = $69   // main temp: 0 door cells / 1 window cells
.label wdrawn       = $6a   // 2 bytes: window variant drawn
.label bdrawn       = $68   // door / light buttons drawn lit in the office picture (bit 0 L door, 1 L light, 2 R door, 3 R light)

//------------------------------------------------------------------------------
// Game state (RAM $0f00.., see src/game.asm). Font copy at $0d00 (64 glyphs).
//------------------------------------------------------------------------------
.const FONT         = $0d00
.label gv           = $0f00
.label g_night      = gv+0      // 1..7
.label g_maxnight   = gv+1
.const NF_STEP      = 8         // newspaper fade: frames per level (NewsFade shifts by 3)
.label nf_cur        = gv+242    // newspaper fade level (src/newsfade.asm)
.label nf_lo         = $0bba     // 16 + 16 bytes: nibble tables of the current fade level
.label nf_hi         = $0bca
.label g_savereq    = gv+240    // 1: write the reached night to the disk before the next load
.label jshake       = gv+241    // 1: the jumpscare shakes the screen vertically (ShakeUpdate)
.label g_act        = gv+2      // 1 while the night clock and the animatronics run
.label g_hour       = gv+3      // 0 (12 AM) .. 6
.label g_hds        = gv+4      // 2 bytes: deciseconds left in this hour
.label g_dsacc      = gv+6
.label g_fps        = gv+7
.label g_power      = gv+8      // percent
.label g_pacc       = gv+9
.label g_ppass      = gv+10
.label g_usage      = gv+11
.label ai_lvl       = gv+12     // 4: Freddy, Bonnie, Chica, Foxy
.label ai_tm        = gv+16     // 4: deciseconds to the next movement opportunity
.label ai_pos       = gv+20     // 4: camera index / 11 doorway / 12 office (Foxy: stage 0-3)
.label fx_run       = gv+24
.label fx_frz       = gv+25
.label fx_hits      = gv+26
.label fx_seen      = gv+27
.label fr_tm        = gv+28
.label g_pkill      = gv+29
.label g_pull       = gv+30
.label adoor        = gv+31     // 2: Bonnie / Chica stands in the doorway
.label a_seen       = gv+33     // 2
.label g_who        = gv+35
.label sc_ph        = gv+36
.label ps_stage     = gv+37
.label ps_tm        = gv+38
.label hud_dirty    = gv+39     // bit0 office, bit1 camera
.label fwant        = gv+40
.label fmark        = gv+41     // tie breaker for rooms with several animatronics
.label mjob         = gv+42
.label marg         = gv+43
.label mbusy        = gv+44
.label camdirty     = gv+45
.label forcedown    = gv+46
.label blank        = gv+47
.label knock        = gv+48
.label g_pause      = gv+52     // 1 while paused (P)
.label p_key        = gv+53     // P key down now
.label p_prev       = gv+54     // ... and in the previous frame
.label knock_tm     = gv+49
.label kitchen_tm   = gv+50
.label groan_tm     = gv+51
.label kit_hits     = gv+55     // kitchen clatter: hits left in the burst
.label hbuf         = gv+56     // 24 bytes: text buffer (screen codes, $ff terminated)
.label kd_now       = gv+84     // keys: bit 0 left arrow, 1 = 8, 2 = 9, 3 = 0 (the digits 1-7 are kb_now)
.label kd_prev      = gv+85
.label keyraw2      = gv+106    // 4 bytes: left arrow, 8, 9, 0 down now
.label hcol         = gv+80
.label hval         = gv+81
.label tbmp_hi      = gv+82
.label tscr_hi      = gv+83
.label mel_ptr      = $71       // 2 (zero page: used with (),y)
.label mel_left     = gv+86
.label mel_id       = gv+87
.label mel_loop     = gv+88
.label mel_wave     = gv+89
.label mel_q        = gv+98     // 1: the note just started is a quiet one (released after its first frame)
.label g_gt         = gv+90     // 8 bytes of temporaries for the game tick
.label fan_tm       = gv+100
.label fan_i        = gv+101
.label roll_off     = gv+102     // 5 AM -> 6 AM scroll offset (lines) requested by the frame tick
.label roll_drawn   = gv+103
.label sc_pre       = gv+104     // 1: both jumpscare pictures were loaded during the power-out blackout
.label pw_irq       = gv+105     // power out stage 0: the frame tick draws the opening doors (the main loop is inside the loader)
.label roll_buf     = gv+112     // 64 bytes: two 16x32 strips (5 above 6)
.label ph_st        = gv+180     // phone call: 0 idle, 1 waiting, 2 ringing, 3 talking
.label ph_tm        = gv+181
.label ph_rings     = gv+182
.label sub_on       = gv+183     // subtitle row visible
.label sub_req      = gv+184     // main loop: redraw the subtitle row
.label sub_len      = gv+185
.label ph_loaded    = gv+186
.label sub_buf      = gv+192     // 40 screen codes + $ff
.label ph_ptr       = $73        // zero page (2): position in the call text
.label ph_src       = $75        // zero page (2)

// main loop jobs
.const J_LOAD       = 1
.const J_CARD       = 2
.const J_TITLETXT   = 3
.const J_NFADE      = 4         // newspaper fade: set the colour level in marg
.const J_NFINIT     = 5         // newspaper fade: copy its colours, start black
// card types
.const CARD_NIGHT   = 0
.const CARD_5AM     = 1
.const CARD_6AM     = 2
.const CARD_OVER    = 3
.const CARD_END     = 4
// dir indices of the non-camera bundles
.const DI_OFFICE    = $0e
.const DI_TITLE     = $0f
.const DISC_SECS    = 6         // the disclaimer stays up at least this many seconds (BCD, below 10)
.const DI_JS        = $40       // + 2 * who (+ 1: the second picture; Foxy has only the first: 2.png, his sprite and his code, see src/foxy.asm)
.const DI_DARK      = $48
.const DI_DARKF     = $49
.const DI_NEWS      = $4a
.const DI_TITLEH    = $4b       // the title with only Freddy's head shifted (office buffer)
.const DI_SAVER     = $7e       // Sparkle hi-score saver plugin
.const DI_SAVEFILE  = $7f       // the hi-score file: one page, loaded to SAVE_BUF at boot
.const SAVE_BUF     = $bd00
.const SAVE_MAGIC   = $a5
.const DI_PHONE     = $4f       // + night (1..5)
.const PHONE_BUF    = $4a40     // the night's call text (loaded from disk)
#if FASTHOUR
.const HOUR_DS      = 120       // test builds: 12 s hours
#else
.const HOUR_DS      = 892       // 89.2 s per in-game hour (real game)
#endif
