//==============================================================================
// Text output: HUD (power, usage, clock, night) and the text cards.
//
// The 64 uppercase glyphs are copied from the character ROM at start-up
// (FONT). Text is plotted straight into the bitmaps:
//   * hires office / cards: one 8x8 cell per character
//   * multicolor camera picture: two cells per character (each glyph pixel is
//     doubled), pixel value hval selects white / green / colour RAM colour
// All of this runs in the main loop, never in an IRQ.
//==============================================================================
.label zgl      = $6b           // glyph pointer (2)
.label zhy      = $6d
.label zhr      = $6e
.label zhk      = $6f
.label zhb      = $70           // bar counter

//------------------------------------------------------------------------------
InitFont:
        lda #$33                // character ROM visible at $d000
        sta $01
        ldx #0
!:      lda $d000,x
        sta FONT,x
        lda $d100,x
        sta FONT+256,x
        inx
        bne !-
        lda #$35
        sta $01
        rts

//------------------------------------------------------------------------------
// Cell addressing.  X = column, Y = row -> zdb (bitmap), zds (screen RAM)
//------------------------------------------------------------------------------
CellAddr:
        clc
        lda r320_lo,y
        adc c8_lo,x
        sta zdb
        lda r320_hi,y
        adc c8_hi,x
        adc tbmp_hi
        sta zdb+1
        stx mt                  // (zt belongs to the IRQ)
        clc
        lda r40_lo,y
        adc mt
        sta zds
        lda r40_hi,y
        adc #0
        adc tscr_hi
        sta zds+1
        rts

// glyph pointer for screen code A -> zgl
GlyphPtr:
        pha
        lsr
        lsr
        lsr
        lsr
        lsr
        clc
        adc #>FONT
        sta zgl+1
        pla
        asl
        asl
        asl
        sta zgl
        rts

//------------------------------------------------------------------------------
// DrawH: string at zsrc ($ff terminated) at cell X,Y of the hires bitmap
//        (tbmp_hi / tscr_hi), screen colour byte hcol
//------------------------------------------------------------------------------
DrawH:
        jsr CellAddr
        ldy #0
dh_lp:  sty zhy
        lda (zsrc),y
        cmp #$ff
        beq dh_end
        jsr GlyphPtr
        ldy #7
!:      lda (zgl),y
        sta (zdb),y
        dey
        bpl !-
        ldy #0
        lda hcol
        sta (zds),y
        clc
        lda zdb
        adc #8
        sta zdb
        bcc !+
        inc zdb+1
!:      inc zds
        bne !+
        inc zds+1
!:      ldy zhy
        iny
        bne dh_lp
dh_end: rts

// one solid bar cell at zdb / zds with screen colour A (hires)
BarH:
        pha
        ldy #7
        lda #$7e
!:      sta (zdb),y
        dey
        bpl !-
        pla
        ldy #0
        sta (zds),y
        rts

//------------------------------------------------------------------------------
// DrawM: same for the multicolor camera picture, two cells per character.
//        hval = pixel value 1..3, hcol = screen byte, colour RAM gets $02.
//------------------------------------------------------------------------------
DrawM:
        jsr CellAddr
        ldy #0
dm_lp:  sty zhy
        lda (zsrc),y
        cmp #$ff
        beq dm_end
        jsr GlyphPtr
        ldy #7
dm_row: sty zhr
        lda (zgl),y
        pha
        lsr
        lsr
        lsr
        lsr
        tax
        lda mc_tab,x
        jsr MulVal
        ldy zhr
        sta (zdb),y
        pla
        and #$0f
        tax
        lda mc_tab,x
        jsr MulVal
        tya
        clc
        adc #8
        tay
        lda zhk
        sta (zdb),y
        ldy zhr
        dey
        bpl dm_row
        jsr McCellColors
        clc
        lda zdb
        adc #16
        sta zdb
        bcc !+
        inc zdb+1
!:      clc
        lda zds
        adc #2
        sta zds
        bcc !+
        inc zds+1
!:      ldy zhy
        iny
        bne dm_lp
dm_end: rts

// A = pixel pattern (%01 per set pixel) -> A = pattern * hval (also in zhk)
MulVal:
        sta zhk
        ldx hval
        cpx #2
        bcc mv_done
        beq mv_2
        lda zhk                 // x3
        asl
        ora zhk
        sta zhk
        rts
mv_2:   asl zhk
mv_done:
        lda zhk
        rts

// screen + colour RAM for the two cells at zds
McCellColors:
        ldy #0
        lda hcol
        sta (zds),y
        iny
        sta (zds),y
        lda zds+1
        clc
        adc #$98                // $4000 -> $d800
        sta zds+1
        lda #$02
        dey
        sta (zds),y
        iny
        sta (zds),y
        lda zds+1
        sec
        sbc #$98
        sta zds+1
        rts

// two solid camera bar cells at zdb (value hval): $55*v and a slightly narrower right half
BarM:
        lda #$55
        jsr MulVal
        ldy #7
!:      sta (zdb),y
        dey
        bpl !-
        lda #$54
        jsr MulVal              // pattern also in zhk
        ldy #7
!:      tya
        clc
        adc #8
        tay
        lda zhk
        sta (zdb),y
        tya
        sec
        sbc #8
        tay
        dey
        bpl !-
        jmp BarColors

BarColors:                      // same colouring as text
        lda hcol
        ldy #0
        sta (zds),y
        iny
        sta (zds),y
        lda zds+1
        clc
        adc #$98
        sta zds+1
        lda #$02
        dey
        sta (zds),y
        iny
        sta (zds),y
        lda zds+1
        sec
        sbc #$98
        sta zds+1
        rts

// blank two camera cells (usage bar off)
ClearM:
        lda #0
        ldy #15
!:      sta (zdb),y
        dey
        bpl !-
        jmp BarColors

//------------------------------------------------------------------------------
// hbuf helpers
//------------------------------------------------------------------------------
// power percent (0..100) -> hbuf: 3 right aligned digits + '%' + end
PowerText:
        ldx #32
        stx hbuf
        stx hbuf+1
        lda g_power
        ldy #0                  // hundreds
        cmp #100
        bcc !+
        sbc #100
        ldy #1
        ldx #49                 // '1'
        stx hbuf
!:      ldx #0
!:      cmp #10
        bcc !+
        sbc #10
        inx
        bne !-
!:      sta zhr                 // ones
        cpy #0
        bne pt_ten              // hundreds present: tens always shown
        cpx #0
        beq pt_ones
pt_ten: txa
        ora #48
        sta hbuf+1
pt_ones:
        lda zhr
        ora #48
        sta hbuf+2
        lda #37                 // %
        sta hbuf+3
        lda #$ff
        sta hbuf+4
        rts

// clock text "12 AM" / " 3 AM" -> hbuf
TimeText:
        lda g_hour
        bne tt_h
        lda #49
        sta hbuf
        lda #50
        sta hbuf+1
        jmp tt_am
tt_h:   ora #48
        sta hbuf+1
        lda #32
        sta hbuf
tt_am:  lda #32
        sta hbuf+2
        lda #1
        sta hbuf+3
        lda #13
        sta hbuf+4
        lda #$ff
        sta hbuf+5
        rts

// "1" .. "6" -> hbuf for the night number (single char)
NightText:
        lda g_night
        ora #48
        sta hbuf
        lda #$ff
        sta hbuf+1
        rts

.macro SetStr(s) {
        lda #<s
        sta zsrc
        lda #>s
        sta zsrc+1
}
.macro SetBuf() {
        lda #<hbuf
        sta zsrc
        lda #>hbuf
        sta zsrc+1
}

//------------------------------------------------------------------------------
// HUD in the office (hires)
//------------------------------------------------------------------------------
HudOffice:
        lda #>OFF_BMP
        sta tbmp_hi
        lda #>OFF_SCR
        sta tscr_hi
        lda #$10
        sta hcol
        :SetStr(str_power)
        ldx #1
        ldy #0
        jsr DrawH
        jsr PowerText
        :SetBuf()
        ldx #8
        ldy #0
        jsr DrawH
        :SetStr(str_usage)
        ldx #1
        ldy #1
        jsr DrawH
        lda #0
        sta zhb
ho_bar: lda #8
        clc
        adc zhb
        tax
        ldy #1
        jsr CellAddr
        ldx zhb
        inx
        cpx g_usage
        bcc ho_on
        beq ho_on
        lda #0                  // off: blank cell
        ldy #7
!:      sta (zdb),y
        dey
        bpl !-
        jmp ho_next
ho_on:  lda #$50                // green
        ldx g_usage
        cpx #3
        bcc !+
        lda #$20                // red from usage 3 on
!:      jsr BarH
ho_next:
        inc zhb
        lda zhb
        cmp #5
        bne ho_bar
        jsr TimeText
        :SetBuf()
        lda #$10
        sta hcol
        ldx #34
        ldy #0
        jsr DrawH
        :SetStr(str_night)
        ldx #32
        ldy #1
        jsr DrawH
        jsr NightText
        :SetBuf()
        ldx #38
        ldy #1
        jmp DrawH

//------------------------------------------------------------------------------
// HUD in the camera picture (multicolor)
//------------------------------------------------------------------------------
HudCam:
        lda #>CAM_BMP
        sta tbmp_hi
        lda #>CAM_SCR
        sta tscr_hi
        lda #$15                // %01 white, %10 green (colour RAM %11 red)
        sta hcol
        lda #1
        sta hval
        :SetStr(str_power)
        ldx #1
        ldy #22
        jsr DrawM
        jsr PowerText
        :SetBuf()
        ldx #15
        ldy #22
        jsr DrawM
        :SetStr(str_usage)
        ldx #1
        ldy #23
        jsr DrawM
        lda #0
        sta zhb
hc_bar: lda zhb
        asl
        clc
        adc #14
        tax
        ldy #23
        jsr CellAddr
        lda #2
        sta hval
        ldx g_usage
        cpx #3
        bcc !+
        lda #3
        sta hval
!:      ldx zhb
        inx
        cpx g_usage
        bcc hc_on
        beq hc_on
        jsr ClearM
        jmp hc_next
hc_on:  jsr BarM
hc_next:
        inc zhb
        lda zhb
        cmp #5
        bne hc_bar
        lda #1
        sta hval
        jsr TimeText
        :SetBuf()
        ldx #29
        ldy #4
        jsr DrawM
        :SetStr(str_night)
        ldx #25
        ldy #5
        jsr DrawM
        jsr NightText
        :SetBuf()
        ldx #37
        ldy #5
        jmp DrawM

//------------------------------------------------------------------------------
// 5 AM -> 6 AM: the digit is a 16x16 window onto a 16x32 strip (5 above 6); the frame tick sets
// roll_off (0..16 lines) and this copies the visible part into the two cell columns
//------------------------------------------------------------------------------
RollStep:
        lda mode
        cmp #M_WIN
        bne rs_ret
        lda roll_off
        cmp roll_drawn
        beq rs_ret
        sta roll_drawn
        sta zhk
        lda #>CAM_BMP
        sta tbmp_hi
        lda #>CAM_SCR
        sta tscr_hi
        lda #0
        sta zhb
rs_lp:  lda zhb
        and #1
        clc
        adc #11
        tay
        lda zhb
        lsr
        clc
        adc #16
        tax
        jsr CellAddr
        lda zhb
        and #2                  // second column: strip starts at 32
        asl
        asl
        asl
        asl
        sta zhr
        lda zhb
        and #1
        asl
        asl
        asl
        clc
        adc zhr
        clc
        adc zhk
        tax
        ldy #0
!:      lda roll_buf,x
        sta (zdb),y
        inx
        iny
        cpy #8
        bne !-
        inc zhb
        lda zhb
        cmp #4
        bne rs_lp
rs_ret: rts

HudRefresh:
        lda hud_dirty
        beq hr_ret
        lda g_act
        beq hr_ret
        lda mode
        cmp #M_POWER
        bcs hr_ret
        lda hud_dirty
        and #1
        beq hr_cam
        sei
        lda hud_dirty
        and #$fe
        sta hud_dirty
        cli
        jsr HudOffice
hr_cam: lda hud_dirty
        and #2
        beq hr_ret
        lda cam_loaded
        cmp #$ff
        beq hr_ret
        sei
        lda hud_dirty
        and #$fd
        sta hud_dirty
        cli
        jmp HudCam
hr_ret: rts

//------------------------------------------------------------------------------
// Text cards: black hires screen in the camera buffer with big (16x16) text
//------------------------------------------------------------------------------
CardClear:
        lda #<CAM_BMP
        sta zdb
        lda #>CAM_BMP
        sta zdb+1
        ldx #32                 // 8192 bytes (a little more than the bitmap)
        ldy #0
        tya
!:      sta (zdb),y
        iny
        bne !-
        inc zdb+1
        dex
        bne !-
        lda #<CAM_SCR
        sta zdb
        lda #>CAM_SCR
        sta zdb+1
        ldx #3
        lda #$10
!:      sta (zdb),y
        iny
        bne !-
        inc zdb+1
        dex
        bne !-
        ldy #0
!:      sta CAM_SCR+$300,y
        iny
        cpy #$e8
        bne !-
        lda #$ff
        sta cam_loaded
        rts

// DrawBig: string at zsrc, X = column, Y = row, 2x2 cells per character
DrawBig:
        jsr CellAddr
        ldy #0
db_lp:  sty zhy
        lda (zsrc),y
        cmp #$ff
        beq db_end
        jsr GlyphPtr
        lda #0
        sta zhk                 // cell row 0 / 1
db_cr:  ldy #0                  // output line 0..7 inside the cell row
db_ln:  sty zhr
        tya
        lsr
        clc
        ldx zhk
        beq !+
        adc #4
!:      tay                     // source row
        lda (zgl),y
        pha
        lsr
        lsr
        lsr
        lsr
        tax
        lda dbl_tab,x
        ldy zhr
        sta (zdb),y
        pla
        and #$0f
        tax
        lda dbl_tab,x
        tya
        clc
        adc #8
        tay
        lda dbl_tab,x
        sta (zdb),y
        ldy zhr
        iny
        cpy #8
        bne db_ln
        // next cell row: +320 bytes
        clc
        lda zdb
        adc #<320
        sta zdb
        lda zdb+1
        adc #>320
        sta zdb+1
        inc zhk
        lda zhk
        cmp #2
        bne db_cr
        // back to the first cell row, next character
        sec
        lda zdb
        sbc #<(640-16)
        sta zdb
        lda zdb+1
        sbc #>(640-16)
        sta zdb+1
        ldy zhy
        iny
        bne db_lp
db_end: rts

// card type in A
DrawCard:
        pha
        jsr CardClear
        lda #>CAM_BMP
        sta tbmp_hi
        lda #>CAM_SCR
        sta tscr_hi
        pla
        beq dc_night
        cmp #CARD_5AM
        bne !+
        jmp dc_5
!:      cmp #CARD_OVER
        bne !+
        jmp dc_over
!:
        // the end
        :SetStr(str_end1)
        ldx #5
        ldy #9
        jsr DrawBig
        :SetStr(str_end2)
        ldx #12
        ldy #14
        jmp DrawBig
dc_night:
        :SetStr(str_1200)
        ldx #12
        ldy #8
        jsr DrawBig
        lda g_night             // "1ST NIGHT" ...
        sec
        sbc #1
        tax
        lda ord_lo,x
        sta zsrc
        lda ord_hi,x
        sta zsrc+1
        ldx #11
        ldy #13
        jmp DrawBig
dc_5:   :SetStr(str_am)         // " AM" stays; the digit rolls from 5 to 6 (see RollStep)
        ldx #18
        ldy #11
        jsr DrawBig
        :SetStr(str_5)
        ldx #16
        ldy #11
        jsr DrawBig
        :SetStr(str_6)          // the 6 waits below the 5 (rows 13-14), is copied into roll_buf and erased
        ldx #16
        ldy #13
        jsr DrawBig
        lda #0
        sta zhb
br_lp:  lda zhb
        and #3
        clc
        adc #11
        tay
        lda zhb
        lsr
        lsr
        clc
        adc #16
        tax
        jsr CellAddr
        lda zhb
        asl
        asl
        asl
        tax
        ldy #0
!:      lda (zdb),y
        sta roll_buf,x
        inx
        iny
        cpy #8
        bne !-
        lda zhb
        and #2                  // cell rows 13-14: erase (only the 5 stays on screen)
        beq br_nx
        lda #0
        ldy #7
!:      sta (zdb),y
        dey
        bpl !-
br_nx:  inc zhb
        lda zhb
        cmp #8
        bne br_lp
        lda #0
        sta roll_off
        sta roll_drawn
        rts
dc_over:
        :SetStr(str_over)
        ldx #11
        ldy #11
        jmp DrawBig

// "NIGHT n" on the title picture
DrawTitleTxt:
        lda #>CAM_BMP
        sta tbmp_hi
        lda #>CAM_SCR
        sta tscr_hi
        lda #$10
        sta hcol
        :SetStr(str_night)
        ldx #6
        ldy #14
        jsr DrawH
        jsr NightText
        :SetBuf()
        ldx #12
        ldy #14
        jsr DrawH
        lda g_maxnight          // "1-3 CHOOSE NIGHT" once more than one night is open
        cmp #2
        bcc dtt_ret
        ora #48
        sta hbuf+2
        lda #49
        sta hbuf
        lda #45
        sta hbuf+1
        lda #$ff
        sta hbuf+3
        :SetBuf()
        ldx #6
        ldy #15
        jsr DrawH
        :SetStr(str_choose)
        ldx #9
        ldy #15
        jmp DrawH
dtt_ret: rts

//------------------------------------------------------------------------------
// Data (screen codes), segment Code4
//------------------------------------------------------------------------------
.segment Code4
.encoding "screencode_upper"
str_power:  .text "POWER:"
            .byte $ff
str_usage:  .text "USAGE:"
            .byte $ff
str_night:  .text "NIGHT "
            .byte $ff
str_1200:   .text "12:00 AM"
            .byte $ff
str_am:     .text " AM"
            .byte $ff
str_5:      .text "5"
            .byte $ff
str_6:      .text "6"
            .byte $ff
str_choose: .text " CHOOSE NIGHT"
            .byte $ff
str_over:   .text "GAME OVER"
            .byte $ff
str_end1:   .text "CONGRATULATIONS"
            .byte $ff
str_end2:   .text "YOU WIN"
            .byte $ff
ord1:       .text "1ST NIGHT"
            .byte $ff
ord2:       .text "2ND NIGHT"
            .byte $ff
ord3:       .text "3RD NIGHT"
            .byte $ff
ord4:       .text "4TH NIGHT"
            .byte $ff
ord5:       .text "5TH NIGHT"
            .byte $ff
ord6:       .text "6TH NIGHT"
            .byte $ff
ord_lo:     .byte <ord1, <ord2, <ord3, <ord4, <ord5, <ord6
ord_hi:     .byte >ord1, >ord2, >ord3, >ord4, >ord5, >ord6

mc_tab:     .fill 16, (floor(i/8)&1)*$40 + (floor(i/4)&1)*$10 + (floor(i/2)&1)*$04 + (i&1)*$01
dbl_tab:    .fill 16, (floor(i/8)&1)*$c0 + (floor(i/4)&1)*$30 + (floor(i/2)&1)*$0c + (i&1)*$03
r320_lo:    .fill 25, <(i * 320)
r320_hi:    .fill 25, >(i * 320)
r40_lo:     .fill 25, <(i * 40)
r40_hi:     .fill 25, >(i * 40)
c8_lo:      .fill 40, <(i * 8)
c8_hi:      .fill 40, >(i * 8)
.segment Code2
