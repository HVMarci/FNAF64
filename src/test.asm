//==============================================================================
// Test harness (assembled only with -define TEST): scripted key input and
// snapshot hooks that the VICE monitor turns into screenshots.
//==============================================================================
.label tk_a   = sndvars+16
.label tk_b   = sndvars+17
.label tk_c   = sndvars+18
.label tk_d   = gv+110           // left arrow, 8, 9, 0 (kd_now)
.label snapn  = sndvars+19
.label snapvec= sndvars+20      // 2 bytes
.label tinit  = sndvars+22

TestScript:
        lda tinit
        bne ts_go
        lda #<test_script
        sta tsp
        lda #>test_script
        sta tsp+1
        lda #1
        sta tinit
ts_go:  ldy #0
        lda frame
        cmp (tsp),y             // current - entry (16 bit)
        iny
        lda frameh
        sbc (tsp),y
        bcc ts_ret              // not reached yet
        ldy #2
        lda (tsp),y
        sta tk_a
        iny
        lda (tsp),y
        sta tk_b
        iny
        lda (tsp),y
        sta tk_c
        iny
        lda (tsp),y
        sta tk_d
        iny
        lda (tsp),y
        sta snapn
        lda tsp
        clc
        adc #7
        sta tsp
        bcc !+
        inc tsp+1
!:      lda snapn
        beq ts_ret
        asl
        tax
        lda snap_tab,x
        sta snapvec
        lda snap_tab+1,x
        sta snapvec+1
        jsr SnapJ
ts_ret: rts
SnapJ:  jmp (snapvec)

TestOverride:
        lda tk_a
        sta ka_now
        lda tk_b
        sta kb_now
        lda tk_d
        sta kd_now
        lda tk_c
        and #$1f
        sta kc_now
        lda tk_c                // bit 5: the P key
        and #$20
        sta p_key
        rts

snap_tab:
        .word 0
.for (var i=1; i<=40; i++) {
        .word snapstubs + (i-1)
}
snapstubs:
        .fill 40, $60           // 40 x rts (one per snapshot id)
.import source "../build/test_script.asm"

test_ai:  .byte TEST_AI0, TEST_AI1, TEST_AI2, TEST_AI3
test_pos: .byte TEST_POS0, TEST_POS1, TEST_POS2, TEST_POS3
LoadStartHook: rts
LoadEndHook:   rts
