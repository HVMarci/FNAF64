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
.label kit_ring   = sndvars+8   // ring-modulated kitchen hit: voice 2 is its modulator (1), or the noise clack still plays (2, 3)
.label kit_q      = sndvars+9
.label scream_t   = sndvars+10  // frames left of the jumpscare scream (it owns all three voices)

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
        lda scream_t
        beq st_am0
        jsr Random              // the filter cutoff jumps around every frame: the screech wanders between 2 and 4 kHz
        and #$1f
        clc
        adc #$0e
        sta $d416
        jsr Random              // voice 1 jitters around 2.3 kHz
        and #$3f
        clc
        adc #$80
        sta $d401
        lda scream_t            // fade out over the last 15 frames
        cmp #16
        bcc !+
        lda #15
!:      ora #$40
        sta $d418
        dec scream_t
        bne st_sr
        jmp ScreamEnd
st_sr:  rts
st_am0: lda mel_id
        beq st_nomel
        jmp MelTick
st_nomel:
        lda kit_ring
        beq st_kn
        cmp #2
        bcc st_k1
        dec kit_ring
        cmp #3
        beq st_k1               // the clack lasts two frames
        lda sfx_wave
        sta $d412               // then the ring-modulated tone
st_k1:  lda sfx_left
        bne st_ret              // the hit owns voice 2 until it has died away
        lda #0
        sta kit_ring
        lda #$ff
        sta amb2_cur            // then voice 2 goes back to the ambient sound
st_kn:  lda amb2_cur
        cmp #$fe                // just after a melody: re-initialise the ambient voice
        bne st_amb2
        lda #$ff
        sta amb2_cur
st_amb2:
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
// One "syllable" of the phone guy's mumble: a very short sawtooth blip at a random voice-like pitch
// (skipped while another effect owns voice 3)
//------------------------------------------------------------------------------
SndBlip:
        lda sfx_left
        bne sb_ret
        jsr Random
        and #$0f
        clc
        adc #$0a
        sta sfx_fh
        sta $d40f
        lda #0
        sta sfx_fl
        sta sfx_dl
        sta sfx_dh
        sta $d40e
        lda #$21
        sta sfx_wave
        lda #$03
        sta $d413
        lda #$00
        sta $d414
        lda #3
        sta sfx_left
        lda #$20
        sta $d412
        lda #$21
        sta $d412
sb_ret: rts

//------------------------------------------------------------------------------
// Melodies on voice 2 (triangle "music box"): notes are (freq lo, freq hi, frames),
// a zero length ends the tune (loops if mel_loop is set)
//------------------------------------------------------------------------------
MelStart:                       // A = MEL_*
        sta mel_id
        tax
        lda mel_lo-1,x
        sta mel_ptr
        lda mel_hi-1,x
        sta mel_ptr+1
        lda mel_lp-1,x
        sta mel_loop
        lda mel_wv-1,x
        sta mel_wave
        lda #0
        sta mel_left
        lda #$fe
        sta amb2_cur
        rts

MelTick:
        lda mel_left
        beq mt_next
        dec mel_left
        bne mt_ret
        lda mel_wave            // gate off between notes
        and #$fe
        sta $d40b
        rts
mt_next:
        ldy #2
        lda (mel_ptr),y
        bne mt_note
        lda mel_loop            // end of the tune
        beq mt_stop
        ldx mel_id
        lda mel_lo-1,x
        sta mel_ptr
        lda mel_hi-1,x
        sta mel_ptr+1
        rts
mt_stop:
        jmp MelStop
mt_note:
        sta mel_left
        ldy #0
        lda (mel_ptr),y
        sta $d407
        iny
        lda (mel_ptr),y
        sta $d408
        ldx mel_id
        lda mel_ad-1,x
        sta $d40c
        lda mel_sr-1,x
        sta $d40d
        lda mel_wave
        and #$fe
        sta $d40b
        lda mel_wave
        sta $d40b
        clc
        lda mel_ptr
        adc #3
        sta mel_ptr
        bcc mt_ret
        inc mel_ptr+1
mt_ret: rts

MelStop:
        lda #0
        sta mel_id
        lda #$fe                // ambient voice is re-initialised on the next tick
        sta amb2_cur
        lda #$10
        sta $d40b
        rts

// per tune: waveform (gate bit set), attack / decay, sustain / release -> plucked bell and music box
mel_wv:     .byte $41, $11
mel_ad:     .byte $0a, $07
mel_sr:     .byte $08, $06
mel_lo:     .byte <tune_chime, <tune_box
mel_hi:     .byte >tune_chime, >tune_box
mel_lp:     .byte 0, 1
// note frequencies (PAL): SID value = Hz * 2^24 / 985248
.function sidhz(hz) { .return round(hz * 16777216 / 985248) }
.const N_E5  = sidhz(659.26)
.const N_Fs5 = sidhz(739.99)
.const N_Gs5 = sidhz(830.61)
.const N_B4  = sidhz(493.88)
.const N_Fs4 = sidhz(369.99)
.const N_Gs4 = sidhz(415.30)
.const N_As4 = sidhz(466.16)
.const N_Cs5 = sidhz(554.37)
.const N_Ds5 = sidhz(622.25)
.macro Note(f, n) { .byte <f, >f, n }
.segment Code3
// 6 AM: the Westminster chime (E C D G - G D E C in C; here G# E F# B - B F# G# E in E major, as in the original clock)
tune_chime:
        Note(N_Gs5, 20)
        Note(N_E5, 20)
        Note(N_Fs5, 20)
        Note(N_B4, 50)
        Note(N_B4, 20)
        Note(N_Fs5, 20)
        Note(N_Gs5, 20)
        Note(N_E5, 90)
        .byte 0, 0, 0
// Freddy's music box: the Toreador March as the music box plays it (Bizet, "Carmen"): the refrain, the
// modulating middle part and the run that leads back to the start, 47 beats, F# major like the original recording.
// Pitches and rhythm come from a music-box MIDI transcription (melody line only, transposed to the recording's
// key); one beat = 28 frames (0.56 s PAL, the tempo of the original). The tune loops seamlessly.
.function nhz(m) { .return round(440 * pow(2, (m - 69) / 12) * 16777216 / 985248) }
tune_box:
        Note(nhz(73), 28)        // C#5  (beat 0.00)
        Note(nhz(75), 21)        // D#5  (beat 1.00)
        Note(nhz(73), 7)        // C#5  (beat 1.75)
        Note(nhz(70), 28)        // A#4  (beat 2.00)
        Note(nhz(70), 28)        // A#4  (beat 3.00)
        Note(nhz(70), 21)        // A#4  (beat 4.00)
        Note(nhz(68), 7)        // G#4  (beat 4.75)
        Note(nhz(70), 21)        // A#4  (beat 5.00)
        Note(nhz(71), 7)        // B4  (beat 5.75)
        Note(nhz(70), 49)        // A#4  (beat 6.00)
        Note(nhz(71), 28)        // B4  (beat 7.75)
        Note(nhz(68), 21)        // G#4  (beat 8.75)
        Note(nhz(73), 7)        // C#5  (beat 9.50)
        Note(nhz(70), 49)        // A#4  (beat 9.75)
        Note(nhz(66), 28)        // F#4  (beat 11.50)
        Note(nhz(63), 21)        // D#4  (beat 12.50)
        Note(nhz(68), 7)        // G#4  (beat 13.25)
        Note(nhz(61), 49)        // C#4  (beat 13.50)
        Note(nhz(68), 56)        // G#4  (beat 15.25)
        Note(nhz(68), 14)        // G#4  (beat 17.25)
        Note(nhz(68), 14)        // G#4  (beat 17.75)
        Note(nhz(75), 14)        // D#5  (beat 18.25)
        Note(nhz(73), 14)        // C#5  (beat 18.75)
        Note(nhz(71), 14)        // B4  (beat 19.25)
        Note(nhz(70), 14)        // A#4  (beat 19.75)
        Note(nhz(68), 14)        // G#4  (beat 20.25)
        Note(nhz(70), 14)        // A#4  (beat 20.75)
        Note(nhz(71), 14)        // B4  (beat 21.25)
        Note(nhz(70), 49)        // A#4  (beat 21.75)
        Note(nhz(65), 28)        // F4  (beat 23.50)
        Note(nhz(70), 28)        // A#4  (beat 24.50)
        Note(nhz(70), 28)        // A#4  (beat 25.50)
        Note(nhz(69), 14)        // A4  (beat 26.50)
        Note(nhz(72), 14)        // C5  (beat 27.00)
        Note(nhz(77), 91)        // F5  (beat 27.50)
        Note(nhz(75), 7)        // D#5  (beat 30.75)
        Note(nhz(77), 7)        // F5  (beat 31.00)
        Note(nhz(75), 28)        // D#5  (beat 31.25)
        Note(nhz(75), 14)        // D#5  (beat 32.25)
        Note(nhz(68), 14)        // G#4  (beat 32.75)
        Note(nhz(70), 14)        // A#4  (beat 33.25)
        Note(nhz(71), 28)        // B4  (beat 33.75)
        Note(nhz(70), 7)        // A#4  (beat 34.75)
        Note(nhz(71), 7)        // B4  (beat 35.00)
        Note(nhz(70), 14)        // A#4  (beat 35.25)
        Note(nhz(66), 14)        // F#4  (beat 35.75)
        Note(nhz(75), 14)        // D#5  (beat 36.25)
        Note(nhz(73), 49)        // C#5  (beat 36.75)
        Note(nhz(66), 7)        // F#4  (beat 38.50)
        Note(nhz(68), 7)        // G#4  (beat 38.75)
        Note(nhz(66), 14)        // F#4  (beat 39.00)
        Note(nhz(71), 28)        // B4  (beat 39.50)
        Note(nhz(70), 28)        // A#4  (beat 40.50)
        Note(nhz(68), 28)        // G#4  (beat 41.50)
        Note(nhz(66), 28)        // F#4  (beat 42.50)
        Note(nhz(56), 7)        // G#3  (beat 43.50)
        Note(nhz(58), 7)        // A#3  (beat 43.75)
        Note(nhz(60), 7)        // C4  (beat 44.00)
        Note(nhz(61), 7)        // C#4  (beat 44.25)
        Note(nhz(63), 7)        // D#4  (beat 44.50)
        Note(nhz(65), 7)        // F4  (beat 44.75)
        Note(nhz(66), 7)        // F#4  (beat 45.00)
        Note(nhz(68), 7)        // G#4  (beat 45.25)
        Note(nhz(70), 7)        // A#4  (beat 45.50)
        Note(nhz(68), 7)        // G#4  (beat 45.75)
        Note(nhz(70), 7)        // A#4  (beat 46.00)
        Note(nhz(71), 7)        // B4  (beat 46.25)
        Note(nhz(73), 7)        // C#5  (beat 46.50)
        Note(nhz(75), 14)        // D#5  (beat 46.75)
        .byte 0, 0, 0

.segment Code3

//------------------------------------------------------------------------------
// effect table: freq lo/hi, delta lo/hi (16 bit signed per frame), wave, AD, SR, frames
.segment Code4
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
        // 5 footstep: short low thud
        .word $0b00, $ff90
        .byte $81, $04, $00, 9
        // 6 Freddy's laugh: wobbling sawtooth sweeping down
        .word $2600, $ffa0
        .byte $21, $05, $a0, 34
        // 7 sting: shrill pulse rising (seeing somebody in the doorway)
        .word $5800, $0140
        .byte $41, $00, $f0, 18
        // 8 scream: long harsh noise
        .word $2800, $0030
        .byte $81, $00, $f0, 150
        // 9 power down: falling saw
        .word $3800, $ff70
        .byte $21, $0a, $f8, 60
        // 10 pans clattering: bright noise crash (the pitch is randomised by KitchenHit)
        .word $7000, $0000
        .byte $81, $03, $03, 5
        // 11 groan: low growl
        .word $0700, $0006
        .byte $21, $06, $b0, 40
        // 12 knock: door bang, shorter
        .word $1400, $ff60
        .byte $81, $08, $00, 10
        // 13 phone ring burst (the frame tick alternates the pitch while it lasts)
        .word $3400, $0000
        .byte $41, $00, $c0, 26
        // 14 receiver click
        .word $5000, $fe00
        .byte $81, $00, $00, 4
        // 15 pot clang: triangle ring-modulated by voice 2 (KitchenHit sets both pitches): inharmonic, metallic
        .word $3000, $0000
        .byte $15, $06, $05, 5
        // 16 / 17 the same two, quiet: no decay, a low sustain level (the 8 ms attack peak is the clang)
        .word $4000, $0000
        .byte $81, $00, $33, 5
        .word $3000, $0000
        .byte $15, $00, $46, 5

.segment Code3

//               off  buzz  hiss
amb_wave:   .byte $40, $41, $80
amb_ad:     .byte $00, $00, $00
amb_sr:     .byte $00, $70, $40
amb_fl:     .byte $00, $a7, $00
amb_fh:     .byte $00, $06, $30
buzz_fl:    .byte $a7, $b9

// ---- jumpscare scream: as loud as the SID goes. Imitates the original scream (about 80 % of its energy at 1.6-3.2 kHz, an unsteady cluster of peaks, constant level): noise on voices 2 and 3 plus a jittering sawtooth on voice 1, all through the resonant band-pass filter whose cutoff jumps every frame, at
// full sustain and nothing routed through the filter; the ambient sounds stay off until ScreamEnd.
.segment Code3
SndScream:
        lda #SFX_SCREAM
        jsr SndStart            // voice 3: noise
        lda #$f7                // all three voices through the filter, resonance 15
        sta $d417
        lda #$4f                // band-pass, volume 15
        sta $d418
        lda #0
        sta $d415
        sta $d40c               // voice 2: noise, no attack, full sustain
        sta $d407
        sta $d405               // voice 1: sawtooth, no attack, full sustain
        sta $d400
        lda #$24
        sta $d416
        lda #$f0
        sta $d40d
        sta $d406
        lda #$c0
        sta $d408
        lda #$98
        sta $d401
        lda #$80
        sta $d40b
        lda #$81
        sta $d40b
        lda #$20
        sta $d404
        lda #$21
        sta $d404
        lda #150
        sta scream_t
        rts

ScreamEnd:                      // back to the fan hum (voice 1, low-pass filtered) and the ambient voice 2
        lda #$01
        sta $d417
        lda #$1f
        sta $d418
        lda #$30
        sta $d416
        lda #0
        sta $d400
        sta $d405
        lda #$0c
        sta $d401
        lda #$40
        sta $d406
        lda #$81
        sta $d404
        lda #$ff
        sta amb2_cur
        rts
