//==============================================================================
// Pause (P): freezes the night clock, the animatronics, the phone call, the state machine and the
// sound; the display keeps running. Only while playing (office / camera monitor). The border turns red.
//==============================================================================

// Called every frame from IrqTick after the keys are scanned; returns Z clear while the game is paused.
PauseLogic:
        lda p_key
        ldx p_prev
        sta p_prev
        cpx #0
        bne pl_done             // key still held: not a new press
        cmp #0
        beq pl_done
        lda g_pause
        bne pl_off
        lda mode                // pause only in the office (0) or on the cameras (1)
        cmp #M_CAM+1
        bcs pl_done
        lda g_act
        beq pl_done
        lda #1
        sta g_pause
        lda mode                // M_OFFICE / M_CAM are also LAY_OFFICE / LAY_CAM: show the plain picture
        jsr SetAll              // (no glitch rows or static frozen into the pause screen)
        lda #$10                // low-pass, volume 0
        sta $d418
        lda #2                  // red border
        sta $d020
        bne pl_done
pl_off: lda #0
        sta g_pause
        sta $d020
        lda #$1f                // low-pass, volume 15 (SndInit)
        sta $d418
pl_done:
        lda g_pause
        rts
