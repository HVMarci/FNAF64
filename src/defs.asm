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
.const SIDE_SZ      = 5508
.const P_N          = 0
.const P_L          = 1782
.const P_C          = 3564
.const P_S          = 5346

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
