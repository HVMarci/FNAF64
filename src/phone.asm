//==============================================================================
// Phone Guy: an automatic call at the start of nights 1-5 with subtitles.
//
// The call text (one file per night, see tools/gen_assets.py) is loaded to PHONE_BUF when the
// night starts. The frame tick (PhoneTick) walks through it: ring, then one subtitle line at a
// time with a sawtooth "mumble" blip every few frames, then a click. The subtitle is text row 24
// shown from bank 1 (LAY_SUB); the main loop (SubDraw) plots the characters into that row of
// the camera bitmap buffer. M mutes the call.
//==============================================================================
PhoneStart:                     // the night has begun
        lda #0
        sta ph_st
        sta sub_on
        lda g_night
        cmp #6
        bcs phs_ret             // night 6: nobody calls
        lda #<PHONE_BUF
        sta ph_ptr
        lda #>PHONE_BUF
        sta ph_ptr+1
        lda #1
        sta ph_st
        lda #150                // 3 s of quiet, then it rings
        sta ph_tm
phs_ret:
        rts

PhoneStop:                      // hang up / silence (death, power out, morning, mute)
        lda #0
        sta ph_st
        lda sub_on
        beq phx_ret
        lda #0
        sta sub_on
SubClear:
        ldx #39
        lda #32
!:      sta sub_buf,x
        dex
        bpl !-
        lda #$ff
        sta sub_buf+40
        lda #1
        sta sub_req
phx_ret:
        rts

// A = characters, ph_src -> screen codes: centre them in the subtitle row and show it
PutSub:
        sta sub_len
        ldx #39
        lda #32
!:      sta sub_buf,x
        dex
        bpl !-
        lda #$ff
        sta sub_buf+40
        lda #40
        sec
        sbc sub_len
        lsr
        tax
        ldy #0
!:      lda (ph_src),y
        sta sub_buf,x
        inx
        iny
        cpy sub_len
        bne !-
        lda #1
        sta sub_on
        sta sub_req
        rts

PhoneTick:
        lda ph_st
        beq ph_ret
        lda g_act
        beq ph_stop
        lda mode
        cmp #M_POWER
        bcs ph_stop
        lda ev
        and #EV_MUTE
        beq ph_go
        lda #SFX_CLICK          // the player hangs up
        jsr SndStart
ph_stop:
        jmp PhoneStop
ph_go:  lda ph_st
        cmp #2
        beq ph_ring
        cmp #3
        beq ph_talk
        dec ph_tm               // waiting for the phone to ring
        bne ph_ret
        lda #2
        sta ph_st
        lda #3
        sta ph_rings
        lda #0
        sta ph_tm
ph_ret: rts

ph_ring:
        lda ph_tm
        bne pr_dec
        lda ph_rings
        beq pr_done
        dec ph_rings
        lda #60
        sta ph_tm
        lda #SFX_RING
        jsr SndStart
        lda #<str_ring
        sta ph_src
        lda #>str_ring
        sta ph_src+1
        lda #8
        jsr PutSub
pr_dec: dec ph_tm
        lda ph_tm
        cmp #34
        bcc ph_ret
        lda frame               // warble while the burst lasts
        and #2
        beq pr_lo
        lda #$3c
        sta sfx_fh
        rts
pr_lo:  lda #$2c
        sta sfx_fh
        rts
pr_done:
        lda #3
        sta ph_st
        lda #1
        sta ph_tm               // start speaking on the next frame
        jmp SubClear2

SubClear2:                      // blank subtitle, overlay off
        lda #0
        sta sub_on
        jmp SubClear

ph_talk:
        dec ph_tm
        beq ph_next
        lda sub_on
        beq ph_ret              // silence
        lda ph_tm
        cmp #14
        bcc ph_ret
        and #3
        bne ph_ret
        jmp SndBlip
ph_next:
        ldy #0
        lda (ph_ptr),y
        beq ph_end
        bmi ph_pause
        pha                     // a subtitle line of A characters
        lda ph_ptr
        clc
        adc #1
        sta ph_src
        lda ph_ptr+1
        adc #0
        sta ph_src+1
        pla
        pha
        jsr PutSub
        pla
        sta ph_tm               // shown for 0.6 s + 80 ms per character
        asl
        asl
        clc
        adc #30
        sta ph_tm
        lda sub_len
        sec                     // ph_ptr += n + 1
        adc ph_ptr
        sta ph_ptr
        bcc !+
        inc ph_ptr+1
!:      rts
ph_pause:
        and #$7f
        tax
        lda #0
!:      clc
        adc #20
        dex
        bne !-
        sta ph_tm
        inc ph_ptr
        bne !+
        inc ph_ptr+1
!:      jmp SubClear2
ph_end: lda #SFX_CLICK
        jsr SndStart
        jmp PhoneStop

//------------------------------------------------------------------------------
// Subtitle row, main loop side: plot sub_buf into row 24 of the camera bitmap buffer
// (bitmap $7e00, screen $47c0); the pixels of a camera picture there are simply lost.
//------------------------------------------------------------------------------
SubDraw:
        lda sub_req
        beq sd_ret
        lda #0
        sta sub_req
        lda #$60
        sta tbmp_hi
        lda #$44
        sta tscr_hi
        lda #$10
        sta hcol
        lda #<sub_buf
        sta zsrc
        lda #>sub_buf
        sta zsrc+1
        ldx #0
        ldy #24
        jmp DrawH
sd_ret: rts

// frame tick: show the subtitle row in place of row 24 of whatever the mode displays
SubOverlay:
        lda sub_on
        beq so_ret
        lda g_act
        beq so_ret
        lda mode
        cmp #M_CARD
        bcs so_ret
        lda #LAY_SUB
        sta rowlayer+24
        lda #0
        sta rowxs+24
so_ret: rts

.segment Code4
str_ring:   .encoding "screencode_upper"
            .text "* RING *"
.segment Code2
