//==============================================================================
// Freddy's smile (F in the office): the poster's Freddy smiles while his nose honks (SFX_HONK on voice 3).
// The smile is 4 hires cells of the office picture (columns 15-16, rows 8-9, from assets/office/freddy_smile.png);
// it goes when the honk is over, when another effect takes voice 3, or when the game leaves the office / monitor
// modes (power out, jumpscare, ...: the poster is put back before anything is loaded over the office buffer).
//==============================================================================
.const SM_LEN   = 22                    // frames: the honk's 12 + its release
.const SM_NORM  = 36                    // smile_data offset of the office's own cells

// Called every frame from IrqTick while the game is not paused.
SmileTick:
#if TEST
        lda tk_c                        // bit 6: the F key
        and #$40
#else
        lda #$fb                        // F: column 2, row 5
        sta $dc00
        lda $dc01
        and #$20
        eor #$20
        ldx #$ff
        stx $dc00
#endif
        ldx f_prev
        sta f_prev
        cpx #0
        bne sm_run                      // key still held: not a new press
        cmp #0
        beq sm_run
        lda mode                        // only in the office, during the night
        cmp #M_OFFICE
        bne sm_run
        lda g_act
        beq sm_run
        lda #SFX_HONK
        jsr SndStart
        lda #$05                        // 31 % pulse from the first frame
        sta $d411
        lda #SM_LEN
        sta sm_t
        ldx #0
        jmp SmileDraw
sm_run: lda sm_t
        beq sm_ret
        lda sfx_id                      // another effect took voice 3: the honk is over
        cmp #SFX_HONK
        bne sm_end
        lda mode
        cmp #M_SWITCH+1
        bcs sm_end
        lda sm_t                        // the rasp: the pulse width wobbles between 25 % and 37 % at 12.5 Hz
        and #2
        ora #4
        sta $d411
        dec sm_t
        bne sm_ret
sm_end: lda #0
        sta sm_t
        ldx #SM_NORM
// X = 0: the smile, SM_NORM: the office's own cells
SmileDraw:
        ldy #0
!:      lda smile_data,x
        sta OFF_BMP + (8 * 40 + 15) * 8,y
        lda smile_data + 16,x
        sta OFF_BMP + (9 * 40 + 15) * 8,y
        inx
        iny
        cpy #16
        bne !-
        lda smile_data + 16,x
        sta OFF_SCR + 8 * 40 + 15
        lda smile_data + 17,x
        sta OFF_SCR + 8 * 40 + 16
        lda smile_data + 18,x
        sta OFF_SCR + 9 * 40 + 15
        lda smile_data + 19,x
        sta OFF_SCR + 9 * 40 + 16
sm_ret: rts

smile_data: .import binary "../build/gen/smile.bin"
