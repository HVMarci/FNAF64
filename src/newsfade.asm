//==============================================================================
// Fade in / out of the newspaper, the text cards (night card, 5 AM / 6 AM) and the disclaimer. All pictures are hires bitmaps, so they fade
// through their colour cells (screen RAM $4000) along the grey ramp white > light grey > grey > dark grey > black, level 0..4
// (4 = black). A fade lasts 5 levels * NF_STEP frames. The state machine runs in the frame tick, so only cheap work happens there.
//==============================================================================

// ---- frame tick helpers: fade level (0..4) from the frame counter tcnt
FadeInLvl:                      // the first frames of a picture: 4 .. 0
        lda tcnt
        lsr
        lsr
        lsr
        jmp nf_lv
FadeOutLvl:                     // A = frame at which the picture is gone: 0 .. 4 over its last frames
        sec
        sbc tcnt
        lsr
        lsr
        lsr
nf_lv:  cmp #5                  // frames / 8 -> level (4 .. 0), 0 once past the fade
        bcs nf_z
        eor #$ff
        sec
        adc #4
        rts
nf_z:   lda #0
        rts

// 6 AM sequence, shown phase tph: 1 = 5 AM fades in, 3 = 6 AM fades out, 5 = newspaper both
WinFade:
        ldx tph
        cpx #1
        beq CardFadeIn
        lda wn_time,x
        cpx #3
        beq CardFadeOut
        cpx #5
        bne !+
        jmp NewsFade
!:      rts

// 6 AM sequence, end of a static phase: C set = not ready yet
WinPrep:
        ldx tph
        lda wn_kind,x
        bmi NewsPrep
        cmp #CARD_5AM
        bne wp_ok
        lda #4
        jsr CardFade
wp_ok:  clc
        rts

// ---- text cards: the whole screen RAM is one colour (white / grey / ... on black)
CardFadeIn:
        jsr FadeInLvl
        jmp cf_chk
CardFadeOut:                    // A = frame at which the card is gone
        jsr FadeOutLvl
cf_chk: cmp nf_cur
        bne CardFade
        rts
CardFade:                       // A = level
        sta nf_cur
        tax
        lda cf_col,x
        ldx #0
!:      sta CAM_SCR,x
        sta CAM_SCR+$100,x
        sta CAM_SCR+$200,x
        inx
        bne !-
        ldx #231
!:      sta CAM_SCR+$300,x
        dex
        cpx #$ff
        bne !-
        rts
cf_col: .byte $10, $f0, $c0, $b0, $00

// night card phase 3: fade out, then phase 2 (the dissolve into the office)
CardOutPhase:
        lda #LAY_TITLE
        jsr SetAll
        inc tcnt
        lda tcnt
        lsr
        lsr
        lsr
        cmp #5
        bcc !+
        lda #4
!:      cmp nf_cur
        beq !+
        jsr CardFade
!:      lda tcnt
        cmp #5*NF_STEP
        bcc !+
        lda #2
        sta tph
        lda #0
        sta tcnt
!:      rts

// ---- newspaper: the picture is big, so the main loop does the work (jobs J_NFINIT / J_NFADE)
NewsPrep:                       // the picture is loaded: start black first. C set = the main loop is still on it
        lda nf_cur
        bpl wp_ok
        lda #J_NFINIT
        sta mjob
        lda #1
        sta mbusy
        sec
        rts

NewsFade:                       // frame tick, A = frame at which the newspaper is gone: fade in and out
        jsr FadeOutLvl
        pha
        jsr FadeInLvl
        tsx
        cmp $0101,x
        bcs !+
        lda $0101,x
!:      tay
        pla
        tya
        cmp nf_cur
        beq !+
        sta nf_cur
        sta marg
        lda #J_NFADE
        sta mjob
        lda #1
        sta mbusy
!:      rts

// main loop. The original colour cells are kept in a copy at $0400 (the office buffer is not needed while the newspaper is up;
// the next night / title loads it again).
NewsFadeInit:                   // copy the colours, the picture starts black
        ldx #0
nfi_l:  lda $4000,x
        sta $0400,x
        lda $4100,x
        sta $0500,x
        lda $4200,x
        sta $0600,x
        cpx #232
        bcs !+
        lda $4300,x
        sta $0700,x
!:      inx
        bne nfi_l
        lda #4
NewsFadeSet:                    // A = level: the copy's colours stepped down `level` times
        sta nf_cur
        jsr NfTables
        :NfPage(0, 0)
        :NfPage(1, 0)
        :NfPage(2, 0)
        :NfPage(3, 232)
        rts

NfTables:                       // A = level: nibble tables nf_lo / nf_hi = a colour stepped down `level` times (low, high nibble)
        sta mt2
        ldy #15                 // nibble tables for this level (low and high nibble)
nf_t:   lda mt2
        sta mt
        tya
nf_d:   ldx mt
        beq nf_s
        dec mt
        tax
        lda nf_dn,x
        jmp nf_d
nf_s:   sta nf_lo,y
        asl
        asl
        asl
        asl
        sta nf_hi,y
        dey
        bpl nf_t
        rts

FadeCells:                      // 1024 bytes of colour cells from (zsrc) to (zdb) through nf_lo / nf_hi (source = destination is fine)
        lda #4
        sta mt2
fc_pg:  ldy #0
fc_lp:  lda (zsrc),y
        and #$0f
        tax
        lda nf_lo,x
        sta mt
        lda (zsrc),y
        lsr
        lsr
        lsr
        lsr
        tax
        lda nf_hi,x
        ora mt
        sta (zdb),y
        iny
        bne fc_lp
        inc zsrc+1
        inc zdb+1
        dec mt2
        bne fc_pg
        rts

// ---- disclaimer (start-up: no interrupts, bank 3 screen $c000): fades in when it appears, out before the title
DiscPrep:                       // the picture starts black: a copy of its colours goes to $0400 (the office loads there later)
        lda #$00
        sta zsrc
        sta zdb
        lda #$c0
        sta zsrc+1
        lda #$04
        sta zdb+1
        ldx #4
        ldy #0
!:      lda (zsrc),y
        sta (zdb),y
        iny
        bne !-
        inc zsrc+1
        inc zdb+1
        dex
        bne !-
        lda #4
DiscLevel:                      // A = level: the screen = the copy at $0400 stepped down `level` times
        jsr NfTables
        lda #$00
        sta zsrc
        sta zdb
        lda #$04
        sta zsrc+1
        lda #$c0
        sta zdb+1
        jmp FadeCells

DiscFadeIn:                     // the display is on and black: levels 3 .. 0
        lda #3
!:      pha
        jsr WaitSteps
        pla
        pha
        jsr DiscLevel
        pla
        sec
        sbc #1
        bpl !-
        rts

DiscFadeOut:                    // four steps down, in place
        lda #1
        jsr NfTables
        lda #4
!:      pha
        jsr WaitSteps
        lda #$00
        sta zsrc
        sta zdb
        lda #$c0
        sta zsrc+1
        sta zdb+1
        jsr FadeCells
        pla
        sec
        sbc #1
        bne !-
        rts

WaitSteps:
        ldx #NF_STEP
WaitFrames:                     // X frames (raster counted: the interrupts are off)
!:      lda $d011
        bpl !-
!:      lda $d011
        bmi !-
        dex
        bne !--
        rts

.macro NfPage(n, lim) {
        ldx #0
!:      lda $0400+n*256,x
        and #$0f
        tay
        lda nf_lo,y
        sta mt
        lda $0400+n*256,x
        lsr
        lsr
        lsr
        lsr
        tay
        lda nf_hi,y
        ora mt
        sta $4000+n*256,x
        inx
        cpx #lim
        bne !-
}

nf_dn:  .byte 0, 15, 9, 0, 0, 0, 0, 8, 9, 11, 2, 0, 11, 0, 0, 12       // one step darker: white > light grey > grey > dark grey > black, yellow > orange > brown > dark grey, light red > red > brown
