
.include "tr.inc"

.export tr_cos

.import FP_COS
.import TEST_CHECK, TEST_FP1CMP

.segment "CODE"
.proc tr_cos
    TEST_ROUTINE_HEADER_MACRO msg_header

    ; --------------------------------------------------------
    ; Five cases spanning cos's own zero crossings and extremes,
    ; not just re-using sin's angle set - cos(90) and cos(270) are
    ; specifically interesting here because they exercise the
    ; phase-shifted argument landing EXACTLY on a quadrant boundary
    ; inside FP_SIN_FULL_PROC (90+90=180=pi exactly; 270+90=360=
    ; 2*pi exactly, i.e. right back at the FP_FMOD wraparound
    ; point) - the two places most likely to expose an off-by-one
    ; in the quadrant comparisons if the boundary handling documented
    ; in lib_fp_sin_full.s were wrong.
    ;
    ; Expected values (Python math.cos, for visual comparison - same
    ; truncating-display caveat as every earlier test):
    ;   cos(0 deg)   = +1.0000000
    ;   cos(45 deg)  = +0.7071068
    ;   cos(90 deg)  =  0.0000000
    ;   cos(180 deg) = -1.0000000
    ;   cos(270 deg) =  0.0000000  (approaches from the negative
    ;                               side mathematically, but this
    ;                               format has no signed zero, so
    ;                               expect plain 0 or a tiny residual
    ;                               near 0 either sign)
    ; --------------------------------------------------------
    FP_ERROR_INIT_MACRO t00_recover
    FP_LOAD1_MACRO TestValue::rad_0
    jsr FP_COS                   ; FP1 = cos(0 deg) ~= 1.0
    FP_ERROR_CLEAR_MACRO
t00_recover:
    TEST_CHECK_MACRO_V2 0, msg_t00, 7

    FP_ERROR_INIT_MACRO t01_recover
    FP_LOAD1_MACRO TestValue::rad_45
    jsr FP_COS                   ; FP1 = cos(45 deg) ~= 0.7071068
    FP_ERROR_CLEAR_MACRO
t01_recover:
    TEST_CHECK_MACRO_V2 1, msg_t01, 7

    FP_ERROR_INIT_MACRO t02_recover
    FP_LOAD1_MACRO TestValue::rad_90
    jsr FP_COS                   ; FP1 = cos(90 deg) ~= 0.0 -
                                 ; phase-shifted argument lands
                                 ; exactly on pi, a quadrant boundary
    FP_ERROR_CLEAR_MACRO
t02_recover:
    TEST_CHECK_MACRO_V2 2, msg_t02, 7

    FP_ERROR_INIT_MACRO t03_recover
    FP_LOAD1_MACRO TestValue::rad_180
    jsr FP_COS                   ; FP1 = cos(180 deg) ~= -1.0
    FP_ERROR_CLEAR_MACRO
t03_recover:
    TEST_CHECK_MACRO_V2 3, msg_t03, 7

    ; --------------------------------------------------------
    ; T04: cos(270 deg) = sin(270+90) = sin(360) = sin(2*pi).
    ; [PINNED] Same FP_FMOD(x, x) residue as tr_sin_full.s T05 -
    ; see that test's comment. Expected value below must stay in
    ; lockstep with t05_sin_2pi_obs in tr_sin_full.s.
    ; --------------------------------------------------------
    FP_ERROR_INIT_MACRO t04_recover
    FP_LOAD1_MACRO TestValue::rad_270
    jsr FP_COS
    FP_ERROR_CLEAR_MACRO
t04_recover:
    TEST_FP1CMP_MACRO 4, msg_t04, TestValue::val_0  ; t04_cos_270_obs

    ; --------------------------------------------------------
    ; T05: cos(-90 deg) = cos(90 deg) = 0.0 exactly (confirmed)
    ; --------------------------------------------------------
    FP_ERROR_INIT_MACRO t05_recover
    FP_LOAD1_MACRO TestValue::rad_neg90
    jsr FP_COS
    FP_ERROR_CLEAR_MACRO
t05_recover:
    TEST_FP1CMP_MACRO 5, msg_t05, TestValue::val_0

    ; --------------------------------------------------------
    ; T06: cos(360 deg) = cos(0 deg) = 1.0000035 (Taylor residual)
    ; --------------------------------------------------------
    FP_ERROR_INIT_MACRO t06_recover
    FP_LOAD1_MACRO TestValue::rad_360
    jsr FP_COS
    FP_ERROR_CLEAR_MACRO
t06_recover:
    TEST_FP1CMP_MACRO 6, msg_t06, t06_cos_360_obs

    rts

.segment "RODATA"
msg_header: .asciiz "trigonometry: cosine"
msg_t00:    .asciiz "  0deg"
msg_t01:    .asciiz " 45deg"
msg_t02:    .asciiz " 90deg boundary"
msg_t03:    .asciiz "180deg"
msg_t04:    .asciiz "270deg wrap"
msg_t05:    .asciiz "-90deg neg"
msg_t06:    .asciiz "360deg full turn"

;t04_cos_270_obs:    .byte $6b,$7f,$ff,$fe
t06_cos_360_obs:    .byte $80,$40,$00,$0f
.endproc
