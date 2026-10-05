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
.segmentdef Code3 [start=$ad00, max=$bcff]   // bank 2 after the patches ($8000-$ac4b); $bd00 is the save page, $be40.. holds the fan frames
.segmentdef Code4 [start=$4400, max=$47bf]   // $47c0.. is the subtitle row screen RAM
.file [name="code1.prg", segments="Code1"]
.file [name="code2.prg", segments="Code2"]
.file [name="code3.prg", segments="Code3"]
.file [name="code4.prg", segments="Code4"]

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

#if !TEST
        lda $dc0f               // the CIA1 time-of-day clock times the disclaimer (it runs while the loader works)
        and #$7f                // writes set the clock, not the alarm
        sta $dc0f
        lda #0
        sta $dc0b               // hours: stops the clock
        sta $dc0a
        sta $dc09
        sta $dc08               // tenths: starts it
#endif
        jsr Sparkle_LoadNext    // bundle 1: the disclaimer (hires, bank 3: screen $c000, bitmap $e000 - built over by InitNoise later)
        lda #$3f                // show it: bank 3
        sta $dd02
        lda #$08
        sta $d018
        sta $d016
        lda #$3b
        sta $d011

        jsr Sparkle_LoadNext    // bundle 2: title screen (hires, camera buffer), loads behind the disclaimer
        jsr Sparkle_LoadNext    // bundle 3: office bitmap, patches, sprites
        lda #DI_SAVEFILE        // the save page (the reached night), ApplySave reads it in InitState
        jsr Sparkle_LoadA
        jsr InitState           // (the title's glitch copy loads here; its BuildTables switches the display to the title)
        lda #$3f                // ... so the disclaimer is put back until the title is complete
        sta $dd02
        lda #$08
        sta $d018
        sta $d016
        jsr InitFont
#if !SKIPTITLE
        jsr DrawTitleTxt        // the title texts are drawn now, not by the main loop, so the title is complete when it appears
        lda #0
        sta mjob
        sta mbusy
#endif
#if !TEST
        ldx #0                  // keep the disclaimer up for DISC_SECS seconds in all (the fail-safe loop ends it even if the clock does not run)
        ldy #0
        lda #10
        sta zt
!:      lda $dc09               // seconds (BCD, the clock started at 0)
        cmp #DISC_SECS
        bcs !+
        dex
        bne !-
        dey
        bne !-
        dec zt
        bne !-
!:
#endif
DiscDone:
        jsr BuildTables         // the title screen: bank 1 (InitNoise builds over the disclaimer)
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
        sta $0f00,x
        inx
        bne !-
        lda Sparkle_NTSC_Check  // $dd PAL / $dc NTSC
        ldx #50
        cmp #$dd
        beq !+
        ldx #60
!:      stx g_fps
        lda #1
        sta g_night
        sta g_maxnight
        jsr ApplySave
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
        lda #TEST_NIGHT
        sta g_night
        sta g_maxnight
        jsr NewNight            // test builds start in the office
        lda #TEST_PHONE
        beq !+
        lda g_night
        clc
        adc #DI_PHONE
        jsr ReqLoad
        jsr PhoneStart
!:        lda #TEST_POWER
        sta g_power
        ldx #3                  // optional AI overrides (TEST_AI = 255: keep the night's level)
!:      lda test_ai,x
        cmp #$ff
        beq !+
        sta ai_lvl,x
!:      lda test_pos,x
        cmp #$ff
        beq !+
        sta ai_pos,x
!:      dex
        bpl !---
        lda #3
        sta hud_dirty
        lda #1
        sta g_act
        lda #M_OFFICE
        sta mode
        lda #1
        sta sprmode
        lda #LAY_OFFICE
#else
        lda #DI_TITLEH          // the title's glitch copy replaces the office picture while the title is up
        jsr Sparkle_LoadA
#if TEST
#if !SAVETEST
        lda #NIGHTS             // every night selectable in test builds (SAVETEST: use what the disk says)
        sta g_maxnight
#endif
#endif
        lda #M_TITLE
        sta mode
        lda #0
        sta sprmode
        lda #J_TITLETXT
        sta mjob
        lda #1
        sta mbusy
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
        // the REC indicator is the only sprite (camera views); every slot points at it
        ldx #7
        lda #SPR_PTR
!:      sta $07f8,x
        sta CAM_SCR+$3f8,x
        sta NZ_SCR0+$3f8,x
        sta $c400+$3f8,x
        sta $cc00+$3f8,x
        dex
        bpl !-
        ldx #$34
        stx $01
        ldx #7
!:      sta $d000+$3f8,x
        sta $d400+$3f8,x
        sta $d800+$3f8,x
        sta $dc00+$3f8,x
        dex
        bpl !-
        ldx #$35
        stx $01
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
        jsr PauseLogic          // P: freeze the game (the display keeps running)
        bne it_paused
        jsr StateMachine
        jsr GameTick
        jsr PhoneTick
it_paused:
        jsr SubOverlay
        jsr BuildTables
        jsr SpriteUpdate
        jsr ShakeUpdate
        jsr LampUpdate
        lda g_pause
        bne !+
        jsr SndTick
!:      lda chain_on
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
        lda kd_now
        sta kd_prev
        lda kc_now
        sta kc_prev
        ldx #15
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
        ldx #3                  // left arrow, 8, 9, 0
si2:    lda kcol2,x
        sta $dc00
        lda $dc01
        and krow2,x
        beq si_p2
        lda #0
        beq si_s2
si_p2:  lda #1
si_s2:  sta keyraw2,x
        dex
        bpl si2
        lda #$df                // P: pause (column 5, row 1)
        sta $dc00
        lda $dc01
        and #$02
        eor #$02
        sta p_key
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
        ldx keyraw+15           // M: mute the phone call
        beq !+
        ora #KA_MUTE
!:      sta ka_now
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
        // --- left arrow, 8, 9, 0 -> kd bits 0..3
        lda #0
        ldx #3
!:      asl
        ldy keyraw2,x
        beq !+
        ora #1
!:      dex
        bpl !--
        sta kd_now
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
        and #KA_MUTE
        beq !+
        lda #EV_MUTE
        sta ev
!:      lda zt
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
        rts
ev_nodigit:
        lda kd_prev             // left arrow, 8, 9, 0 -> evdigit 11, 8, 9, 10
        eor #$ff
        and kd_now
        beq ev_ret
        ldx #0
!:      lsr
        bcs !+
        inx
        bne !-
!:      lda kd_codes,x
        sta evdigit
ev_ret: rts

//==============================================================================
// Game state machine (runs in the frame tick)
//==============================================================================
StateMachine:
        jsr Events
        lda forcedown           // Bonnie / Chica pull the monitor down
        beq !+
        lda ev
        ora #EV_CAM
        sta ev
!:      jsr DoorLogic
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
!:      cmp #M_CARD
        bne !+
        jmp sm_card
!:      cmp #M_POWER
        bne !+
        jmp sm_power
!:      cmp #M_SCARE
        bne !+
        jmp sm_scare
!:      cmp #M_OVER
        bne !+
        jmp sm_over
!:      cmp #M_WIN
        bne !+
        jmp sm_win
!:      cmp #M_NEWS
        bne !+
        jmp sm_news
!:      jmp sm_totitle

// ---- title screen ----
sm_title:
        lda #0
        sta sprmode
        lda #LAY_TITLE
        jsr SetAll
        jsr TitleGlitch
        lda evdigit             // 1..7 choose an unlocked night
        beq st_nodig
        cmp g_night
        beq st_nodig
        cmp #NIGHTS+1
        bcs st_nodig
        cmp g_maxnight
        beq st_dig
        bcs st_nodig
st_dig: sta g_night
        lda #1
        sta mbusy
        lda #J_TITLETXT
        sta mjob
st_nodig:
        lda ev
        and #EV_CAM
        beq !+
        lda mbusy               // title text still being drawn
        bne !+
        ldx #M_CARD
        lda g_night
        cmp #1
        bne st_go
        ldx #M_NEWS             // the first night starts with the newspaper
st_go:  stx mode
        lda #0
        sta tph
        sta tcnt
        lda #SFX_STATIC
        jsr SndStart
!:      rts

// ---- night card: static, "12:00 AM / 1ST NIGHT" while the office assets load, dissolve into the office
sm_card:
        lda #0
        sta sprmode
        lda tph
        bne cd_p1
        lda #LAY_NOISE
        jsr SetAll
        lda tcnt
        bne cd_0b
        jsr NewNight
        lda #0
        sta ph_loaded
        lda #CARD_NIGHT
        jsr ReqCard
cd_0b:  inc tcnt
        lda tcnt
        cmp #8
        bcc cd_ret
        lda mbusy
        bne cd_ret
        lda #1
        sta tph
        lda #0
        sta tcnt
        lda #DI_OFFICE
        jmp ReqLoad
cd_p1:  cmp #1
        bne cd_p2
        lda #LAY_TITLE
        jsr SetAll
        lda tcnt
        cmp #150
        bcs !+
        inc tcnt
!:      lda ph_loaded           // once the office is in, fetch tonight's call text
        bne cd_pl
        lda tcnt
        cmp #8
        bcc cd_ret
        lda mbusy
        bne cd_ret
        lda #1
        sta ph_loaded
        lda g_night
        cmp #6
        bcs cd_pl
        clc
        adc #DI_PHONE
        jmp ReqLoad
cd_pl:  lda tcnt
        cmp #150
        bcc cd_ret
        lda mbusy
        bne cd_ret
        lda #2
        sta tph
        lda #0
        sta tcnt
        lda #3
        sta hud_dirty
        lda #1                  // the night starts: clock, power and animatronics run
        sta g_act
        jmp PhoneStart
cd_p2:  lda #LAY_OFFICE
        sta revlay
        jsr RevealRows
        inc tcnt
        lda tcnt
        cmp #9
        bcc cd_ret
        lda #M_OFFICE
        sta mode
cd_ret: rts

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
        inc fmark
        jsr WantFrame
        lda ai_pos+1            // Bonnie / Chica inside: they kill once the monitor is lowered
        cmp #12
        beq so_arm
        lda ai_pos+2
        cmp #12
        bne so_flip
so_arm: lda #1
        sta g_pkill
        jsr Random
        and #$3f
        clc
        adc #30
        sta g_pull
        lda #0
        sta groan_tm
so_flip:
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
        cpy fwant
        bne !+
        lda #LAY_CAM            // cached feed rises with the monitor
!:      sta wlow
        lda wipe_up,x
        jsr WipeRows
        inc tcnt
        rts
up_next:
        lda cam_loaded
        cmp fwant
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
        cmp fwant
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
        sta forcedown
        jsr Random              // Foxy is frozen for 0.8 - 16.7 s after the monitor goes down
        and #$7f
        clc
        adc #8
        sta fx_frz
        lda #SFX_FLIP
        jsr SndStart
        lda #LAY_CAM
        jmp SetAll
sc_nocam:
        // camera selection
        lda cam_cur
        sta zt2
        lda evdigit             // 1-9, 10 (0 key), 11 (left arrow) select the camera directly
        beq sc_nodig
        cmp #11
        bcc sc_set
        lda #0                  // left arrow: camera 0 (show stage)
        beq sc_set
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
        inc fmark
        jsr WantFrame
        jmp BeginSwitch
sc_stay:
        lda camdirty            // an animatronic moved: does this camera show something new?
        beq sc_nodirty
        lda #0
        sta camdirty
        lda fwant
        pha
        jsr WantFrame
        pla
        cmp fwant
        beq sc_nodirty
        jmp BeginSwitch
sc_nodirty:
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
        jsr Random              // 2 or 3 frames long
        and #1
        clc
        adc #2
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

BeginSwitch:
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
        cmp fwant
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
        jsr SetAll
        lda g_pkill             // Bonnie / Chica were waiting for this
        beq dn_ret
        lda ai_pos+1
        cmp #12
        beq dn_b
        lda #2
        jmp StartScare
dn_b:   lda #1
        jmp StartScare
dn_ret: rts

//------------------------------------------------------------------------------
// Requests to the main loop (it owns the loader)
//------------------------------------------------------------------------------
ReqLoad:                        // A = directory index of the bundle
        sta marg
        lda #J_LOAD
        bne rq_go
ReqCard:                        // A = card type
        sta marg
        lda #J_CARD
rq_go:  ldx #1
        stx mbusy
        sta mjob
        rts

.segment Code3                  // (Code1 and Code2 are nearly full)
// ---- power outage ----
// stage 0 the lit office stays up (the closed doors open, the lights go out) while the dark office loads into the camera buffer
// (with the monitor up: static instead), 1 dissolve to the dark office, 2 darkness (footsteps; Freddy's picture loads into the
// office buffer), 5 Freddy in the doorway (music box, the face blinks: his picture and the dark office alternate), 6 blackout
// (the scare pictures load), then the scare.  tph: 0 office shown, 1 monitor up (stages 0-2)
sm_power:
        lda #0
        sta sprmode
        lda ps_stage
        bne pw_p1
        lda #LAY_OFFICE
        ldx tph
        beq pw_0s
        lda #LAY_NOISE
pw_0s:  jsr SetAll
        lda tcnt
        bne pw_0b
        lda #DI_DARK
        jsr ReqLoad
pw_0b:  lda tcnt
        cmp #10
        bcs pw_0c
        inc tcnt
pw_0c:  lda tph
        bne pw_0w
        lda pw_irq
        beq pw_0w
        jsr PwDraw
pw_0w:  lda tcnt
        cmp #10
        bcc pw_ret
        lda mbusy
        bne pw_ret
        lda dedge               // the doors are open and everything is drawn
        ora dedge+1
        ora ddrawn
        ora ddrawn+1
        ora wdrawn
        ora wdrawn+1
        ora ldrawn
        ora ldrawn+1
        ora bdrawn
        bne pw_ret
        lda #1
        sta ps_stage
        lda #0
        sta tcnt
pw_ret: rts
pw_p1:  cmp #1
        bne pw_p2
        lda #LAY_TITLE
        sta revlay
        jsr RevealRows
        lda tph
        bne pw_1n
        ldx #24                 // the rows that did not dissolve yet show the office, not static
pw_1l:  lda rowlayer,x
        cmp #LAY_NOISE
        bne !+
        lda #LAY_OFFICE
        sta rowlayer,x
!:      dex
        bpl pw_1l
pw_1n:  inc tcnt
        lda tcnt
        cmp #9
        bcc pw_ret
        lda #2
        sta ps_stage
        lda #0
        sta tcnt
        jsr Random              // 1 - 14 s of darkness
        and #$7f
        clc
        adc #10
        sta ps_tm
        rts
pw_p2:  cmp #2
        bne pw_p5
        lda #LAY_TITLE
        jsr SetAll
        lda tcnt
        bne pw_2b
        inc tcnt
        lda #DI_DARKF           // the office buffer is hidden now: Freddy's picture loads into it
        jsr ReqLoad
pw_2b:  jsr PowerSteps
        lda ps_tm
        bne pw_ret
        lda mbusy               // (the picture is loaded long before, unless the darkness was very short)
        bne pw_ret
        lda #5
        sta ps_stage
        lda #0
        sta blank
        lda #LAY_OFFICE         // Freddy's picture is in the office buffer: it simply appears
        jsr SetAll
        lda #MEL_BOX            // Freddy's music box
        jsr MelStart
        jmp PickTime
pw_r2:  rts
pw_p5:  cmp #5
        bne pw_p6
        jsr Random              // eyes flicker: now and then the picture switches back to the dark office (camera buffer)
        cmp #60
        lda #LAY_OFFICE
        bcs pw_5s
        lda #LAY_TITLE
pw_5s:  jsr SetAll
        lda ps_tm
        bne pw_r2
        lda #6
        sta ps_stage
        lda #1
        sta blank
        lda #0
        sta tph                 // pictures requested so far
        jsr MelStop
        jmp PickTime
pw_p6:  lda #1
        sta blank               // the display stays black until the scare shows the first picture
        jsr PowerSteps
        lda mbusy               // the two Freddy pictures load at once, during the darkness
        bne pw_p6w
        lda tph
        cmp #2
        bcs pw_p6w
        clc
        adc #DI_JS              // Freddy: bundles DI_JS (frame 0, camera buffer) and DI_JS+1 (frame 1, office buffer)
        inc tph
        jsr ReqLoad
        rts
pw_p6w: lda ps_tm
        bne pw_r2
        lda mbusy
        bne pw_r2
        lda tph
        cmp #2
        bcc pw_r2               // the timer is out, but the pictures are not both loaded yet
        lda #0
        jsr StartScare          // A = 0: Freddy
        lda #1
        sta sc_pre              // no loading, the pictures flip at once
        rts

PickTime:                       // 5, 10, 15 or 20 s
        jsr Random
        and #3
        tax
        lda ptime_tab,x
        sta ps_tm
        rts

PowerSteps:
        jsr Random
        cmp #3
        bcs !+
        lda #SFX_STEP
        jmp SndStart
!:      rts

// Called by the frame tick in stage 0 (the main loop is inside the loader then): the door, light and button drawing of the
// main loop. The main loop's temporaries are saved around it.
PwDraw:
        ldx #8
!:      lda zsrc,x              // zsrc .. zrow
        pha
        dex
        bpl !-
        lda mt
        pha
        lda mt2
        pha
        lda zwin
        pha
        ldx #0
        jsr DoorStep
        ldx #1
        jsr DoorStep
        ldx #0
        jsr LightRender
        ldx #1
        jsr LightRender
        jsr ButtonRender
        pla
        sta zwin
        pla
        sta mt2
        pla
        sta mt
        ldx #0
!:      pla
        sta zsrc,x
        inx
        cpx #9
        bne !-
        rts

// ---- jumpscare. Frame 0 loads into the camera buffer while the office stays on screen (a power-out blackout stays black).
// Then frame 0 is shown (the scream starts) while frame 1 loads into the office buffer; the two pictures then flip every 5 frames
// (0.1 s) for 10 flips (1 s), all the time shaking, and it cuts to static. Nothing loads between the flips.
// Foxy is different: his bundle holds 2.png (camera buffer), his sprite and the code that moves it (src/foxy.asm). The office stays up,
// the sprite runs in through the left door (phases 7-8), then the picture switches once to 2.png (phase 9) and shakes on.
sm_scare:
        lda #0
        sta sprmode
        lda sc_ph
        cmp #4
        bne !+
        jmp sx_p4
!:      cmp #7
        bcc !+
        jmp FoxyScare           // Foxy: phases 7-9 are in src/foxy.asm (they come with his bundle)
!:      cmp #5
        bne !+
        jmp sn_flip
!:      cmp #6
        beq sn_load2
        lda sc_pre
        beq sn_ph0
        lda #0                  // power-out death: both pictures are in memory already (the display is still black)
        sta sc_pre
        sta tcnt
        sta tph
        lda #5
        sta sc_ph
        jmp SndScream
sn_ph0: lda #LAY_OFFICE         // phase 0: frame 0 loads, the office stays up (fan and lamp keep going)
        jsr SetAll
        jsr FanIrq
        lda tcnt
        bne sn_0b
        lda g_who
        asl
        clc
        adc #DI_JS
        jsr ReqLoad
sn_0b:  inc tcnt
        lda tcnt
        cmp #4
        bcc sn_ret
        lda mbusy
        bne sn_ret
        lda #6
        sta sc_ph
        lda #0
        sta tcnt
        lda g_who
        cmp #3
        bne sn_scr
        lda #7                  // Foxy: his sprite runs in over the office first (the scream starts with it)
        sta sc_ph
        rts
sn_scr: jmp SndScream           // the first picture appears: scream
sn_ret: rts
sn_load2:                       // phase 6: frame 0 is shown (shaking) while frame 1 loads into the office buffer
        lda #0
        sta blank               // display on (a power-out blackout ends here)
        lda #LAY_TITLE
        jsr ScareJolt
        lda tcnt
        bne sn_2b
        lda g_who
        asl
        clc
        adc #DI_JS+1
        jsr ReqLoad
sn_2b:  inc tcnt
        lda tcnt
        cmp #4
        bcc sn_ret
        lda mbusy
        bne sn_ret
        lda #5
        sta sc_ph
        lda #0
        sta tcnt
        sta tph                 // flips done
        rts
sn_flip:
        lda tph
        and #1
        tax
        lda js_flip,x
        jsr ScareJolt
        inc tcnt
        lda tcnt
        cmp #5
        bcc sn_ret
        lda #0
        sta tcnt
        inc tph
        lda tph
        cmp #10
        bcc sn_ret
        lda #4
        sta sc_ph
        lda #0
        sta tcnt
        rts
sx_p4:  lda #0
        sta jshake
        sta blank               // the static is never black
        lda #LAY_NOISE
        jsr SetAll
        inc tcnt
        lda tcnt
        cmp #12
        bcc sn_ret
        jsr ScreamCut           // the scream ends with the animation
        lda #M_OVER
        sta mode
        lda #0
        sta tph
        sta tcnt
        rts

ScareJolt:                      // A = layer for every row, shifted sideways by a random 0-7 pixels; ShakeUpdate adds the vertical shake
        jsr SetAll              // (also at random a black frame: display off, black border)
        lda #1
        sta jshake
        jsr Random
        cmp #44                 // 44/256: about 1 frame in 6 is black
        lda #0
        rol
        eor #1                  // C set (>= 44) -> 0, else 1
        sta blank
        jsr Random
        and #7
        ldx #24
!:      sta rowxs,x
        dex
        bpl !-
        rts

.segment Code2
TitleGlitch:                    // per row: Freddy's head shaken sideways (the row shows the shifted title copy) and static blips
        ldx #24
tg_lp:  jsr Random
        and #1
        beq !+
        lda #LAY_OFFICE         // the shifted title copy sits in the office buffer
        sta rowlayer,x
!:      jsr Random
        cmp #14
        bcs tg_nx
        lda #LAY_NOISE
        sta rowlayer,x
        lda #0
        sta rowxs,x
tg_nx:  dex
        bpl tg_lp
        rts

// ---- game over card
sm_over:
        lda #0
        sta sprmode
        lda tph
        bne ov_p1
        lda #LAY_NOISE
        jsr SetAll
        lda tcnt
        bne ov_0b
        lda #CARD_OVER
        jsr ReqCard
ov_0b:  inc tcnt
        lda tcnt
        cmp #8
        bcc ov_ret
        lda mbusy
        bne ov_ret
        lda #1
        sta tph
        lda #0
        sta tcnt
ov_ret: rts
ov_p1:  lda #LAY_TITLE
        jsr SetAll
        inc tcnt
        lda tcnt
        cmp #150
        bcc ov_ret
        jmp GoTitle

// ---- newspaper before night 1: static while it loads, then it stays up for 5 s (SPACE skips it after 1.2 s)
sm_news:
        lda #0
        sta sprmode
        lda tph
        bne nw_p1
        lda #LAY_NOISE
        jsr SetAll
        lda tcnt
        bne nw_0b
        lda #DI_NEWS
        jsr ReqLoad
nw_0b:  inc tcnt
        lda tcnt
        cmp #8
        bcc nw_ret
        lda mbusy
        bne nw_ret
        lda #1
        sta tph
        lda #0
        sta tcnt
nw_ret: rts
nw_p1:  lda #LAY_TITLE
        jsr SetAll
        lda tcnt
        cmp #250
        bcs nw_go
        inc tcnt
        cmp #60
        bcc nw_ret
        lda ev
        and #EV_CAM
        beq nw_ret
nw_go:  lda #M_CARD
        sta mode
        lda #0
        sta tph
        sta tcnt
        lda #SFX_STATIC
        jmp SndStart

.segment Code1

// ---- 6 AM: "5 AM" -> "6 AM" (chime), on night 5 the newspaper, after night 6 the ending
// tph: 0 static + 5 AM, 1 show, 2 static + 6 AM, 3 show, 4 static + newspaper, 5 show,
//      6 static + ending card, 7 show
sm_win:
        lda #0
        sta sprmode
        lda tph
        cmp #8
        beq wn_roll
        cmp #1
        beq wn_show
        cmp #3
        beq wn_show
        cmp #5
        beq wn_show
        cmp #7
        beq wn_show
        // static phases: load / draw the next card, then show it
        lda #LAY_NOISE
        jsr SetAll
        lda tcnt
        bne wn_sb
        ldx tph
        lda wn_kind,x
        bmi wn_news
        jsr ReqCard
        jmp wn_sb
wn_news:
        lda #DI_NEWS
        jsr ReqLoad
wn_sb:  inc tcnt
        lda tcnt
        cmp #8
        bcc wn_ret
        lda mbusy
        bne wn_ret
        inc tph
        lda #0
        sta tcnt
wn_ret: rts
wn_roll:
        lda #LAY_TITLE
        jsr SetAll
        lda tcnt
        lsr
        tax
        lda roll_tab,x
        sta roll_off
        inc tcnt
        lda tcnt
        cmp #40
        bcc wn_ret
        lda #3                  // the 6 is in place: ring the bell
        sta tph
        lda #0
        sta tcnt
        lda #MEL_CHIME
        jmp MelStart
wn_show:
        lda #LAY_TITLE
        jsr SetAll
        lda tcnt
        cmp #250
        bcs !+
        inc tcnt
!:      ldx tph
        lda tcnt
        cmp wn_time,x
        bcc wn_ret
        // this card is done: which one comes next?
        lda tph
        cmp #1
        beq wn_next
        cmp #3
        beq wn_after6
        jmp wn_finish           // newspaper or ending card done
wn_next:
        lda #8                  // the 5 rolls up and out, the 6 rolls in
        sta tph
        lda #0
        sta tcnt
        lda #SFX_FLIP
        jmp SndStart
wn_after6:
        lda g_night
        cmp #5
        bne wn_n5
        lda #4                  // newspaper after night 5
        sta tph
        lda #0
        sta tcnt
        rts
wn_n5:  cmp #6
        bne wn_finish
        lda #6                  // ending card after night 6
        sta tph
        lda #0
        sta tcnt
        rts
wn_finish:
        jsr AdvanceNight
        jmp GoTitle

.segment Code2                  // (Code1 is nearly full)
AdvanceNight:                   // nights 1-5: the next one; night 6 unlocks night 7 (the custom night); back to 1
        lda g_maxnight
        pha
        lda g_night
        cmp #6
        bcc an_inc
        bne an_one
        lda #NIGHTS
        sta g_maxnight
an_one: lda #1
        sta g_night
        jmp an_chk
an_inc: inc g_night
        lda g_night
        cmp g_maxnight
        bcc an_chk
        beq an_chk
        sta g_maxnight
an_chk: pla
        cmp g_maxnight
        beq an_ret              // nothing new reached: no need to write the disk
        lda #1
        sta g_savereq
an_ret: rts
.segment Code1

.segment Code4
// card / bundle kind per static phase: card type, or $80 = newspaper
wn_kind:    .byte CARD_5AM, 0, 0, 0, $80, 0, CARD_END, 0
roll_tab:   .byte 0,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,16,16
wn_time:    .byte 0, 70, 0, 220, 0, 200, 0, 250

.segment Code1

// ---- back to the title screen
GoTitle:
        jsr MelStop
        lda #M_TOTITLE
        sta mode
        lda #0
        sta tph
        sta tcnt
        sta lamp_cur            // the lamp's colour cells belong to the office picture: LampUpdate must not redraw them over the title's glitch copy
        rts

sm_totitle:
        lda #0
        sta sprmode
        lda tph
        bne tt_p1
        lda #LAY_NOISE
        jsr SetAll
        lda tcnt
        bne tt_0b
        lda #DI_TITLE
        jsr ReqLoad
tt_0b:  inc tcnt
        lda tcnt
        cmp #8
        bcc tt_ret
        lda mbusy
        bne tt_ret
        lda #1
        sta tph
        lda #0
        sta tcnt
        jsr FanOn               // (silent after a power-out death until now)
tt_ret: rts
tt_p1:  lda #LAY_TITLE
        sta revlay
        jsr RevealRows
        inc tcnt
        lda tcnt
        cmp #9
        bcc tt_ret
        lda #M_TITLE
        sta mode
        rts

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
        lda rowxs,x             // (all rows equal: one set of registers, also with a sideways shift)
        cmp rowxs
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
        lda ai_pos+1,x          // Bonnie / Chica inside: the door is jammed
        cmp #12
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
        ldy ai_pos+1,x          // dead while the animatronic is inside
        cpy #12
        beq ll_set
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
        ldy adoor,x
        beq ll_set
        lda a_seen,x            // Bonnie / Chica stand in the light
        bne ll_4
        lda #1
        sta a_seen,x
        stx ztx
        lda #SFX_STING
        jsr SndStart
        ldx ztx
ll_4:   lda #4
ll_set: sta lwant,x
        bne ll_nx
        sta a_seen,x
ll_nx:  dex
        bpl ll_lp
        lda lwant               // only one light at a time
        beq ll_ret
        lda lwant+1
        beq ll_ret
        lda #0
        sta lwant+1
        sta a_seen+1
ll_ret: rts

//------------------------------------------------------------------------------
// Sprites (frame tick)
//------------------------------------------------------------------------------
SpriteUpdate:
        lda sprmode
        cmp #2
        beq spr_cam
        lda #0                  // no sprites in the office: its buttons are part of the picture
        sta $d015
        rts
spr_cam:
        lda #38                 // REC indicator (x = 294 -> MSB set)
        sta $d000
        lda #66                 // (picture y 16, right below the clock)
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
        ldx jshake
        beq su_nj
        ldx chain_on
        bne su_nj
        jsr Random              // jumpscare: vertical scroll 0-7
        and #7
        ora #$38
su_nj:  ldx blank
        beq !+
        lda #$2b                // display off (power outage darkness)
!:      sta $d011
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
LampDrawDark:
        :LampCopy(lamp_data + 60)
        rts

LampUpdate:
        lda mode
        cmp #M_SCARE
        bne lu_nsc
        lda sc_ph               // the office stays up while jumpscare frame 0 loads: the lamp keeps flickering
        ora blank
        beq lu_office
        rts
lu_nsc: cmp #M_CARD
        bcs lu_ret
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
        lda #16
        sta lamp_cnt
        jsr Random
        and #$3f
        clc
        adc #40
        sta lamp_wait
        lda #0
lu_apply:
        cmp lamp_cur
        beq lu_ret
        sta lamp_cur
        tax
        bne lu_dim
        jmp LampDrawNorm
lu_dim: cmp #1
        bne lu_dark
        jmp LampDrawDim
lu_dark:
        jmp LampDrawDark
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
        lda mode                // the office buffer holds jumpscare frame 1 / the shifted title: no door, light and button drawing
        cmp #M_SCARE
        beq mw_fx
        cmp #M_TITLE
        beq mw_scare
        cmp #M_OVER
        beq mw_scare
        cmp #M_TOTITLE
        beq mw_scare
        cmp #M_POWER
        bne mw_doors
        lda ps_stage            // blackout: the office buffer receives jumpscare frame 1
        cmp #6
        beq mw_scare
        lda ps_stage            // stage 0 with the office shown: the main loop sits in the loader, so the frame tick draws the doors
        bne mw_doors
        lda tph
        bne mw_doors
        lda #1
        sta pw_irq
        jmp mw_scare
mw_doors:
        ldx #0
        jsr DoorStep
        ldx #1
        jsr DoorStep
        ldx #0
        jsr LightRender
        ldx #1
        jsr LightRender
        jsr ButtonRender
mw_scare:
        jsr FanStep
        jsr RollStep
        jsr SubDraw
        jsr FoxyRunStep
        jsr MainJobs
        jsr HudRefresh
        jsr CamCheck
        jmp Main
mw_fx:  lda sc_ph               // Foxy's sprite is drawn by the main loop
        cmp #7
        bcc mw_scare
        jsr FoxyMain
        jmp mw_scare

//------------------------------------------------------------------------------
// Jobs requested by the frame tick (bundle loads and text cards)
//------------------------------------------------------------------------------
MainJobs:
        lda mjob
        beq mj_ret
        ldx #0
        stx mjob
        cmp #J_LOAD
        beq mj_load
        cmp #J_CARD
        beq mj_card
        jsr DrawTitleTxt        // J_TITLETXT: "NIGHT n" on the title picture
        jmp mj_done
mj_card:
        lda marg
        jsr DrawCard
        jmp mj_done
mj_load:
        lda marg
        sta mt
        lda g_savereq
        beq !+
        jsr DoSave              // a night was beaten: write it to the disk first
!:
#if TEST
        jsr LoadStartHook
#endif
        lda mt
        jsr Sparkle_LoadA
#if TEST
        jsr LoadEndHook
#endif
        lda #$ff
        sta cam_loaded          // the camera buffer no longer holds a camera picture
        lda mt
        cmp #DI_OFFICE
        bne !+
        lda #3
        sta hud_dirty           // fresh office bitmap: HUD needs drawing
!:      cmp #DI_TITLE
        bne mj_done
        lda #DI_TITLEH          // the shifted copy for the glitch (office buffer), then the texts into both pictures
        jsr Sparkle_LoadA
        jsr DrawTitleTxt
mj_done:
        lda #0
        sta mbusy
mj_ret: rts

//------------------------------------------------------------------------------
// Desk fan: redraw its 21 cells from one of four prepared frames every third frame
// (frame data: per row segment the bitmap bytes followed by the screen bytes)
//------------------------------------------------------------------------------
FanStep:
        lda mode
        beq fs_go
        cmp #M_UP
        beq fs_go
        cmp #M_DOWN
        bne fs_ret
fs_go:  dec fan_tm
        bpl fs_ret
        lda #2
        sta fan_tm
        lda fan_i
        clc
        adc #1
        and #3
        sta fan_i
        tax
        lda fan_lo,x
        sta zsrc
        lda fan_hi,x
        sta zsrc+1
        ldx #0
fs_row: lda fan_bl,x
        sta zdb
        lda fan_bh,x
        sta zdb+1
        lda fan_sl,x
        sta zds
        lda fan_sh,x
        sta zds+1
        ldy fan_n8,x
        dey
!:      lda (zsrc),y
        sta (zdb),y
        dey
        bpl !-
        clc
        lda zsrc
        adc fan_n8,x
        sta zsrc
        bcc !+
        inc zsrc+1
!:      ldy fan_n1,x
        dey
!:      lda (zsrc),y
        sta (zds),y
        dey
        bpl !-
        clc
        lda zsrc
        adc fan_n1,x
        sta zsrc
        bcc !+
        inc zsrc+1
!:      inx
        cpx #5
        bne fs_row
fs_ret: rts

FanIrq:                         // one fan step from the frame tick (the main loop is busy loading); the main loop's temporaries are saved
        ldx #5
!:      lda zsrc,x
        pha
        dex
        bpl !-
        jsr fs_go
        ldx #0
!:      pla
        sta zsrc,x
        inx
        cpx #6
        bne !-
        rts

//------------------------------------------------------------------------------
// Load requested camera image when the effects allow it
//------------------------------------------------------------------------------
CamCheck:
        lda can_load
        beq cc_ret
        lda fwant
        cmp cam_loaded
        beq cc_ret
        sta mt2
        tax
#if TEST
        jsr LoadStartHook
#endif
        lda mt2
        clc
        adc #$10                // camera pictures start at directory index $10
        jsr Sparkle_LoadA
#if TEST
        jsr LoadEndHook
#endif
        lda mt2
        sta cam_loaded
        lda hud_dirty
        ora #2                  // the fresh picture has no HUD text yet
        sta hud_dirty
        lda sub_on
        beq cc_ret
        sta sub_req             // ... and lost the subtitle row
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
        cmp #2
        bcs crs_plain
        asl                     // the top two rows: the strip is masked by the slanted door frame (strip_msk)
        ora mt
        ldx zside
        beq !+
        ora #4
!:      tay
        lda msk_lo,y
        sta zsrc
        lda msk_hi,y
        sta zsrc+1
        jmp CopyRecDst
crs_plain:
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
        adc bsrc,x
        sta zsrc
        bcc !+
        inc zsrc+1
!:      clc
        lda zdb
        adc bdst,x
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
        adc ssadv,x
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

// zsrc = side base + variant offset + row*REC_SZ
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
        adc mulrec_lo,y
        sta zsrc
        lda zsrc+1
        adc mulrec_hi,y
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
        // (lvar is a snapshot: the IRQ may change lwant between two reads)
        lda lvar,x
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

//------------------------------------------------------------------------------
// Door / light buttons: part of the office picture, two cells each. Redraw the cells of a button
// whenever its state (closed or closing / light wanted) differs from the drawn one.
//------------------------------------------------------------------------------
ButtonRender:
        lda #0
        ldx dstate
        beq !+
        cpx #DS_OPENING
        beq !+
        ora #1
!:      ldx lwant
        beq !+
        ora #2
!:      ldx dstate+1
        beq !+
        cpx #DS_OPENING
        beq !+
        ora #4
!:      ldx lwant+1
        beq !+
        ora #8
!:      sta zvar                // wanted states
        eor bdrawn
        sta zrow                // buttons to redraw
        beq btn_ret
        lda zvar
        sta bdrawn
        ldx #3
btn_lp:  lda bu_mask,x
        and zrow
        beq btn_nx
        lda bu_mask,x
        and zvar
        beq !+
        lda #BTN_SZ             // lit variant
!:      clc
        adc bu_src_lo,x
        sta zsrc
        lda bu_src_hi,x
        adc #0
        sta zsrc+1
        lda bu_bmp_lo,x
        sta zdb
        lda bu_bmp_hi,x
        sta zdb+1
        lda bu_scr_lo,x
        sta zds
        lda bu_scr_hi,x
        sta zds+1
        ldy #7                  // upper cell
!:      lda (zsrc),y
        sta (zdb),y
        dey
        bpl !-
        clc                     // lower cell: next text row
        lda zdb+1
        adc #1
        sta zdb+1
        lda zdb
        adc #$40
        sta zdb
        bcc !+
        inc zdb+1
!:      clc
        lda zsrc
        adc #8
        sta zsrc
        bcc !+
        inc zsrc+1
!:      ldy #7
!:      lda (zsrc),y
        sta (zdb),y
        dey
        bpl !-
        ldy #8                  // the two screen bytes follow the bitmap cells
        lda (zsrc),y
        ldy #0
        sta (zds),y
        ldy #9
        lda (zsrc),y
        ldy #40
        sta (zds),y
btn_nx:  dex
        bpl btn_lp
btn_ret: rts

// buttons: 0 L door, 1 L light, 2 R door, 3 R light (rows 10 / 13, columns 1 / 38)
bu_mask:    .byte 1, 2, 4, 8
bu_src_lo:  .fill 4, <(BTN_DATA + i*2*BTN_SZ)
bu_src_hi:  .fill 4, >(BTN_DATA + i*2*BTN_SZ)
.var bu_row = List().add(10, 13, 10, 13)
.var bu_col = List().add(1, 1, 38, 38)
bu_bmp_lo:  .fill 4, <(OFF_BMP + (bu_row.get(i)*40 + bu_col.get(i))*8)
bu_bmp_hi:  .fill 4, >(OFF_BMP + (bu_row.get(i)*40 + bu_col.get(i))*8)
bu_scr_lo:  .fill 4, <(OFF_SCR + bu_row.get(i)*40 + bu_col.get(i))
bu_scr_hi:  .fill 4, >(OFF_SCR + bu_row.get(i)*40 + bu_col.get(i))

.import source "game.asm"
.import source "hud.asm"
.import source "phone.asm"

//==============================================================================
.segment Code3
//==============================================================================
.import source "sound.asm"


//------------------------------------------------------------------------------
// Saving: a Sparkle "hi-score file" (one page at SAVE_BUF) holds the reached night.
// Layout: magic, night, night EOR $ff.  A blank disk (all zero) fails the check -> start at night 1.
//------------------------------------------------------------------------------
ApplySave:
        lda SAVE_BUF
        cmp #SAVE_MAGIC
        bne as_ret
        lda SAVE_BUF+1
        eor #$ff
        cmp SAVE_BUF+2
        bne as_ret
        lda SAVE_BUF+1
        beq as_ret
        cmp #NIGHTS+1
        bcs as_ret
        sta g_maxnight
        cmp #NIGHTS             // night 7 open: the next game starts at night 1 (as after beating night 6)
        bcc !+
        lda #1
!:      sta g_night
as_ret: rts

DoSave:
        lda #0
        sta g_savereq
        lda #SAVE_MAGIC
        sta SAVE_BUF
        lda g_maxnight
        sta SAVE_BUF+1
        eor #$ff
        sta SAVE_BUF+2
        lda #DI_SAVER
        jsr Sparkle_LoadA       // drive: enter the saver loop
        lda #>$100
        jmp Sparkle_Save        // overwrite the hi-score file, back to normal loading

//------------------------------------------------------------------------------
// Tables
//------------------------------------------------------------------------------
lay_d018:   .byte $18, $08, $08, $68, $78, $38, $08, $18
lay_dd02:   .byte $3c, $3d, $3f, $3f, $3f, $3f, $3d, $3d
lay_d016:   .byte $08, $18, $08, $08, $08, $08, $08, $08
noise_d018: .byte $08, $18, $48, $58, $08, $18, $48, $58
noise_slots:.byte $c0, $c4, $d0, $d4
pairtab:    .byte $10, $1b, $b0, $c0, $1c, $fb, $cb, $f0
            .byte $10, $0b, $bc, $0c, $0f, $cf, $1f, $1b

wipe_up:    .byte 24,22,20,17,14,11,9,7,5,3,2,1,0
wipe_dn:    .byte 0,1,2,3,5,7,9,11,14,17,20,22,24,26
shake_tab:  .byte $3b,$3b,$3b,$3c,$3a,$3c,$39,$3d
lamp_pat:   .byte 0,2,1,0,2,2,0,1,2,0,2,1,0,2,1,2
lamp_data:  .import binary "../build/gen/lamp.bin"
ordtab:     .byte 7,19,2,14,23,5,11,17,0,21,9,3,15,24,6,12,20,1,10,18,4,13,22,8,16

rowline:    .fill 26, 50+8*i

// fan frames: 189 bytes each, two at $be40 and two at $0a40 (see tools/gen_assets.py)
.var fan_col = List().add(20, 19, 19, 19, 20)
.var fan_cnt = List().add(3, 5, 5, 5, 3)
fan_lo:     .byte <$be40, <($be40+189), <$0a40, <($0a40+189)
fan_hi:     .byte >$be40, >($be40+189), >$0a40, >($0a40+189)
fan_bl:     .fill 5, <(OFF_BMP + (11+i)*320 + fan_col.get(i)*8)
fan_bh:     .fill 5, >(OFF_BMP + (11+i)*320 + fan_col.get(i)*8)
fan_sl:     .fill 5, <(OFF_SCR + (11+i)*40 + fan_col.get(i))
fan_sh:     .fill 5, >(OFF_SCR + (11+i)*40 + fan_col.get(i))
fan_n8:     .fill 5, fan_cnt.get(i)*8
fan_n1:     .fill 5, fan_cnt.get(i)

js_flip:    .byte LAY_TITLE, LAY_OFFICE                       // jumpscare frame 0 (camera buffer) / frame 1 (office buffer), both hires
ptime_tab:  .byte 50, 100, 150, 200
kd_codes:   .byte 11,8,9,10         // key code of the kd bits: 1-9 = the digit, 10 = the 0 key, 11 = left arrow
evdoor:     .byte EV_LD, EV_RD

// key matrix: column select / row mask
//             A    S    K    L   SPC   1    2    3    4    5    6    7   CRSR LSH  RSH
kcol:       .byte $fd,$fd,$ef,$df,$7f,$7f,$7f,$fd,$fd,$fb,$fb,$f7,$fe,$fd,$bf,$ef
krow:       .byte $04,$20,$20,$04,$10,$01,$08,$01,$08,$01,$08,$01,$04,$80,$10,$10
//             <-   8    9    0
kcol2:      .byte $7f,$f7,$ef,$ef
krow2:      .byte $02,$08,$01,$08

// patch addressing
// pre-masked hazard strip records for the top two patch rows: left (row 0: strip 0/1, row 1: strip 0/1), then right
strip_msk:  .import binary "../build/gen/strip_msk.bin"
msk_lo:     .fill 8, <(strip_msk + i*REC_SZ)
msk_hi:     .fill 8, >(strip_msk + i*REC_SZ)
sbase_lo:   .byte <PATCHES, <(PATCHES+SIDE_SZ)
sbase_hi:   .byte >PATCHES, >(PATCHES+SIDE_SZ)
voff_lo:    .byte <P_N, <P_L, <P_C, <P_S, <P_A
voff_hi:    .byte >P_N, >P_L, >P_C, >P_S, >P_A
// door / window sub-ranges of a record: part = side*2 + window
// (source offsets are inside the packed record, destination offsets inside the 9-cell span on screen)
//              L door  L win  R door  R win
bsrc:       .byte 0,     40,    16,     0      // bitmap bytes: offset in the record
bdst:       .byte 0,     56,    32,     0      //               offset from the span's first cell
blen:       .byte 40,    16,    40,     16
ssadv:      .byte 56,    21,    42,     56     // screen bytes: from the start of the bitmap part above
soff:       .byte 0,     7,     4,      0      //               offset from the span's first cell
slen:       .byte 5,     2,      5,     2
mulrec_lo:  .fill 22, <(i*REC_SZ)
mulrec_hi:  .fill 22, >(i*REC_SZ)
rbl_lo:     .fill 22, <(OFF_BMP + (i+3)*320 + 16)
rbl_hi:     .fill 22, >(OFF_BMP + (i+3)*320 + 16)
rbr_lo:     .fill 22, <(OFF_BMP + (i+3)*320 + 232)
rbr_hi:     .fill 22, >(OFF_BMP + (i+3)*320 + 232)
rsl_lo:     .fill 22, <(OFF_SCR + (i+3)*40 + 2)
rsl_hi:     .fill 22, >(OFF_SCR + (i+3)*40 + 2)
rsr_lo:     .fill 22, <(OFF_SCR + (i+3)*40 + 29)
rsr_hi:     .fill 22, >(OFF_SCR + (i+3)*40 + 29)

.import source "pause.asm"
.segment Code1                  // (Code3 has no room for the test harness any more)
.import source "foxyrun.asm"
.segment Code3

//------------------------------------------------------------------------------
// Test harness (test builds only): key script + snapshot hooks. Lives in the spare segment so that
// long scenario scripts never compete with the game for room.
//------------------------------------------------------------------------------
#if TEST
.import source "test.asm"
#endif

//==============================================================================
// Foxy's jumpscare: its own file (foxy.prg), loaded with his bundle into the door patch area
//==============================================================================
.segmentdef Foxy [start=FX_CODE, max=$9fff]
.file [name="foxy.prg", segments="Foxy"]
.segment Foxy
.import source "foxy.asm"
