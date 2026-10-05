//==============================================================================
// Foxy running down the west hall (camera 2A), after the original animation
//
// The first picture of the run is the third picture of camera 2A (the hall with Foxy far away); it loads like every camera picture,
// and the camera shows it instead of 1.png / 2.png as soon as Foxy sprints (game.asm WantFrame). Its bundle also brings the steps of
// the run (tools/gen_assets.py gen_foxy_anim) into bank 3's noise memory ($e000-$fff9 and a few gaps in $c000-$cbff), which nothing may
// show while the run plays. Each step is a list of spans of cells (count, cell index, bitmap, screen, colour bytes; $ff = continue at
// the address that follows, 0 = end) that the main loop copies into the camera buffer. When the run is over (or the picture is left
// early) the noise bitmap is rebuilt. The arrival (game.asm FoxyArrive) is held back while he runs and comes at once when he is gone;
// after that the AI moves him back or he gets the player.
//==============================================================================
.const FR_HOLD      = 10        // frames the first picture stays
.const FR_RATE      = 4         // frames per step
.label fp_p         = $6b       // 2: the step data (zero page: hud.asm's temporaries, free outside HudRefresh)
.label fp_b         = $6d       // 2: destination bitmap
.label fp_s         = $77       // 2: destination screen RAM
.label fp_c         = $79       // 2: destination colour RAM

.import source "../build/gen/foxy_run.asm"

// every frame, from the main loop
FoxyRunStep:
        lda g_pause
        bne fr_ret
        lda ai_pos+3
        cmp #3
        bne fr_off
        lda cam_cur
        cmp #3
        bne fr_off
        lda mode
        cmp #M_CAM
        beq fr_cam
        cmp #M_UP               // the monitor goes up / the picture loads: wait
        beq fr_ret
        cmp #M_SWITCH
        bne fr_off
fr_ret: rts
fr_cam: jsr FrPic               // is the first picture of the run (the last of camera 2A) the one in the buffer?
        cmp cam_loaded
        bne fr_ret
        lda fr_k
        cmp #FA_STEPS
        bcs fr_fin
        lda #3                  // he is running: no arrival yet
        sta fx_run
        lda fr_hold
        cmp #FR_HOLD
        bcc fr_inc
        lda #FR_HOLD - FR_RATE
        sta fr_hold
        lda fr_k
        inc fr_k
        jmp FrApply
fr_inc: inc fr_hold
        rts
fr_fin: lda fr_done
        bne fr_ret
        inc fr_done
        jsr NoiseRestore
        lda #1
        sta fx_run              // he arrives now
        rts
// not wanted (any more): the picture the run has played on, or the steps sitting in the noise memory, must go
fr_off: jsr FrPic
        cmp cam_loaded
        bne fo_reset
        lda fr_done
        bne fo_shown
        jsr NoiseRestore        // the run did not finish: the picture is not complete and the steps are still in the noise memory
        beq fo_inval
fo_shown:
        lda mode                // the finished picture (empty hall) is fine while it is shown, until the AI moves Foxy
        cmp #M_CAM
        beq fo_reset
        cmp #M_UP
        beq fo_reset
        cmp #M_SWITCH
        beq fo_reset
fo_inval:
        lda #$ff
        sta cam_loaded
fo_reset:
        lda #0
        sta fr_hold
        sta fr_k
        sta fr_done
        rts

FrPic:  ldx #3                  // A = picture number of the first picture of the run
        lda cam_first,x
        clc
        adc cam_nfr,x
        sec
        sbc #1
        rts

// play step A
FrApply:
        tax
        lda fr_tab_lo,x
        sta fp_p
        lda fr_tab_hi,x
        sta fp_p+1
fa_next:
        ldy #0
        lda (fp_p),y
        bne !+
        rts                     // end of the step
!:      cmp #$ff
        bne fa_span
        iny                     // continue in the next block
        lda (fp_p),y
        tax
        iny
        lda (fp_p),y
        sta fp_p+1
        stx fp_p
        jmp fa_next
fa_span:
        sta fr_n
        asl
        asl
        asl
        sta fr_n8
        iny
        lda (fp_p),y            // cell index
        sta fp_b
        sta fp_s
        sta fp_c
        iny
        lda (fp_p),y
        sta fp_b+1
        clc
        adc #$40
        sta fp_s+1              // + CAM_SCR
        lda fp_b+1
        clc
        adc #$d8
        sta fp_c+1              // + colour RAM
        asl fp_b                // * 8 + CAM_BMP
        rol fp_b+1
        asl fp_b
        rol fp_b+1
        asl fp_b
        rol fp_b+1
        lda fp_b+1
        clc
        adc #>CAM_BMP
        sta fp_b+1
        lda #3
        jsr FrSkip
        ldy #0                  // bitmap
!:      lda (fp_p),y
        sta (fp_b),y
        iny
        cpy fr_n8
        bne !-
        lda fr_n8
        jsr FrSkip
        ldy #0                  // screen RAM
!:      lda (fp_p),y
        sta (fp_s),y
        iny
        cpy fr_n
        bne !-
        lda fr_n
        jsr FrSkip
        ldy #0                  // colour RAM
!:      lda (fp_p),y
        sta (fp_c),y
        iny
        cpy fr_n
        bne !-
        lda fr_n
        jsr FrSkip
        jmp fa_next

FrSkip: clc                     // fp_p += A
        adc fp_p
        sta fp_p
        bcc !+
        inc fp_p+1
!:      rts

// the steps have been in the noise memory: random bytes again ($fffa-$ffff are the vectors). Only zdb, X and Y are used here: the
// frame tick uses the other zero page temporaries (zsx, zt2, ...) while the main loop runs
NoiseRestore:
        lda #<NZ_BMP
        sta zdb
        lda #>NZ_BMP
        sta zdb+1
        ldx #31
        ldy #0
!:      jsr Random
        sta (zdb),y
        iny
        bne !-
        inc zdb+1
        dex
        bne !-
!:      jsr Random              // the last page up to $fff9
        sta (zdb),y
        iny
        cpy #$fa
        bne !-
        lda #0                  // Z set
        rts

fr_hold:    .byte 0
fr_k:       .byte 0             // steps played
fr_done:    .byte 0
fr_n:       .byte 0
fr_n8:      .byte 0
