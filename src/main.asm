//==============================================================================
// Five Nights at Freddy's - C64 port  (basic mechanics build)
//
// Assemble with KickAssembler:   java -jar KickAss.jar src/main.asm
// See README.md for the build pipeline (tools/build.sh).
//==============================================================================
.import source "../Sparkle3.3/Source/6510/Sparkle.inc"
.import source "defs.asm"

.segmentdef Code1 [start=$1000, max=$1fff]
.segmentdef Code2 [start=$4c00, max=$5fff]
.segmentdef Code3 [start=$ac00, max=$bfff]
.file [name="code1.prg", segments="Code1"]
.file [name="code2.prg", segments="Code2"]
.file [name="code3.prg", segments="Code3"]

//==============================================================================
.segment Code1
//==============================================================================
Start:
        sei
        lda #$35
        sta $01
        lda #$7f                // no CIA interrupts
        sta $dc0d
        sta $dd0d
        lda $dc0d
        lda $dd0d
        lda #$0b                // screen off while loading
        sta $d011
        lda #$00
        sta $d020
        sta $d021
        lda #$3c                // VIC bank 0 via $dd02 (Sparkle friendly)
        sta $dd02

        jsr Sparkle_LoadNext    // bundle 1: title screen (hires, camera buffer)
        lda #$3d                // show it: bank 1
        sta $dd02
        lda #$08
        sta $d018
        sta $d016
        lda #$3b
        sta $d011

        jsr Sparkle_LoadNext    // bundle 2: office bitmap, patches, sprites

        jsr InitState
        jsr InitNoise
        jsr InitSprites
        jsr SndInit

        // vectors live in RAM (KERNAL is off): they sit in the last bytes of the
        // noise bitmap, so they must be written after InitNoise
        lda #<NmiRti            // RESTORE key
        sta $fffa
        lda #>NmiRti
        sta $fffb
        // IRQ: frame tick at raster line 251
        lda #<IrqTick
        sta $fffe
        lda #>IrqTick
        sta $ffff
        lda #251
        sta $d012
        lda #$01
        sta $d01a
        sta $d019
        cli
        jmp Main

NmiRti: rti

//------------------------------------------------------------------------------
// Random (16 bit xorshift), result in A, preserves X/Y
//------------------------------------------------------------------------------
Random:
        lda rng+1
        lsr
        lda rng
        ror
        eor rng+1
        sta rng+1
        ror
        eor rng
        sta rng
        eor rng+1
        sta rng+1
        rts

//------------------------------------------------------------------------------
InitState:
        lda #$a5
        sta rng
        lda #$3c
        sta rng+1
        lda #0
        ldx #$5f
!:      sta $10,x
        dex
        bpl !-
        tax
!:      sta $0c00,x             // clear the table / sound variable area
        sta $0d00,x
        inx
        bne !-
        lda #$a5
        sta rng
        lda #$3c
        sta rng+1
        lda #$ff
        sta cam_loaded
        sta band_row
        lda #200
        sta band_wait
#if SKIPTITLE
        lda #M_OFFICE           // test builds start in the office
        sta mode
        lda #1
        sta sprmode
        lda #LAY_OFFICE
#else
        lda #M_TITLE
        sta mode
        lda #0
        sta sprmode
        lda #LAY_TITLE
#endif
        jsr SetAll
        jsr BuildTables
        rts

//------------------------------------------------------------------------------
// Noise bitmap ($e000), noise screens and bar screens (bank 3)
//------------------------------------------------------------------------------
InitNoise:
        lda #<NZ_BMP
        sta zdb
        lda #>NZ_BMP
        sta zdb+1
        ldx #32
        ldy #0
!:      jsr Random
        sta (zdb),y
        iny
        bne !-
        inc zdb+1
        dex
        bne !-
        // screens under I/O too
        lda #$34
        sta $01
        ldx #0
!:      lda noise_slots,x
        sta zdb+1
        lda #0
        sta zdb
        stx zsx
        jsr FillNoiseScreen
        ldx zsx
        inx
        cpx #4
        bne !-
        lda #$d8                // white bar screen
        ldx #$11
        jsr FillSolid
        lda #$dc                // grey bar screen
        ldx #$cc
        jsr FillSolid
        lda #$cc                // dark grey bar screen
        ldx #$bb
        jsr FillSolid
        lda #$35
        sta $01
        rts

// zdb points to a 1K block, fill 4 pages with random colour pairs
FillNoiseScreen:
        lda #4
        sta zt2
        ldy #0
!:      jsr Random
        and #$0f
        tax
        lda pairtab,x
        sta (zdb),y
        iny
        bne !-
        inc zdb+1
        dec zt2
        bne !-
        rts

// A = high byte of block, X = value
FillSolid:
        sta zdb+1
        lda #0
        sta zdb
        stx zt
        lda #4
        sta zt2
        ldy #0
!:      lda zt
        sta (zdb),y
        iny
        bne !-
        inc zdb+1
        dec zt2
        bne !-
        rts

//------------------------------------------------------------------------------
// Sprites
//------------------------------------------------------------------------------
InitSprites:
        // pointers
        ldx #7
!:      lda ptr_office,x
        sta $07f8,x
        lda ptr_cam,x
        sta CAM_SCR+$3f8,x
        sta NZ_SCR0+$3f8,x
        sta $c400+$3f8,x
        sta $cc00+$3f8,x
        dex
        bpl !-
        lda #$34
        sta $01
        ldx #7
!:      lda ptr_cam,x
        sta $d000+$3f8,x
        sta $d400+$3f8,x
        sta $d800+$3f8,x
        sta $dc00+$3f8,x
        dex
        bpl !-
        lda #$35
        sta $01
        // positions (office layout, keep in sync with tools/layout.py)
        ldx #7
!:      txa
        asl
        tay
        lda spr_x,x
        sta $d000,y
        lda spr_y,x
        sta $d001,y
        dex
        bpl !-
        lda #$00
        sta $d010
        // colours
        ldx #7
!:      lda spr_col,x
        sta $d027,x
        dex
        bpl !-
        lda #0
        sta $d015
        sta $d017
        sta $d01b
        sta $d01c
        sta $d01d
        rts

//==============================================================================
// IRQ: frame tick (raster line 251)
//==============================================================================
IrqTick:
        sta zsa
        stx zsx
        sty zsy
        lda #$01
        sta $d019
        inc frame
        bne !+
        inc frameh
!:
#if TEST
        jsr TestScript
#endif
        jsr ScanInput
#if TEST
        jsr TestOverride
#endif
        jsr StateMachine
        jsr BuildTables
        jsr SpriteUpdate
        jsr ShakeUpdate
        jsr LampUpdate
        jsr SndTick
        lda chain_on
        beq !+
        lda #<IrqRow
        sta $fffe
        lda #>IrqRow
        sta $ffff
        lda #0
        sta rowcur
        lda #50
        sta $d012
!:      ldy zsy
        ldx zsx
        lda zsa
        rti

//==============================================================================
// IRQ: per-row layer switch. Fires on the LAST raster line of the previous
// text row (line 50+8r) and writes the VIC registers for row r at the end of
// that line, so that the next badline fetches from the new bank/screen.
//==============================================================================
IrqRow:
        sta zsa
        stx zsx
        sty zsy
        ldy rowcur
        lda tab_d016,y
        tax
        lda tab_dd02,y
        sta zt
        lda tab_d018,y
        ldy zt
        .fill ROW_DELAY, $ea
        sta $d018
        sty $dd02
        stx $d016
        lda #$01
        sta $d019
        inc rowcur
        ldy rowcur
        cpy #25
        beq irr_last
        lda rowline,y
        sta $d012
        ldy zsy
        ldx zsx
        lda zsa
        rti
irr_last:
        lda #<IrqTick
        sta $fffe
        lda #>IrqTick
        sta $ffff
        lda #251
        sta $d012
        ldy zsy
        ldx zsx
        lda zsa
        rti

//==============================================================================
// Input
//==============================================================================
ScanInput:
        lda ka_now
        sta ka_prev
        lda kb_now
        sta kb_prev
        lda kc_now
        sta kc_prev
        ldx #14
si1:    lda kcol,x
        sta $dc00
        lda $dc01
        and krow,x
        beq si_p
        lda #0
        beq si_s
si_p:   lda #1
si_s:   sta keyraw,x
        dex
        bpl si1
        lda #$ff
        sta $dc00
        lda $dc00
        eor #$ff
        and #$1f
        sta joy
        // --- compose ka
        lda #0
        ldx keyraw+0
        beq !+
        ora #KA_LD
!:      ldx keyraw+1
        beq !+
        ora #KA_LL
!:      ldx keyraw+2
        beq !+
        ora #KA_RL
!:      ldx keyraw+3
        beq !+
        ora #KA_RD
!:      ldx keyraw+4
        beq !+
        ora #KA_CAM
!:      ldx keyraw+12
        beq si_nocrsr
        ldx keyraw+13
        bne si_prev
        ldx keyraw+14
        bne si_prev
        ora #KA_NEXT
        bne si_nocrsr
si_prev:
        ora #KA_PREV
si_nocrsr:
        sta ka_now
        // --- digits 1..7 -> kb bits 0..6
        lda #0
        ldx #6
!:      asl
        ldy keyraw+5,x
        beq !+
        ora #1
!:      dex
        bpl !--
        sta kb_now
        // --- joystick
        lda joy
        lsr
        lsr
        and #7
        sta kc_now
        lda joy
        and #3
        asl
        asl
        asl
        ora kc_now
        sta kc_now
        rts

//------------------------------------------------------------------------------
// Turn key states into events for the current mode
//------------------------------------------------------------------------------
Events:
        lda #0
        sta ev
        sta evdigit
        lda ka_prev
        eor #$ff
        and ka_now
        sta zt                  // new ka
        lda kc_prev
        eor #$ff
        and kc_now
        sta zt2                 // new kc
        lda zt
        and #KA_CAM
        beq !+
        lda #EV_CAM
        ora ev
        sta ev
!:      lda zt2
        and #KC_JF
        beq !+
        lda #EV_CAM
        ora ev
        sta ev
!:      lda mode
        bne ev_notoffice
        // office: doors
        lda zt
        and #KA_LD
        beq !+
        lda #EV_LD
        ora ev
        sta ev
!:      lda zt
        and #KA_RD
        beq !+
        lda #EV_RD
        ora ev
        sta ev
!:      lda zt2
        and #KC_JL
        beq !+
        lda #EV_LD
        ora ev
        sta ev
!:      lda zt2
        and #KC_JR
        beq !+
        lda #EV_RD
        ora ev
        sta ev
!:      rts
ev_notoffice:
        lda zt
        and #KA_PREV
        beq !+
        lda #EV_PREV
        ora ev
        sta ev
!:      lda zt
        and #KA_NEXT
        beq !+
        lda #EV_NEXT
        ora ev
        sta ev
!:      lda zt2
        and #KC_JL
        beq !+
        lda #EV_PREV
        ora ev
        sta ev
!:      lda zt2
        and #KC_JR
        beq !+
        lda #EV_NEXT
        ora ev
        sta ev
!:      // digits
        lda kb_prev
        eor #$ff
        and kb_now
        beq ev_nodigit
        ldx #0
!:      lsr
        bcs !+
        inx
        bne !-
!:      inx
        stx evdigit
ev_nodigit:
        rts

//==============================================================================
// Game state machine (runs in the frame tick)
//==============================================================================
StateMachine:
        jsr Events
        jsr DoorLogic
        jsr LightLogic
        lda mode
        bne !+
        jmp sm_office
!:      cmp #M_CAM
        bne !+
        jmp sm_cam
!:      cmp #M_UP
        bne !+
        jmp sm_up
!:      cmp #M_DOWN
        bne !+
        jmp sm_down
!:      cmp #M_SWITCH
        bne !+
        jmp sm_switch
!:      cmp #M_TITLE
        bne !+
        jmp sm_title
!:      jmp sm_start

// ---- title screen ----
sm_title:
        lda #0
        sta sprmode
        lda #LAY_TITLE
        jsr SetAll
        lda ev
        and #EV_CAM
        beq !+
        lda #M_START
        sta mode
        lda #0
        sta tph
        sta tcnt
        lda #SFX_STATIC
        jsr SndStart
!:      rts

// ---- title -> office: static burst, then the office dissolves in ----
sm_start:
        lda #0
        sta sprmode
        lda tph
        bne ts_p1
        lda #LAY_NOISE
        jsr SetAll
        inc tcnt
        lda tcnt
        cmp #8
        bcc ts_ret2
        lda #1
        sta tph
        lda #0
        sta tcnt
ts_ret2: rts
ts_p1:  lda #LAY_OFFICE
        sta revlay
        jsr RevealRows
        inc tcnt
        lda tcnt
        cmp #9
        bcc ts_ret2
        lda #M_OFFICE
        sta mode
        rts

// ---- office ----
sm_office:
        lda #1
        sta sprmode
        lda #LAY_OFFICE
        jsr SetAll
        lda ev
        and #EV_CAM
        beq !+
        lda #M_UP
        sta mode
        lda #0
        sta tph
        sta tcnt
        lda #1
        sta can_load
        lda #SFX_FLIP
        jsr SndStart
!:      rts

// ---- office -> camera ----
sm_up:
        lda #0
        sta sprmode
        lda tph
        bne up_p1
        ldx tcnt
        cpx #13
        bcs up_next
        lda #LAY_NOISE
        ldy cam_loaded
        cpy cam_cur
        bne !+
        lda #LAY_CAM            // cached feed rises with the monitor
!:      sta wlow
        lda wipe_up,x
        jsr WipeRows
        inc tcnt
        rts
up_next:
        lda cam_loaded
        cmp cam_cur
        bne !+
        jmp EnterCam
!:      lda #1
        sta tph
        lda #0
        sta tcnt
        lda #LAY_NOISE
        jmp SetAll
up_p1:  cmp #1
        bne up_p2
        lda #LAY_NOISE
        jsr SetAll
        lda tcnt
        cmp #200
        bcs !+
        inc tcnt
!:      lda tcnt
        cmp #6
        bcc up_ret
        lda cam_loaded
        cmp cam_cur
        bne up_ret
        lda #2
        sta tph
        lda #0
        sta tcnt
        lda #SFX_BLIP
        jsr SndStart
up_ret: rts
up_p2:  lda #LAY_CAM
        sta revlay
        jsr RevealRows
        inc tcnt
        lda tcnt
        cmp #9
        bcc up_ret
        jmp EnterCam

EnterCam:
        lda #M_CAM
        sta mode
        lda #2
        sta flash
        lda #$ff
        sta band_row
        lda #0
        sta glitch_cnt
        lda #40
        sta band_wait
        rts

// ---- camera steady state ----
sm_cam:
        lda #2
        sta sprmode
        lda ev
        and #EV_CAM
        beq sc_nocam
        lda #M_DOWN
        sta mode
        lda #0
        sta tph
        sta tcnt
        lda #SFX_FLIP
        jsr SndStart
        lda #LAY_CAM
        jmp SetAll
sc_nocam:
        // camera selection
        lda cam_cur
        sta zt2
        lda evdigit
        beq sc_nodig
        tax
        dex
        lda grp_start,x
        sta zt                  // start
        lda cam_cur
        sec
        sbc zt
        bcc sc_first            // below group
        clc
        adc #1                  // t = cam_cur - start + 1
        cmp grp_len,x
        bcs sc_first            // beyond or wrapped
        clc
        adc zt
        jmp sc_set
sc_first:
        lda zt
        jmp sc_set
sc_nodig:
        lda ev
        and #EV_NEXT
        beq sc_np
        lda cam_cur
        clc
        adc #1
        cmp #NUM_CAMS
        bcc sc_set
        lda #0
        jmp sc_set
sc_np:  lda ev
        and #EV_PREV
        beq sc_stay
        lda cam_cur
        bne !+
        lda #NUM_CAMS
!:      sec
        sbc #1
sc_set:
        cmp zt2
        beq sc_stay
        sta cam_cur
        lda #M_SWITCH
        sta mode
        lda #0
        sta tph
        sta tcnt
        lda #1
        sta can_load
        lda #SFX_STATIC
        jsr SndStart
        lda #LAY_NOISE
        jmp SetAll
sc_stay:
        lda flash
        beq sc_noflash
        dec flash
        lda #LAY_NOISE
        jmp SetAll
sc_noflash:
        lda #LAY_CAM
        jsr SetAll
        // --- analog jitter on a couple of random rows ---
        jsr RandRow
        tax
        jsr Random
        and #3
        sta rowxs,x
        jsr RandRow
        tax
        jsr Random
        and #1
        sta rowxs,x
        // --- big glitch line ---
        lda glitch_cnt
        beq g_none
        dec glitch_cnt
        ldx glitch_row
        lda glitch_x
        sta rowxs,x
        jmp g_done
g_none: jsr Random
        cmp #9
        bcs g_done
        jsr RandRow
        sta glitch_row
        jsr Random
        and #7
        cmp #2
        bcs !+
        lda #5
!:      sta glitch_x
        lda #2
        sta glitch_cnt
g_done:
        // --- occasional full static flash ---
        jsr Random
        bne !+
        lda #1
        sta flash
!:
        // --- rolling noise band ---
        lda band_row
        cmp #$ff
        bne b_active
        lda band_wait
        bne !+
        lda #0
        sta band_row
        rts
!:      dec band_wait
        rts
b_active:
        tax
        lda #LAY_NOISE
        sta rowlayer,x
        cpx #24
        bcs !+
        sta rowlayer+1,x
!:      lda frame
        and #1
        bne !+
        inc band_row
        lda band_row
        cmp #25
        bcc !+
        lda #$ff
        sta band_row
        jsr Random
        and #$7f
        clc
        adc #60
        sta band_wait
!:      rts

RandRow:                        // A = random row 0..24
        jsr Random
        and #$1f
        cmp #25
        bcc !+
        sbc #25
!:      rts

// ---- camera switch ----
sm_switch:
        lda #0
        sta sprmode
        lda #LAY_NOISE
        jsr SetAll
        lda tph
        bne sw_p1
        inc tcnt
        lda tcnt
        cmp #3
        bcc sw_ret
        lda #1
        sta tph
        lda #0
        sta tcnt
        lda #1
        sta can_load
sw_ret: rts
sw_p1:  cmp #1
        bne sw_p2
        lda tcnt
        cmp #200
        bcs !+
        inc tcnt
!:      lda tcnt
        cmp #6
        bcc sw_ret
        lda cam_loaded
        cmp cam_cur
        bne sw_ret
        lda #2
        sta tph
        lda #0
        sta tcnt
        rts
sw_p2:  lda #LAY_CAM
        sta revlay
        jsr RevealRows
        inc tcnt
        lda tcnt
        cmp #9
        bcc sw_ret
        jmp EnterCam

// ---- camera -> office ----
sm_down:
        lda #0
        sta sprmode
        lda #LAY_CAM
        sta wlow
        ldx tcnt
        cpx #14
        bcs dn_done
        lda wipe_dn,x
        jsr WipeRows
        inc tcnt
        rts
dn_done:
        lda #M_OFFICE
        sta mode
        lda #LAY_OFFICE
        jmp SetAll

//------------------------------------------------------------------------------
// row layer helpers
//------------------------------------------------------------------------------
SetAll:                         // A = layer
        ldx #24
!:      sta rowlayer,x
        dex
        bpl !-
        lda #0
        ldx #24
!:      sta rowxs,x
        dex
        bpl !-
        rts

// Boundary between office (rows < b) and wlow (rows > b+2); edge bars at b..b+2
WipeRows:
        sta zt
        ldx #0
wl:     cpx zt
        bcc wl_office
        beq wl_barw
        txa
        sec
        sbc zt
        cmp #1
        beq wl_barg
        cmp #2
        beq wl_bard
        lda wlow
        sta rowlayer,x
        cmp #LAY_CAM
        bne wl_nx
        jsr Random              // unstable signal below the edge
        and #3
        sta rowxs,x
        jmp wl_next
wl_office:
        lda #LAY_OFFICE
        beq wl_set
wl_barw:
        lda #LAY_BARW
        bne wl_set
wl_barg:
        lda #LAY_BARG
        bne wl_set
wl_bard:
        lda #LAY_BARD
wl_set: sta rowlayer,x
wl_nx:  lda #0
        sta rowxs,x
wl_next:
        inx
        cpx #25
        bne wl
        rts

// Dissolve noise -> camera image. Rows with ordtab < (tcnt+1)*3 show the camera
RevealRows:
        lda tcnt
        asl
        clc
        adc tcnt
        adc #3
        sta zt
        ldx #24
rv:     lda ordtab,x
        cmp zt
        lda revlay
        bcc rv_s
        lda #LAY_NOISE
rv_s:   sta rowlayer,x
        lda #0
        sta rowxs,x
        dex
        bpl rv
        rts

//------------------------------------------------------------------------------
// Turn rowlayer/rowxs into VIC register tables; decide if the row chain is needed
//------------------------------------------------------------------------------
BuildTables:
        lda #0
        sta chain_on
        ldx #24
bt_lp:  ldy rowlayer,x
        lda lay_d018,y
        sta tab_d018,x
        lda lay_dd02,y
        sta tab_dd02,x
        lda lay_d016,y
        ora rowxs,x
        sta tab_d016,x
        cpy #LAY_NOISE
        bne bt_nn
        jsr Random
        and #7
        tay
        lda noise_d018,y
        sta tab_d018,x
        jsr Random
        lsr
        lsr
        lsr
        and #7
        ora #$08
        sta tab_d016,x
bt_nn:  dex
        bpl bt_lp
        lda rowlayer
        cmp #LAY_NOISE
        beq bt_chain
        ldx #24
bt_u:   lda rowlayer,x
        cmp rowlayer
        bne bt_chain
        lda rowxs,x
        bne bt_chain
        dex
        bpl bt_u
        lda tab_d018
        sta $d018
        lda tab_dd02
        sta $dd02
        lda tab_d016
        sta $d016
        rts
bt_chain:
        lda #1
        sta chain_on
        rts

//------------------------------------------------------------------------------
// Door + light logic (frame tick)
//------------------------------------------------------------------------------
DoorLogic:
        ldx #1
dl_lp:  lda ev
        and evdoor,x
        beq dl_anim
        lda dstate,x
        cmp #DS_CLOSING
        beq dl_open
        cmp #DS_CLOSED
        beq dl_open
        lda #DS_CLOSING
        sta dstate,x
        bne dl_snd
dl_open:
        lda #DS_OPENING
        sta dstate,x
dl_snd: stx ztx
        lda #SFX_SERVO
        jsr SndStart
        ldx ztx
dl_anim:
        lda dstate,x
        cmp #DS_CLOSING
        bne dl_a2
        inc dedge,x
        lda dedge,x
        cmp #24
        bcc dl_next
        lda #DS_CLOSED
        sta dstate,x
        stx ztx
        lda #8
        sta shake
        lda #SFX_DOOR
        jsr SndStart
        ldx ztx
        jmp dl_next
dl_a2:  cmp #DS_OPENING
        bne dl_next
        dec dedge,x
        bne dl_next
        lda #DS_OPEN
        sta dstate,x
dl_next:
        dex
        bpl dl_lp
        rts

LightLogic:
        ldx #1
ll_lp:  lda #0
        ldy mode
        bne ll_set              // only in the office
        cpx #0
        bne ll_right
        lda ka_now
        and #KA_LL
        bne ll_held
        lda kc_now
        and #KC_JU
        jmp ll_chk
ll_right:
        lda ka_now
        and #KA_RL
        bne ll_held
        lda kc_now
        and #KC_JD
ll_chk: beq ll_set
ll_held:
        lda lflick,x
        beq ll_nf
        dec lflick,x
        lda #0
        beq ll_set
ll_nf:  jsr Random
        cmp #6
        bcs ll_on
        lda #2
        sta lflick,x
ll_on:  lda #1
ll_set: sta lwant,x
        dex
        bpl ll_lp
        rts

//------------------------------------------------------------------------------
// Sprites (frame tick)
//------------------------------------------------------------------------------
SpriteUpdate:
        lda sprmode
        bne !+
        sta $d015
        rts
!:      cmp #1
        bne spr_cam
        // office: rings + lit overlays
        lda #$0f
        ldx dstate
        beq !+
        cpx #DS_OPENING
        beq !+
        ora #$10
!:      ldx dstate+1
        beq !+
        cpx #DS_OPENING
        beq !+
        ora #$40
!:      ldx lwant
        beq !+
        ora #$20
!:      ldx lwant+1
        beq !+
        ora #$80
!:      sta $d015
        lda #90                 // slot 0 back to the door button
        sta $d000
        lda #108
        sta $d001
        lda #15
        sta $d027
        lda #0
        sta $d010
        rts
spr_cam:
        lda #38                 // REC indicator (x = 294 -> MSB set)
        sta $d000
        lda #56
        sta $d001
        lda #2
        sta $d027
        lda #1
        sta $d010
        lda frame
        and #$20
        beq !+
        lda #0
        sta $d015
        rts
!:      lda #1
        sta $d015
        rts

//------------------------------------------------------------------------------
// Screen shake when a door slams shut (vertical scroll jitter, decaying)
//------------------------------------------------------------------------------
ShakeUpdate:
        lda chain_on
        bne su_norm
        lda shake
        beq su_norm
        dec shake
        ldx shake
        lda shake_tab,x
        sta $d011
        rts
su_norm:
        lda #$3b
        sta $d011
        rts

//------------------------------------------------------------------------------
// Ceiling lamp flicker (office only): swaps the lamp's colour cells
//------------------------------------------------------------------------------
.macro LampCopy(tab) {
        .for (var i = 0; i < 30; i++) {
            lda tab + i
            sta OFF_SCR + floor(i / 6) * 40 + 17 + (i - 6 * floor(i / 6))
        }
}
LampDrawNorm:
        :LampCopy(lamp_data)
        rts
LampDrawDim:
        :LampCopy(lamp_data + 30)
        rts

LampUpdate:
        lda mode
        beq lu_office
        lda lamp_cur
        beq lu_ret
        lda #0
        sta lamp_cur
        jmp LampDrawNorm
lu_office:
        lda lamp_cnt
        beq lu_idle
        dec lamp_cnt
        ldx lamp_cnt
        lda lamp_pat,x
        jmp lu_apply
lu_idle:
        lda lamp_wait
        beq lu_start
        dec lamp_wait
        lda #0
        jmp lu_apply
lu_start:
        lda #8
        sta lamp_cnt
        jsr Random
        and #$7f
        clc
        adc #90
        sta lamp_wait
        lda #0
lu_apply:
        cmp lamp_cur
        beq lu_ret
        sta lamp_cur
        bne lu_dim
        jmp LampDrawNorm
lu_dim: jmp LampDrawDim
lu_ret: rts

//==============================================================================
.segment Code2
//==============================================================================
Main:
        lda frame
        sta lastf
mw:     lda frame
        cmp lastf
        beq mw
        sta lastf
        ldx #0
        jsr DoorStep
        ldx #1
        jsr DoorStep
        ldx #0
        jsr LightRender
        ldx #1
        jsr LightRender
        jsr CamCheck
        jmp Main

//------------------------------------------------------------------------------
// Load requested camera image when the effects allow it
//------------------------------------------------------------------------------
CamCheck:
        lda can_load
        beq cc_ret
        lda cam_cur
        cmp cam_loaded
        beq cc_ret
        sta mt2
        tax
#if TEST
        jsr LoadStartHook
#endif
        lda camidx_tab,x
        jsr Sparkle_LoadA
#if TEST
        jsr LoadEndHook
#endif
        lda mt2
        sta cam_loaded
cc_ret: rts

//------------------------------------------------------------------------------
// Door animation: move the drawn edge one step towards the wanted edge
//------------------------------------------------------------------------------
DoorStep:                       // X = side
        lda dedge,x
        cmp ddrawn,x
        beq ds_ret
        bcc ds_dec
        inc ddrawn,x
        jmp RenderEdge
ds_dec: dec ddrawn,x
        jmp RenderEdge
ds_ret: rts

// Render state k (= ddrawn-2): rows k-1 closed, k / k+1 hazard strip, k+2 open
RenderEdge:
        stx zside
        lda #0
        sta zwin                // door cells only
        lda ddrawn,x
        sec
        sbc #3                  // row k-1
        sta zrow
        cmp #22
        bcs !+
        lda #2
        sta zvar
        jsr CopyRec
!:      ldx zside
        lda ddrawn,x
        sec
        sbc #2                  // row k
        sta zrow
        cmp #22
        bcs !+
        lda #3
        sta zvar
        jsr CopyStrip0
!:      ldx zside
        lda ddrawn,x
        sec
        sbc #1                  // row k+1
        sta zrow
        cmp #22
        bcs !+
        lda #3
        sta zvar
        jsr CopyStrip1
!:      ldx zside
        lda ddrawn,x
        sta zrow                // row k+2 (open, normal or lit)
        cmp #22
        bcs !+
        lda lvar,x
        sta zvar
        jsr CopyRec
!:      rts

// strips: record index 0/1 inside the S patch, destination row = zrow
CopyStrip0:
        lda #0
        sta mt
        jmp CopyRecStrip
CopyStrip1:
        lda #1
        sta mt
// src record row index in mt (0/1) of variant 3, destination row zrow

CopyRecStrip:
        lda zrow
        sta mt2
        lda mt
        sta zrow
        jsr CopyRecSrc          // computes zsrc from zside/zvar/zrow
        lda mt2
        sta zrow
        jmp CopyRecDst

// Copy a full record of variant zvar, row zrow of side zside to the screen
CopyRec:
        jsr CopyRecSrc
CopyRecDst:
        ldx zside
        ldy zrow
        cpx #0
        bne cr_right
        lda rbl_lo,y
        sta zdb
        lda rbl_hi,y
        sta zdb+1
        lda rsl_lo,y
        sta zds
        lda rsl_hi,y
        sta zds+1
        jmp cr_copy
cr_right:
        lda rbr_lo,y
        sta zdb
        lda rbr_hi,y
        sta zdb+1
        lda rsr_lo,y
        sta zds
        lda rsr_hi,y
        sta zds+1
cr_copy:
        lda zside               // part = side*2 + window flag
        asl
        ora zwin
        tax
        clc
        lda zsrc
        adc boff,x
        sta zsrc
        bcc !+
        inc zsrc+1
!:      clc
        lda zdb
        adc boff,x
        sta zdb
        bcc !+
        inc zdb+1
!:      lda blen,x
        tay
        dey
!:      lda (zsrc),y
        sta (zdb),y
        dey
        bpl !-
        clc
        lda zsrc
        adc sadv,x
        sta zsrc
        bcc !+
        inc zsrc+1
!:      clc
        lda zds
        adc soff,x
        sta zds
        bcc !+
        inc zds+1
!:      lda slen,x
        tay
        dey
!:      lda (zsrc),y
        sta (zds),y
        dey
        bpl !-
        rts

// zsrc = side base + variant offset + row*81
CopyRecSrc:
        ldx zside
        ldy zvar
        clc
        lda sbase_lo,x
        adc voff_lo,y
        sta zsrc
        lda sbase_hi,x
        adc voff_hi,y
        sta zsrc+1
        ldy zrow
        clc
        lda zsrc
        adc mul81_lo,y
        sta zsrc
        lda zsrc+1
        adc mul81_hi,y
        sta zsrc+1
        rts

//------------------------------------------------------------------------------
// Lights: swap the door/window patch between normal and lit variant
//------------------------------------------------------------------------------
LightRender:                    // X = side
        lda lwant,x
        sta lvar,x              // variant used for the door's "open" rows
        cmp wdrawn,x
        beq lr_door
        // the window next to the door follows the light, whatever the door does
        sta wdrawn,x
        stx zside
        sta zvar
        lda #1
        sta zwin
        lda #0
        sta zrow
lr_wl:  jsr CopyRec
        inc zrow
        lda zrow
        cmp #22
        bne lr_wl
        lda #0
        sta zwin
        ldx zside
lr_door:
        // The rows below the door edge ("open" rows) always follow the light, also while
        // the door is moving: redraw them when the light changes. Rows above the edge
        // show the closed door and the strip rows are light independent.
        lda lwant,x
        cmp ldrawn,x
        beq lr_ret
        sta ldrawn,x
        stx zside
        sta zvar
        lda #0
        sta zwin
        lda ddrawn,x
        sta zrow                // first open row (>= 22: none, door fully closed)
lr_lp:  lda zrow
        cmp #22
        bcs lr_ret
        jsr CopyRec
        inc zrow
        jmp lr_lp
lr_ret: rts

//==============================================================================
.segment Code3
//==============================================================================
.import source "sound.asm"

#if TEST
.import source "test.asm"
#endif

//------------------------------------------------------------------------------
// Tables
//------------------------------------------------------------------------------
lay_d018:   .byte $18, $08, $08, $68, $78, $38, $08
lay_dd02:   .byte $3c, $3d, $3f, $3f, $3f, $3f, $3d
lay_d016:   .byte $08, $18, $08, $08, $08, $08, $08
noise_d018: .byte $08, $18, $48, $58, $08, $18, $48, $58
noise_slots:.byte $c0, $c4, $d0, $d4
pairtab:    .byte $10, $1b, $b0, $c0, $1c, $fb, $cb, $f0
            .byte $10, $0b, $bc, $0c, $0f, $cf, $1f, $1b

wipe_up:    .byte 24,22,20,17,14,11,9,7,5,3,2,1,0
wipe_dn:    .byte 0,1,2,3,5,7,9,11,14,17,20,22,24,26
shake_tab:  .byte $3b,$3b,$3b,$3c,$3a,$3c,$39,$3d
lamp_pat:   .byte 0,0,1,0,1,1,0,1
lamp_data:  .import binary "../build/gen/lamp.bin"
ordtab:     .byte 7,19,2,14,23,5,11,17,0,21,9,3,15,24,6,12,20,1,10,18,4,13,22,8,16

rowline:    .fill 26, 50+8*i

camidx_tab: .fill NUM_CAMS, $10+i
grp_start:  .byte 0,3,5,6,8,9,10
grp_len:    .byte 3,2,1,2,1,1,1
evdoor:     .byte EV_LD, EV_RD

// key matrix: column select / row mask
//             A    S    K    L   SPC   1    2    3    4    5    6    7   CRSR LSH  RSH
kcol:       .byte $fd,$fd,$ef,$df,$7f,$7f,$7f,$fd,$fd,$fb,$fb,$f7,$fe,$fd,$bf
krow:       .byte $04,$20,$20,$04,$10,$01,$08,$01,$08,$01,$08,$01,$04,$80,$10

// sprites: 0 L door ring, 1 L light ring, 2 R door ring, 3 R light ring, 4-7 lit overlays
spr_x:      .byte 90,90,255,255,90,90,255,255
spr_y:      .byte 108,136,108,136,108,136,108,136
spr_col:    .byte 15,15,15,15,2,7,2,7
ptr_office: .byte SPR_PTR+0,SPR_PTR+1,SPR_PTR+2,SPR_PTR+3,SPR_PTR+4,SPR_PTR+5,SPR_PTR+6,SPR_PTR+7
ptr_cam:    .byte SPR_PTR+8,SPR_PTR+8,SPR_PTR+8,SPR_PTR+8,SPR_PTR+8,SPR_PTR+8,SPR_PTR+8,SPR_PTR+8

// patch addressing
sbase_lo:   .byte <PATCHES, <(PATCHES+SIDE_SZ)
sbase_hi:   .byte >PATCHES, >(PATCHES+SIDE_SZ)
voff_lo:    .byte <P_N, <P_L, <P_C, <P_S
voff_hi:    .byte >P_N, >P_L, >P_C, >P_S
// door / window sub-ranges of a record: part = side*2 + window
//              L door  L win  R door  R win
boff:       .byte 0,     56,    32,     0
blen:       .byte 40,    16,    40,     16
soff:       .byte 0,     7,     4,      0
slen:       .byte 5,     2,      5,     2
sadv:       .byte 72,    23,    44,     72
mul81_lo:   .fill 22, <(i*81)
mul81_hi:   .fill 22, >(i*81)
rbl_lo:     .fill 22, <(OFF_BMP + (i+3)*320 + 16)
rbl_hi:     .fill 22, >(OFF_BMP + (i+3)*320 + 16)
rbr_lo:     .fill 22, <(OFF_BMP + (i+3)*320 + 232)
rbr_hi:     .fill 22, >(OFF_BMP + (i+3)*320 + 232)
rsl_lo:     .fill 22, <(OFF_SCR + (i+3)*40 + 2)
rsl_hi:     .fill 22, >(OFF_SCR + (i+3)*40 + 2)
rsr_lo:     .fill 22, <(OFF_SCR + (i+3)*40 + 29)
rsr_hi:     .fill 22, >(OFF_SCR + (i+3)*40 + 29)
