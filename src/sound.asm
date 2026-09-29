//==============================================================================
// SID sound: ambient fan hum (voice 1), light buzz / camera hiss (voice 2),
// one-shot effects (voice 3). Runs from the frame tick (50 Hz).
//==============================================================================
.label sfx_left   = sndvars+0
.label sfx_fl     = sndvars+1
.label sfx_fh     = sndvars+2
.label sfx_dl     = sndvars+3
.label sfx_dh     = sndvars+4
.label sfx_wave   = sndvars+5
.label amb2_cur   = sndvars+6
.label amb2_want  = sndvars+7

SndInit:
        ldx #24
        lda #0
!:      sta $d400,x
        dex
        bpl !-
        lda #$00
        sta $d415
        lda #$30                // low cutoff for the fan rumble
        sta $d416
        lda #$01                // filter voice 1 only
        sta $d417
        lda #$1f                // low-pass, volume 15
        sta $d418
        // voice 1: fan (low frequency noise through the filter)
        lda #$00
        sta $d400
        lda #$0c
        sta $d401
        lda #$00
        sta $d405
        lda #$40
        sta $d406
        lda #$81
        sta $d404
        // pulse widths for voice 2 / 3
        lda #$00
        sta $d402
        sta $d409
        sta $d410
        lda #$08
        sta $d403
        sta $d40a
        sta $d411
        lda #$ff
        sta amb2_cur
        rts

//------------------------------------------------------------------------------
// A = effect id
//------------------------------------------------------------------------------
SndStart:
        asl
        asl
        asl
        tax
        lda sfx_tab+0,x
        sta sfx_fl
        lda sfx_tab+1,x
        sta sfx_fh
        lda sfx_tab+2,x
        sta sfx_dl
        lda sfx_tab+3,x
        sta sfx_dh
        lda sfx_tab+4,x
        sta sfx_wave
        lda sfx_tab+5,x
        sta $d413                // AD
        lda sfx_tab+6,x
        sta $d414               // SR
        lda sfx_tab+7,x
        sta sfx_left
        lda sfx_fl
        sta $d40e
        lda sfx_fh
        sta $d40f
        lda sfx_wave
        and #$fe
        sta $d412               // gate off
        lda sfx_wave
        ora #$01
        sta $d412               // gate on (retrigger)
        rts

//------------------------------------------------------------------------------
SndTick:
        lda sfx_left
        beq st_amb
        dec sfx_left
        clc
        lda sfx_fl
        adc sfx_dl
        sta sfx_fl
        sta $d40e
        lda sfx_fh
        adc sfx_dh
        sta sfx_fh
        sta $d40f
        lda sfx_left
        bne st_amb
        lda sfx_wave            // release
        and #$fe
        sta $d412
st_amb:
        // desired ambient for voice 2: 0 off, 1 light buzz, 2 camera hiss
        lda mode
        cmp #M_CAM
        bne st_notcam
        lda #2
        bne st_set
st_notcam:
        cmp #M_OFFICE
        bne st_off
        lda lwant
        ora lwant+1
        beq st_off
        lda #1
        bne st_set
st_off: lda #0
st_set: cmp amb2_cur
        beq st_vib
        sta amb2_cur
        tax
        lda amb_wave,x
        sta $d40b
        lda amb_ad,x
        sta $d40c
        lda amb_sr,x
        sta $d40d
        lda amb_fl,x
        sta $d407
        lda amb_fh,x
        sta $d408
        lda amb_wave,x
        ora #1
        cpx #0
        bne !+
        and #$fe
!:      sta $d40b
        rts
st_vib: lda amb2_cur
        cmp #1
        bne st_ret
        // 100 Hz buzz with a little flutter
        lda frame
        and #1
        tax
        lda buzz_fl,x
        sta $d407
st_ret: rts

//------------------------------------------------------------------------------
// effect table: freq lo/hi, delta lo/hi (16 bit signed per frame), wave, AD, SR, frames
sfx_tab:
        // door slam: low noise thump sweeping down
        .word $1800, $ff40
        .byte $81, $09, $00, 30
        // camera flip: noise sweeping up (whoosh)
        .word $0800, $0140
        .byte $81, $05, $70, 14
        // blip: short pulse beep
        .word $4400, $0000
        .byte $41, $00, $f0, 6
        // static burst
        .word $5000, $0080
        .byte $81, $00, $c0, 8

        // door servo: quiet low noise sweep
        .word $0500, $0018
        .byte $81, $00, $30, 22

//               off  buzz  hiss
amb_wave:   .byte $40, $41, $80
amb_ad:     .byte $00, $00, $00
amb_sr:     .byte $00, $70, $40
amb_fl:     .byte $00, $a7, $00
amb_fh:     .byte $00, $06, $30
buzz_fl:    .byte $a7, $b9
