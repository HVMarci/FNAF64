//==============================================================================
// Newspaper fade in / out. The picture is a hires bitmap, so it fades through its colour cells (screen RAM $4000): the grey ramp
// black < dark grey < grey < light grey < white is stepped down 0..4 times (level 4 = black). The original cells are kept in a
// copy at $0400 (the office buffer is not needed while the newspaper is up; the next night / title loads it again).
//==============================================================================
// call once the newspaper is loaded and still hidden: the picture starts black
NewsFadeInit:
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
        jmp nf_set

// A = frame at which the newspaper is gone (tcnt = frames shown so far): fade in over the first frames, out over the last ones
NewsFade:
        sec
        sbc tcnt
        lsr
        lsr
        lsr
        jsr nf_lv
        pha
        lda tcnt
        lsr
        lsr
        lsr
        jsr nf_lv
        sta mt2
        pla
        cmp mt2
        bcs !+
        lda mt2
!:      cmp nf_cur
        bne nf_set
        rts
nf_lv:  cmp #5                  // frames / 8 -> level (4 .. 0), 0 once past the fade
        bcs nf_z
        eor #$ff
        sec
        adc #4
        rts
nf_z:   lda #0
        rts

nf_set: sta nf_cur
        sta mt2
        ldy #15                 // nibble tables for this level: colour stepped down `level` times (low and high nibble)
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
        :NfPage(0, 0)
        :NfPage(1, 0)
        :NfPage(2, 0)
        :NfPage(3, 232)
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

nf_dn:  .byte 0, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 11, 0, 0, 12     // one step darker: white > light grey > grey > dark grey > black
