//==============================================================================
// Game logic: night clock, power, animatronic AI, death and win flow.
//
// GameTick is called from the frame IRQ. It derives a 10 Hz "decisecond" tick
// (independent of PAL / NTSC) and runs GameDs on it. Everything the original
// game does in whole seconds is counted in deciseconds here.
//
// Rules implemented (FNaF 1 wiki / community AI guides):
//  * Every animatronic gets a movement opportunity at a fixed interval
//    (Freddy 3.0 s, the others 5.0 s). It moves if a random number 1..20 is
//    <= its AI level. AI levels per night / hour follow the original tables.
//  * Bonnie: stage -> dining/backstage -> west hall / supply closet -> west
//    hall corner -> left doorway -> office. Wanders randomly, never returns to
//    the stage. Chica: same idea on the right side (kitchen, restrooms, east hall).
//    At the doorway the next successful roll decides: door closed -> they leave
//    (Bonnie to the dining area, Chica to the east hall), door open -> they get in
//    and kill you the next time you lower the monitor (they pull it down
//    themselves if you keep it up).
//  * Freddy walks a fixed path, only while the monitor is down (and only after
//    Bonnie and Chica left the stage). In the east hall corner he enters only
//    when the monitor is up on another camera and the right door is open; if the
//    door is closed he steps back. In the office he kills with 25 % per second
//    while the monitor is down.
//  * Foxy sits in Pirate Cove and advances one stage per successful roll, but
//    only while the monitor is down and his freeze timer (reset every time the
//    monitor is lowered) ran out. Stage 4 is the sprint down the west hall:
//    closed door -> he bangs on it and steals 1 % + 5 % per earlier attack,
//    open door -> jumpscare.
//  * Power: 1 % per 9.6 s at usage 1, faster with every tool in use (monitor,
//    each closed door, each light), plus a passive drain that grows every night.
//    At 0 % the office goes dark and Freddy takes over (music, darkness, scare).
//  * A night is 6 hours of 89.2 s.
//==============================================================================

//------------------------------------------------------------------------------
// Called every frame from IrqTick
//------------------------------------------------------------------------------
GameTick:
        lda g_act
        beq gt_ret
        lda g_dsacc
        clc
        adc #10
        cmp g_fps
        bcc gt_store
        sbc g_fps               // carry is set here
        sta g_dsacc
        jmp GameDs
gt_store:
        sta g_dsacc
gt_ret: rts

//------------------------------------------------------------------------------
// Ten times per second
//------------------------------------------------------------------------------
GameDs:
        // ---- clock
        lda g_hds
        bne gd_h1
        dec g_hds+1
gd_h1:  dec g_hds
        lda g_hds
        ora g_hds+1
        bne gd_clk
        jsr HourPassed
        lda g_act
        bne gd_clk
        rts
gd_clk: jsr UsageCalc
        jsr PowerTick
        lda mode
        cmp #M_POWER
        bcs gd_pwr              // power out sequence: only Freddy's timers run
        jmp AiTick
gd_pwr: lda ps_tm
        beq !+
        dec ps_tm
!:      rts

HourPassed:
        inc g_hour
        lda #<HOUR_DS
        sta g_hds
        lda #>HOUR_DS
        sta g_hds+1
        lda hud_dirty
        ora #3
        sta hud_dirty
        lda g_hour
        cmp #6
        bcc !+
        jmp WinNight
!:      cmp #2
        bne hp3
        ldx g_night
        lda bump2_tab-1,x       // 2 AM: Bonnie +1 (not on night 2)
        beq hp_ret
        inc ai_lvl+1
        rts
hp3:    cmp #3
        beq hp34
        cmp #4
        bne hp_ret
hp34:   inc ai_lvl+1            // 3 AM and 4 AM: Bonnie, Chica, Foxy +1
        inc ai_lvl+2
        inc ai_lvl+3
hp_ret: rts

//------------------------------------------------------------------------------
// Power usage (1 + tools) and drain
//------------------------------------------------------------------------------
UsageCalc:
        ldy #1
        lda mode
        cmp #M_UP
        beq uc_mon
        cmp #M_CAM
        beq uc_mon
        cmp #M_SWITCH
        bne uc_d
uc_mon: iny
uc_d:   lda dstate
        cmp #DS_CLOSING
        beq uc_d1
        cmp #DS_CLOSED
        bne uc_d2
uc_d1:  iny
uc_d2:  lda dstate+1
        cmp #DS_CLOSING
        beq uc_d3
        cmp #DS_CLOSED
        bne uc_l
uc_d3:  iny
uc_l:   lda lwant
        beq uc_l2
        iny
uc_l2:  lda lwant+1
        beq uc_st
        iny
uc_st:  cpy g_usage
        beq uc_ret
        sty g_usage
        lda hud_dirty
        ora #3
        sta hud_dirty
uc_ret: rts

PowerTick:
        lda g_power
        beq pt_ret
        lda g_pacc
        clc
        adc g_usage
        cmp #96                 // 1 % per 9.6 s at usage 1
        bcc pt_s
        sbc #96
        pha
        jsr PowerDec
        pla
pt_s:   sta g_pacc
        ldx g_night             // passive drain that gets faster every night
        lda pass_tab-1,x
        beq pt_np
        inc g_ppass
        lda g_ppass
        cmp pass_tab-1,x
        bcc pt_np
        lda #0
        sta g_ppass
        jsr PowerDec
pt_np:  lda g_power
        bne pt_ret
        jmp StartPowerOut
pt_ret: rts

PowerDec:                       // one percent less, never below zero
        lda g_power
        beq pd_ret
        dec g_power
        lda hud_dirty
        ora #3
        sta hud_dirty
pd_ret: rts

DrainPower:                     // A = percent to take (Foxy)
        sta g_gt
dp_lp:  lda g_gt
        beq dp_done
        dec g_gt
        jsr PowerDec
        jmp dp_lp
dp_done:
        lda g_power
        bne dp_ret
        jmp StartPowerOut
dp_ret: rts

//------------------------------------------------------------------------------
// Helpers
//------------------------------------------------------------------------------
MonUp:                          // C set while the monitor is up (or coming up)
        lda mode
        cmp #M_UP
        beq mu_y
        cmp #M_CAM
        beq mu_y
        cmp #M_SWITCH
        beq mu_y
        clc
        rts
mu_y:   sec
        rts

RollAi:                         // X = animatronic; C set if random(1..20) <= level
ra1:    jsr Random
        and #31
        cmp #20
        bcs ra1
        cmp ai_lvl,x
        bcc ra_ok
        clc
        rts
ra_ok:  sec
        rts

//------------------------------------------------------------------------------
// Animatronics
//------------------------------------------------------------------------------
AiTick:
        ldx #3
at_lp:  lda ai_lvl,x
        beq at_next
        dec ai_tm,x
        bne at_next
        lda per_tab,x
        sta ai_tm,x
        stx g_gt+1
        jsr RollAi
        ldx g_gt+1
        bcc at_next
        jsr AiMove
        ldx g_gt+1
at_next:
        dex
        bpl at_lp
        jmp AiEveryDs

AiMove:                         // X = animatronic
        cpx #1
        bne !+
        jmp MoveBonnie
!:      cpx #2
        bne !+
        jmp MoveChica
!:      cpx #3
        bne !+
        jmp MoveFoxy
!:      // ---- Freddy
        lda ai_pos
        bne mf_p1
        lda ai_pos+1            // stays on stage until Bonnie and Chica left
        beq mf_ret
        lda ai_pos+2
        beq mf_ret
        jsr MonUp
        bcc mf_go0
        lda cam_cur             // not while somebody watches the stage
        beq mf_ret
mf_go0: lda #1
        jmp FreddyTo
mf_p1:  cmp #7
        beq mf_corner
        cmp #12
        beq mf_ret
        jsr MonUp
        bcs mf_ret              // he only walks while the monitor is down
        ldx ai_pos
        lda fnext_tab,x
        jmp FreddyTo
mf_corner:
        jsr MonUp
        bcc mf_ret              // monitor down: he waits
        lda cam_cur
        cmp #7
        beq mf_ret              // being watched: he waits
        lda dstate+1
        cmp #DS_CLOSING
        beq mf_back
        cmp #DS_CLOSED
        beq mf_back
        lda #12                 // door open and nobody watching: he is in
        sta ai_pos
        lda #0
        sta fr_tm
        lda #SFX_LAUGH
        jsr SndStart
        lda #1
        sta camdirty
mf_ret: rts
mf_back:
        lda #6
FreddyTo:
        sta ai_pos
        lda #SFX_LAUGH
        jsr SndStart
        lda #1
        sta camdirty
        rts

//---- Bonnie (side 0) and Chica (side 1) share most of their logic
MoveBonnie:
        lda ai_pos+1
        cmp #12
        beq mb_ret
        cmp #11
        bne mb_walk
        lda dstate              // in the doorway: door decides
        cmp #DS_CLOSING
        beq mb_repel
        cmp #DS_CLOSED
        beq mb_repel
        lda #12
        sta ai_pos+1
        ldx #0
        jmp Jam
mb_repel:
        lda #1                  // back to the dining area
        sta ai_pos+1
        jmp BcMoved
mb_walk:
        ldx #0
        jmp BcWalk
mb_ret: rts

MoveChica:
        lda ai_pos+2
        cmp #12
        beq mc_ret
        cmp #11
        bne mc_walk
        lda dstate+1
        cmp #DS_CLOSING
        beq mc_repel
        cmp #DS_CLOSED
        beq mc_repel
        lda #12
        sta ai_pos+2
        ldx #1
        jmp Jam
mc_repel:
        lda #6                  // back to the east hall
        sta ai_pos+2
        jmp BcMoved
mc_walk:
        ldx #1
        jmp BcWalk
mc_ret: rts

// X = side (0 Bonnie / 1 Chica): random step along the adjacency table
BcWalk:
        stx g_gt+2
        lda ai_pos+1,x
        asl
        asl
        cpx #0
        beq bw_b
        clc
        adc #52
bw_b:   tay                     // Y -> row [count, d0, d1, d2]
        lda adj_tab,y
        sta g_gt+3
bw_r:   jsr Random
        and #3
        cmp g_gt+3
        bcs bw_r
        sta g_gt+4
        tya
        clc
        adc g_gt+4
        tay
        lda adj_tab+1,y
        ldx g_gt+2
        sta ai_pos+1,x
BcMoved:
        lda #SFX_STEP
        jsr SndStart
        lda #1
        sta camdirty
        jsr MonUp
        bcc bm_ret
        lda #30                 // the camera feed breaks up when they move
        sta flash
bm_ret: rts

// X = side; the animatronic just got into the office
Jam:
        lda #SFX_STING
        jsr SndStart
        lda #1
        sta camdirty
        jsr MonUp
        bcc jam_ret
        lda #1
        sta g_pkill
        jsr Random
        and #$3f
        clc
        adc #30
        sta g_pull
jam_ret:
        rts

//---- Foxy
MoveFoxy:
        lda ai_pos+3
        cmp #3
        bcs mx_ret              // already sprinting
        jsr MonUp
        bcs mx_ret
        lda fx_frz
        bne mx_ret
        inc ai_pos+3
        lda #1
        sta camdirty
        lda ai_pos+3
        cmp #3
        bne mx_ret
        lda #200                // 20 s until he arrives if nobody watches the hall
        sta fx_run
        lda #0
        sta fx_seen
mx_ret: rts

FoxyArrive:
        lda dstate
        cmp #DS_CLOSING
        beq fa_block
        cmp #DS_CLOSED
        beq fa_block
        lda #3
        jmp StartScare
fa_block:
        lda #0
        sta ai_pos+3
        lda #1
        sta camdirty
        lda #4
        sta knock
        lda #0
        sta knock_tm
        jsr Random              // freeze timer 0.8 .. 16.7 s
        and #$7f
        clc
        adc #8
        sta fx_frz
        lda fx_hits             // 1 %, 6 %, 11 % ...
        asl
        asl
        clc
        adc fx_hits
        adc #1
        inc fx_hits
        jmp DrainPower

//------------------------------------------------------------------------------
// Things that happen every decisecond regardless of the movement rolls
//------------------------------------------------------------------------------
AiEveryDs:
        // door visibility (light shows Bonnie / Chica in the doorway)
        ldx #0
        lda ai_pos+1
        cmp #11
        bne !+
        inx
!:      stx adoor
        ldx #0
        lda ai_pos+2
        cmp #11
        bne !+
        inx
!:      stx adoor+1
        // Foxy freeze counts down while the monitor is down
        jsr MonUp
        bcs ae_fox
        lda fx_frz
        beq ae_fox
        dec fx_frz
ae_fox: lda ai_pos+3
        cmp #3
        bne ae_fr
        lda fx_seen             // sprint noticed on camera 2A: he is much faster
        bne ae_run
        lda mode
        cmp #M_CAM
        bne ae_run
        lda cam_cur
        cmp #3
        bne ae_run
        lda #1
        sta fx_seen
        sta camdirty
        lda fx_run
        cmp #30
        bcc !+
        lda #30
        sta fx_run
!:      lda #SFX_STEP
        jsr SndStart
ae_run: dec fx_run
        bne ae_fr
        jsr FoxyArrive
        lda g_act
        bne ae_fr
        rts
ae_fr:  // Freddy in the office
        lda ai_pos
        cmp #12
        bne ae_pull
        jsr MonUp
        bcs ae_pull
        lda mode                // only with the office fully in view
        bne ae_pull
        inc fr_tm
        lda fr_tm
        cmp #10
        bcc ae_pull
        lda #0
        sta fr_tm
        jsr Random
        and #3
        bne ae_pull             // 25 % per second
        lda #0
        jmp StartScare
ae_pull:
        // Bonnie / Chica in the office pull the monitor down after a while
        jsr MonUp
        bcc ae_knock
        lda g_pkill
        beq ae_knock
        lda groan_tm
        bne ae_g
        lda #25
        sta groan_tm
        lda #SFX_GROAN
        jsr SndStart
        jmp ae_p2
ae_g:   dec groan_tm
ae_p2:  lda g_pull
        beq ae_knock
        dec g_pull
        bne ae_knock
        lda #1
        sta forcedown
ae_knock:
        lda knock               // Foxy bangs on the door four times
        beq ae_kit
        lda knock_tm
        bne ae_kt
        lda #SFX_KNOCK
        jsr SndStart
        lda #5
        sta knock_tm
        dec knock
        jmp ae_kit
ae_kt:  dec knock_tm
ae_kit: lda ai_pos+2            // pots and pans while Chica is in the kitchen
        cmp #9
        bne ae_end
        lda kitchen_tm
        bne ae_kd
        jsr Random
        and #$1f
        clc
        adc #15
        sta kitchen_tm
        lda #SFX_CLATTER
        jmp SndStart
ae_kd:  dec kitchen_tm
ae_end: rts

//------------------------------------------------------------------------------
// Which picture does camera cam_cur show right now?  -> fwant (bundle number)
//------------------------------------------------------------------------------
WantFrame:
        ldx cam_cur
        lda cam_kind,x
        beq wf_stage
        cmp #1
        beq wf_multi
        cmp #2
        beq wf_cove
        cmp #3
        beq wf_2a
        cmp #4
        beq wf_bonnie
        lda #0
        jmp wf_done
wf_stage:
        lda ai_pos              // Freddy gone -> empty stage
        beq !+
        lda #4
        jmp wf_done
!:      lda #3
        ldy ai_pos+2            // Chica still there?
        bne !+
        sec
        sbc #2
!:      ldy ai_pos+1            // Bonnie still there?
        bne !+
        sec
        sbc #1
!:      jmp wf_done
wf_cove:
        lda ai_pos+3
        jmp wf_done
wf_2a:  lda ai_pos+3
        cmp #3
        bne !+
        lda fx_seen
        bne wf_one
!:      lda ai_pos+1
        cmp #3
        beq wf_one
        lda #0
        jmp wf_done
wf_bonnie:
        lda ai_pos+1
        cmp cam_cur
        beq wf_one
        lda #0
        jmp wf_done
wf_one: lda #1
        jmp wf_done
wf_multi:
        ldy #0                  // list the animatronics in this room
        lda ai_pos
        cmp cam_cur
        bne !+
        lda #1
        sta g_gt+5,y
        iny
!:      lda ai_pos+2
        cmp cam_cur
        bne !+
        lda #2
        sta g_gt+5,y
        iny
!:      lda ai_pos+1
        cmp cam_cur
        bne !+
        lda #3
        sta g_gt+5,y
        iny
!:      cpy #0
        beq wf_none
        sty g_gt+4
        lda fmark
wf_mod: cmp g_gt+4
        bcc !+
        sbc g_gt+4
        jmp wf_mod
!:      tay
        lda g_gt+5,y
        jmp wf_done
wf_none:
        lda #0
wf_done:
        ldx cam_cur
        clc
        adc cam_first,x
        sta fwant
        rts

//------------------------------------------------------------------------------
// Night set-up (before the office assets are reloaded)
//------------------------------------------------------------------------------
NewNight:
        jsr MelStop
        jsr PhoneStop
        lda #0
        ldx #$0d
!:      sta dstate,x            // door / light state $30-$3d
        dex
        bpl !-
        sta wdrawn
        sta wdrawn+1
        sta lamp_cur
        sta shake
        sta forcedown
        sta blank
        sta adoor
        sta adoor+1
        sta a_seen
        sta a_seen+1
        sta knock
        sta knock_tm
        sta fx_hits
        sta fx_seen
        sta fx_frz
        sta fr_tm
        sta g_pkill
        sta ps_stage
        sta ps_tm
        sta g_hour
        sta g_dsacc
        sta g_pacc
        sta g_ppass
        sta camdirty
        sta fmark
        sta cam_cur
        sta can_load
        sta ai_pos              // everybody starts on the stage / in the cove
        sta ai_pos+1
        sta ai_pos+2
        sta ai_pos+3
        sta hud_dirty
        lda #1
        sta g_usage
        lda #100
        sta g_power
        lda #<HOUR_DS
        sta g_hds
        lda #>HOUR_DS
        sta g_hds+1
        lda #$ff
        sta cam_loaded
        // AI levels for 12 AM
        lda g_night
        sec
        sbc #1
        asl
        asl
        tay
        ldx #0
!:      lda ai_tab,y
        sta ai_lvl,x
        lda per_tab,x
        sta ai_tm,x
        iny
        inx
        cpx #4
        bne !-
        lda g_night
        cmp #4
        bne nn_ret
        jsr Random              // night 4: Freddy 1 or 2 (50 / 50)
        and #1
        clc
        adc #1
        sta ai_lvl
nn_ret: rts

//------------------------------------------------------------------------------
// Death, power out, win
//------------------------------------------------------------------------------
StartScare:                     // A = who: 0 Freddy, 1 Bonnie, 2 Chica, 3 Foxy
        sta g_who
        jsr MelStop
        jsr PhoneStop
        lda #0
        sta g_act
        sta can_load
        sta blank
        sta sc_ph
        sta tcnt
        sta tph
        sta sprmode
        sta g_pkill
        lda #M_SCARE
        sta mode
        lda #SFX_SCREAM
        jmp SndStart

StartPowerOut:
        jsr PhoneStop
        lda #M_POWER
        sta mode
        lda #0
        sta ps_stage
        sta tcnt
        sta tph
        sta can_load
        sta sprmode
        sta lamp_cur
        sta g_pkill
        ldx #$0d
!:      sta dstate,x            // doors up, lights out (the picture is replaced)
        dex
        bpl !-
        sta wdrawn
        sta wdrawn+1
        sta adoor
        sta adoor+1
        lda #SFX_POWER
        jmp SndStart

WinNight:
        jsr PhoneStop
        lda #0
        sta g_act
        sta can_load
        sta blank
        sta sprmode
        sta tcnt
        sta tph
        lda #M_WIN
        sta mode
        rts

//------------------------------------------------------------------------------
// Night table data (segment Code4)
//------------------------------------------------------------------------------
.segment Code4
.import source "../build/gen/frames.asm"
per_tab:    .byte 30, 50, 50, 50                // Freddy 3.0 s, Bonnie / Chica / Foxy 5.0 s
ai_tab:     .byte 0, 0, 0, 0                    // night 1  (Freddy, Bonnie, Chica, Foxy at 12 AM)
            .byte 0, 3, 1, 1                    // night 2
            .byte 1, 0, 5, 2                    // night 3
            .byte 1, 2, 4, 6                    // night 4  (Freddy: 1 or 2)
            .byte 3, 5, 7, 5                    // night 5
            .byte 4, 10, 12, 16                 // night 6
bump2_tab:  .byte 1, 0, 1, 1, 1, 1              // Bonnie +1 at 2 AM (all nights but the 2nd)
pass_tab:   .byte 0, 255, 240, 200, 180, 180    // passive drain: 1 % every n deciseconds

// Freddy's next room (index = room): 1A>1B>7>6>4A>4B
fnext_tab:  .byte 1, 10, 0, 0, 0, 0, 7, 0, 0, 6, 9
cam_kind:   .byte 0, 1, 2, 3, 4, 4, 1, 1, 4, 5, 1

// Random-walk graph: 13 rows x 4 bytes [count, dest, dest, dest]; Bonnie rows first, Chica after
adj_tab:
        // Bonnie
        .byte 1, 1, 0, 0            //  0 1A -> 1B
        .byte 3, 8, 3, 5            //  1 1B -> backstage / west hall / closet
        .byte 0, 0, 0, 0            //  2
        .byte 2, 5, 4, 0            //  3 2A -> closet / corner
        .byte 3, 11, 5, 3           //  4 2B -> doorway / closet / west hall
        .byte 3, 3, 4, 11           //  5 3  -> west hall / corner / doorway
        .byte 0, 0, 0, 0            //  6
        .byte 0, 0, 0, 0            //  7
        .byte 2, 1, 3, 0            //  8 5  -> dining / west hall
        .byte 0, 0, 0, 0            //  9
        .byte 0, 0, 0, 0            // 10
        .byte 0, 0, 0, 0            // 11
        .byte 0, 0, 0, 0            // 12
        // Chica
        .byte 1, 1, 0, 0            //  0 1A -> 1B
        .byte 2, 10, 9, 0           //  1 1B -> restrooms / kitchen
        .byte 0, 0, 0, 0            //  2
        .byte 0, 0, 0, 0            //  3
        .byte 0, 0, 0, 0            //  4
        .byte 0, 0, 0, 0            //  5
        .byte 2, 7, 1, 0            //  6 4A -> corner / dining
        .byte 2, 11, 6, 0           //  7 4B -> doorway / east hall
        .byte 0, 0, 0, 0            //  8
        .byte 2, 6, 10, 0           //  9 6  -> east hall / restrooms
        .byte 2, 9, 1, 0            // 10 7  -> kitchen / dining
        .byte 0, 0, 0, 0            // 11
        .byte 0, 0, 0, 0            // 12
.segment Code2
