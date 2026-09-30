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
//  bank 2  (never displayed) $8000 door/light patches, $ac00 code + data
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
.const REC_SZ       = 81
.const SIDE_SZ      = 7290
.const P_N          = 0
.const P_L          = 1782
.const P_C          = 3564
.const P_S          = 5346
.const P_A          = 5508      // light on + Bonnie / Chica in the doorway

// layers (row sources)
.const LAY_OFFICE   = 0
.const LAY_CAM      = 1
.const LAY_NOISE    = 2
.const LAY_BARW     = 3
.const LAY_BARG     = 4
.const LAY_BARD     = 5
.const LAY_TITLE    = 6

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

.const NUM_CAMS     = 11

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
.const MEL_CHIME    = 1
.const MEL_BOX      = 2
.label zwin          = $69   // main temp: 0 door cells / 1 window cells
.label wdrawn       = $6a   // 2 bytes: window variant drawn

//------------------------------------------------------------------------------
// Game state (RAM $0f00.., see src/game.asm). Font copy at $0d00 (64 glyphs).
//------------------------------------------------------------------------------
.const FONT         = $0d00
.label gv           = $0f00
.label g_night      = gv+0      // 1..6
.label g_maxnight   = gv+1
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
.label knock_tm     = gv+49
.label kitchen_tm   = gv+50
.label groan_tm     = gv+51
.label hbuf         = gv+56     // 24 bytes: text buffer (screen codes, $ff terminated)
.label hcol         = gv+80
.label hval         = gv+81
.label tbmp_hi      = gv+82
.label tscr_hi      = gv+83
.label mel_ptr      = gv+84     // 2
.label mel_left     = gv+86
.label mel_id       = gv+87
.label mel_loop     = gv+88
.label g_gt         = gv+90     // 8 bytes of temporaries for the game tick
.label tt_left      = gv+100    // title night text drawn flag

// main loop jobs
.const J_LOAD       = 1
.const J_CARD       = 2
.const J_TITLETXT   = 3
// card types
.const CARD_NIGHT   = 0
.const CARD_5AM     = 1
.const CARD_6AM     = 2
.const CARD_OVER    = 3
.const CARD_END     = 4
// dir indices of the non-camera bundles
.const DI_OFFICE    = $0e
.const DI_TITLE     = $0f
.const DI_JS        = $40
.const DI_DARK      = $48
.const DI_DARKF     = $49
.const DI_NEWS      = $4a
#if FASTHOUR
.const HOUR_DS      = 120       // test builds: 12 s hours
#else
.const HOUR_DS      = 892       // 89.2 s per in-game hour (real game)
#endif
