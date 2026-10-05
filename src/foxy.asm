//==============================================================================
// Foxy's jumpscare (assembled into foxy.prg, which Sparkle loads to FX_CODE with his bundle; imported by main.asm)
//
// His sprite (assets/jumpscare/foxy/1.png, cut out by tools/gen_assets.py: 12 x 23 cells, every cell is either his or the
// background's) runs in from the left door over the office bitmap, 5 jumps of 2-4 cells, the screen shaking as in every scare. The
// main loop draws it: cells he covers come from the sprite, the cells he leaves come from a copy of the office strip (office
// columns 0-14) taken when the scare starts, so whatever state the office was in stays intact around him. When he stands where
// 1.png has him the picture switches once to 2.png (loaded into the camera buffer by the same bundle) and shakes on.
//
// sc_ph 7  the main loop copies the office strip (fx_cmd 1)
//       8  the scream starts; the sprite jumps (fx_cmd 2 = draw the position in fx_new), then holds for a few frames
//       9  2.png, shaking, then sc_ph 4 (static, game over) like the other scares
//==============================================================================
.const FX_STEPS     = 5
.const FX_HOLD      = 8         // frames he stands still (shaking) before 2.png
.const FX_PICLEN    = 36        // frames of 2.png
.const FX_ROWS      = 23
.label zbg          = $77       // 2: strip copy, bitmap of the current row
.label zbs          = $79       // 2: strip copy, colours of the current row
.label zsb          = $7b       // 2: sprite bitmap of the current row, shifted so that (zsb),y with y = 8 * column works
.label zss          = $7d       // 2: sprite colours of the current row, shifted so that (zss),y with y = column works

.macro Add16(p, n) {
        clc
        lda p
        adc #<n
        sta p
        lda p+1
        adc #>n
        sta p+1
}

// ---- frame tick (sm_scare jumps here for sc_ph >= 7) ----
FoxyScare:
        lda sc_ph
        cmp #8
        bcs fxs_8
        lda tcnt                // phase 7
        bne fxs_7w
        inc tcnt
        lda #1
        sta fx_cmd              // the main loop copies the office strip
fxs_ret: rts
fxs_7w:  lda fx_cmd
        bne fxs_ret
        lda #0
        sta tph
        sta tcnt
        lda #$f3                // -13: nothing of him is on screen yet
        sta fx_old
        lda #8
        sta sc_ph
        jmp SndScream           // the scream starts with the sprite
fxs_8:   cmp #9
        bcs fxs_9
        lda #LAY_OFFICE
        jsr ScareJolt
        lda fx_cmd              // the main loop is still drawing the last jump
        bne fxs_ret
        ldx tph
        cpx #FX_STEPS
        bcs fxs_hold
        lda fx_tab,x
        sta fx_new
        lda #2
        sta fx_cmd
        inc tph
        rts
fxs_hold:
        inc tcnt
        lda tcnt
        cmp #FX_HOLD
        bcc fxs_ret
        lda #9
        sta sc_ph
        lda #0
        sta tcnt
        rts
fxs_9:   lda #LAY_TITLE          // 2.png in the camera buffer
        jsr ScareJolt
        inc tcnt
        lda tcnt
        cmp #FX_PICLEN
        bcc fxs_ret
        lda #4                  // static, then game over
        sta sc_ph
        lda #0
        sta tcnt
        rts

// ---- main loop (Main calls it while sc_ph >= 7) ----
FoxyMain:
        lda fx_cmd
        beq fxm_ret
        cmp #1
        beq fxm_copy
        jmp fxm_draw
fxm_ret: rts

fxm_copy:                        // office columns 0-14 of rows 2-24 -> FX_BG (bitmap) and FX_BGS (colours)
        lda #<(OFF_BMP + 2*320)
        sta zdb
        lda #>(OFF_BMP + 2*320)
        sta zdb+1
        lda #<(OFF_SCR + 2*40)
        sta zds
        lda #>(OFF_SCR + 2*40)
        sta zds+1
        lda #<FX_BG
        sta zbg
        lda #>FX_BG
        sta zbg+1
        lda #<FX_BGS
        sta zbs
        lda #>FX_BGS
        sta zbs+1
        lda #FX_ROWS
        sta fx_row
fxc_row: ldy #119
!:      lda (zdb),y
        sta (zbg),y
        dey
        bpl !-
        ldy #14
!:      lda (zds),y
        sta (zbs),y
        dey
        bpl !-
        :Add16(zdb, 320)
        :Add16(zds, 40)
        :Add16(zbg, 120)
        :Add16(zbs, 15)
        dec fx_row
        bne fxc_row
        lda #0
        sta fx_cmd
        rts

// Draw the sprite with its left edge at office column fx_new (signed; -10 .. 3). Columns fx_xl .. fx_xr-1 are redrawn: from the
// old left edge (the cells he left behind) to his right edge. A cell is the sprite's when its colour byte is not $ff, else the strip's.
fxm_draw:
        lda fx_old
        bpl !+
        lda #0
!:      sta fx_xl
        lda fx_new
        clc
        adc #12                 // his right edge + 1, at most the strip's width
        cmp #15
        bcc !+
        lda #15
!:      sta fx_xr
        ldx #0                  // fx_hi: the new left edge sign-extended
        lda fx_new
        bpl !+
        ldx #$ff
!:      stx fx_hi
        sta zsb                 // zsb = FX_SPB - 8 * left edge
        stx zsb+1
        asl zsb
        rol zsb+1
        asl zsb
        rol zsb+1
        asl zsb
        rol zsb+1
        sec
        lda #<FX_SPB
        sbc zsb
        sta zsb
        lda #>FX_SPB
        sbc zsb+1
        sta zsb+1
        sec                     // zss = FX_SPS + 3 - left edge
        lda #<(FX_SPS + 3)
        sbc fx_new
        sta zss
        lda #>(FX_SPS + 3)
        sbc fx_hi
        sta zss+1
        lda #<FX_BG
        sta zbg
        lda #>FX_BG
        sta zbg+1
        lda #<FX_BGS
        sta zbs
        lda #>FX_BGS
        sta zbs+1
        lda #<(OFF_BMP + 2*320)
        sta zdb
        lda #>(OFF_BMP + 2*320)
        sta zdb+1
        lda #<(OFF_SCR + 2*40)
        sta zds
        lda #>(OFF_SCR + 2*40)
        sta zds+1
        lda #FX_ROWS
        sta fx_row
fxd_row: ldx fx_xl
fxd_cell:
        stx fx_x
        txa
        tay                     // y = column
        lda (zss),y
        cmp #$ff
        beq fxd_bg
        sta (zds),y             // the sprite's colour byte
        tya
        asl
        asl
        asl
        tay                     // y = 8 * column
        .for (var i = 0; i < 8; i++) {
            lda (zsb),y
            sta (zdb),y
            iny
        }
        jmp fxd_nx
fxd_bg:  lda (zbs),y             // the strip's colour byte
        sta (zds),y
        tya
        asl
        asl
        asl
        tay
        .for (var i = 0; i < 8; i++) {
            lda (zbg),y
            sta (zdb),y
            iny
        }
fxd_nx:  ldx fx_x
        inx
        cpx fx_xr
        beq fxd_end
        jmp fxd_cell
fxd_end: :Add16(zdb, 320)
        :Add16(zds, 40)
        :Add16(zbg, 120)
        :Add16(zbs, 15)
        :Add16(zsb, 96)
        :Add16(zss, 29)
        dec fx_row
        beq fxd_done
        jmp fxd_row
fxd_done:
        lda fx_new
        sta fx_old
        lda #0
        sta fx_cmd
        rts

fx_cmd:     .byte 0             // 0 idle, 1 copy the office strip, 2 draw the sprite at fx_new (the frame tick asks, the main loop does it)
fx_old:     .byte 0             // left edge (office column, signed) of the sprite as it is on screen
fx_new:     .byte 0             // ... and where it goes
fx_hi:      .byte 0
fx_xl:      .byte 0
fx_xr:      .byte 0
fx_x:       .byte 0
fx_row:     .byte 0
fx_tab:     .byte $f6, $fa, $fe, $01, $03       // -10, -6, -2, 1, 3: the last one is his place in 1.png (tools/gen_assets.py FX_STEPS)
