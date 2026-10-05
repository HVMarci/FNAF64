//==============================================================================
// Foxy running out of camera 2A's picture (the third picture of the west hall, tools/gen_assets.py foxy_run_canvas)
//
// While that picture is on the monitor he stands still for FR_HOLD frames, then jumps FR_STEP cells to the right every few frames until he
// has left the picture. The main loop moves his cells inside the camera buffer: per text row (fr_a / fr_b = first / last text column
// that holds him, in the picture as loaded) the bitmap, screen and colour RAM bytes of those cells are copied FR_STEP cells to the right and
// the FR_STEP cells he leaves are cleared (black). The arrival (game.asm FoxyArrive) is held back while he is on screen and comes at once
// when he is gone; the picture is reloaded as soon as the AI moves him away (or he gets the player).
//==============================================================================
.const FR_STEP      = 3
.const FR_HOLD      = 30        // frames he stands there before he runs
.label fp_s         = $6b       // 2: source of the block copy (zero page: hud.asm's temporaries, free outside HudRefresh)
.label fp_d         = $6d       // 2: ... destination
.label fp_ps        = $77       // 2: bitmap / screen row of the current text row
.label fp_pb        = $79       // 2

.import source "../build/gen/foxy_run.asm"

// every frame, from the main loop
FoxyRunStep:
        lda mode
        cmp #M_CAM
        bne fr_off
        lda cam_cur
        cmp #3
        bne fr_off
        lda fx_seen
        beq fr_off
        lda ai_pos+3
        cmp #3
        bne fr_off
        ldx #3                  // is the running picture (the last of camera 2A) the one in the buffer?
        lda cam_first,x
        clc
        adc cam_nfr,x
        sec
        sbc #1
        cmp cam_loaded
        bne fr_off
        lda fr_done
        bne fr_ret
        lda #3                  // he is on screen: no arrival yet
        sta fx_run
        lda fr_hold
        cmp #FR_HOLD
        bcs fr_go
        inc fr_hold
        rts
fr_go:  lda fr_t
        clc
        adc #FR_AMIN
        cmp #40                 // his left edge has left the picture
        bcs fr_end
        jsr FrShift
        lda fr_t
        clc
        adc #FR_STEP
        sta fr_t
        rts
fr_end: lda #1
        sta fr_done
        sta fx_run              // he arrives now
fr_ret: rts
fr_off: lda #0
        sta fr_hold
        sta fr_t
        sta fr_done
        rts

// move every row one step
FrShift:
        lda #<(CAM_BMP + FR_ROW0*320)
        sta fp_pb
        lda #>(CAM_BMP + FR_ROW0*320)
        sta fp_pb+1
        lda #<(CAM_SCR + FR_ROW0*40)
        sta fp_ps
        lda #>(CAM_SCR + FR_ROW0*40)
        sta fp_ps+1
        ldx #0
frs_row: stx fr_x
        lda fr_a,x
        clc
        adc fr_t
        sta fr_c                // first column of him in this row now
        cmp #40
        bcs frs_next             // already gone
        lda fr_b,x
        clc
        adc fr_t
        clc
        adc #FR_STEP
        cmp #40
        bcc !+
        lda #39
!:      sec                     // cells to copy = last destination column - first column - (FR_STEP - 1)
        sbc fr_c
        sec
        sbc #FR_STEP - 1
        bcc frs_clear
        beq frs_clear
        sta fr_n
        // bitmap
        lda fr_c
        jsr FrCol8
        lda fr_n
        asl
        asl
        asl
        tay
        lda #FR_STEP * 8
        jsr FrBlk
        // screen
        lda fr_c
        clc
        adc fp_ps
        sta fp_s
        lda fp_ps+1
        adc #0
        sta fp_s+1
        ldy fr_n
        lda #FR_STEP
        jsr FrBlk
        // colour RAM
        lda fp_s+1
        clc
        adc #$98
        sta fp_s+1
        ldy fr_n
        lda #FR_STEP
        jsr FrBlk
frs_clear:                       // the cells he leaves: black
        lda #40
        sec
        sbc fr_c
        cmp #FR_STEP + 1
        bcc !+
        lda #FR_STEP
!:      asl
        asl
        asl
        sta fr_n
        lda fr_c
        jsr FrCol8
        ldy fr_n
        dey
        lda #0
!:      sta (fp_s),y
        dey
        bpl !-
frs_next:
        clc
        lda fp_pb
        adc #<320
        sta fp_pb
        lda fp_pb+1
        adc #>320
        sta fp_pb+1
        clc
        lda fp_ps
        adc #40
        sta fp_ps
        bcc !+
        inc fp_ps+1
!:      ldx fr_x
        inx
        cpx #FR_ROWS
        beq !+
        jmp frs_row
!:      rts

// fp_s = the bitmap of column A in this row (fp_pb + 8 * A)
FrCol8: ldy #0
        sty fp_s+1
        asl
        rol fp_s+1
        asl
        rol fp_s+1
        asl
        rol fp_s+1
        clc
        adc fp_pb
        sta fp_s
        lda fp_s+1
        adc fp_pb+1
        sta fp_s+1
        rts

// copy Y bytes (1 - 255) from fp_s to fp_s + A, back to front (the blocks overlap)
FrBlk:  clc
        adc fp_s
        sta fp_d
        lda fp_s+1
        adc #0
        sta fp_d+1
        dey
!:      lda (fp_s),y
        sta (fp_d),y
        dey
        cpy #$ff
        bne !-
        rts

fr_hold:    .byte 0
fr_t:       .byte 0             // cells he has moved to the right
fr_done:    .byte 0
fr_x:       .byte 0
fr_c:       .byte 0
fr_n:       .byte 0
