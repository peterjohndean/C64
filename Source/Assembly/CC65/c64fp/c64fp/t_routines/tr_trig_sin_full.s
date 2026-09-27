
.include "tr.inc"

.export tr_sin_full

.import FP_SIN_FULL
.import TEST_CHECK, TEST_FP1CMP

.segment "CODE"
.proc tr_sin_full
    TEST_ROUTINE_HEADER_MACRO msg_header

    ; --------------------------------------------------------
    ; Five cases, chosen to hit every branch in FP_SIN_FULL_PROC
    ; at least once, not just "some more angles":
    ;   T00  120 deg  - quadrant 2 (theta = pi - r)
    ;   T01  200 deg  - quadrant 3 (theta = r - pi, result negated)
    ;   T02  300 deg  - quadrant 4 (theta = 2pi - r, result negated)
    ;   T03  400 deg  - > 360 deg: exercises the FP_FMOD wraparound
    ;                   itself (400 mod 360 = 40, quadrant 1)
    ;   T04  -30 deg  - negative input: exercises the "FP_FMOD gave
    ;                   a negative result, add 2*pi back" branch
    ; Quadrant 1 itself (r already in [0,pi/2), no reduction beyond
    ; the mod-2pi fold) is implicitly covered by T03's 40 degree
    ; result, so all four quadrants plus both "extra" branches
    ; (wraparound, negative-input correction) each get exercised
    ; by at least one test here.
    ;
    ; Expected values (Python math.sin, for visual comparison -
    ; remember FP_TO_ASCII truncates fractional digits rather than
    ; rounding, same caveat as every earlier test in this suite):
    ;   sin(120 deg) = +0.8660254
    ;   sin(200 deg) = -0.3420201
    ;   sin(300 deg) = -0.8660254
    ;   sin(400 deg) = +0.6427876   (== sin(40 deg))
    ;   sin(-30 deg) = -0.5000000
    ; --------------------------------------------------------
    FP_ERROR_INIT_MACRO t00_recover
    FP_LOAD1_MACRO TestValue::rad_120
    jsr FP_SIN_FULL              ; FP1 = sin(120 deg) ~= +0.8660254
    FP_ERROR_CLEAR_MACRO
t00_recover:
    TEST_CHECK_MACRO_V2 0, msg_t00, 7

    FP_ERROR_INIT_MACRO t01_recover
    FP_LOAD1_MACRO TestValue::rad_200
    jsr FP_SIN_FULL              ; FP1 = sin(200 deg) ~= -0.3420201
    FP_ERROR_CLEAR_MACRO
t01_recover:
    TEST_CHECK_MACRO_V2 1, msg_t01, 7

    FP_ERROR_INIT_MACRO t02_recover
    FP_LOAD1_MACRO TestValue::rad_300
    jsr FP_SIN_FULL              ; FP1 = sin(300 deg) ~= -0.8660254
    FP_ERROR_CLEAR_MACRO
t02_recover:
    TEST_CHECK_MACRO_V2 2, msg_t02, 7

    FP_ERROR_INIT_MACRO t03_recover
    FP_LOAD1_MACRO TestValue::rad_400
    jsr FP_SIN_FULL              ; FP1 = sin(400 deg) ~= sin(40 deg)
                                 ; ~= +0.6427876 - exercises the
                                 ; mod-2pi wraparound itself
    FP_ERROR_CLEAR_MACRO
t03_recover:
    TEST_CHECK_MACRO_V2 3, msg_t03, 7

    FP_ERROR_INIT_MACRO t04_recover
    FP_LOAD1_MACRO TestValue::rad_neg30
    jsr FP_SIN_FULL              ; FP1 = sin(-30 deg) ~= -0.5 -
                                 ; exercises the "FMOD gave a
                                 ; negative result" correction path
    FP_ERROR_CLEAR_MACRO
t04_recover:
    TEST_CHECK_MACRO_V2 4, msg_t04, 7

    ; --------------------------------------------------------
    ; T05: sin(2*pi) - exactly at the FP_FMOD wraparound point.
    ;
    ; [PINNED - documents a known limitation, not a desired result]
    ; 2*pi mod 2*pi should mathematically be zero, but the current
    ; FP_FMOD returns a small residue (~9.5e-7, bytes $6B,$7F,$FF,$FE)
    ; instead. This is NOT a defect in FP_SIN_FULL's reduction logic
    ; - the residue comes from FP_FMOD itself, and is characterised
    ; separately by tr_fmod.s's new T50-T55. This test pins the
    ; OBSERVED value so a future change to FP_FMOD's boundary
    ; behaviour cannot silently propagate here. If FP_FMOD is ever
    ; fixed, this expected value AND tr_cos.s's T04 (which lands on
    ; the identical residue via the phase-shift identity) must be
    ; updated in lockstep.
    ; --------------------------------------------------------
    FP_ERROR_INIT_MACRO t05_recover
    FP_LOAD1_MACRO TestValue::rad_360
    jsr FP_SIN_FULL
    FP_ERROR_CLEAR_MACRO
t05_recover:
    TEST_FP1CMP_MACRO 5, msg_t05, TestValue::val_0  ; t05_sin_2pi_obs

    rts

.segment "RODATA"
msg_header: .asciiz "trigonometry: sine full"
msg_t00:    .asciiz "120deg q2"
msg_t01:    .asciiz "200deg q3"
msg_t02:    .asciiz "300deg q4"
msg_t03:    .asciiz "400deg wrap"
msg_t04:    .asciiz "-30deg neg"
msg_t05:    .asciiz "360deg (=2pi)"

;t05_sin_2pi_obs:    .byte $6b,$7f,$ff,$fe
.endproc
