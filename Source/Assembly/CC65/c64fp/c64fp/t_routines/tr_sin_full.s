
.include "tr.inc"

.export tr_sin_full

.import FP_SIN_FULL
.import TEST_CHECK

.proc tr_sin_full
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
    FP_LOAD1_MACRO rad120
    jsr FP_SIN_FULL              ; FP1 = sin(120 deg) ~= +0.8660254
    FP_ERROR_CLEAR_MACRO
t00_recover:
    TEST_CHECK_MACRO_V2 0, msg_t00, 7

    FP_ERROR_INIT_MACRO t01_recover
    FP_LOAD1_MACRO rad200
    jsr FP_SIN_FULL              ; FP1 = sin(200 deg) ~= -0.3420201
    FP_ERROR_CLEAR_MACRO
t01_recover:
    TEST_CHECK_MACRO_V2 1, msg_t01, 7

    FP_ERROR_INIT_MACRO t02_recover
    FP_LOAD1_MACRO rad300
    jsr FP_SIN_FULL              ; FP1 = sin(300 deg) ~= -0.8660254
    FP_ERROR_CLEAR_MACRO
t02_recover:
    TEST_CHECK_MACRO_V2 2, msg_t02, 7

    FP_ERROR_INIT_MACRO t03_recover
    FP_LOAD1_MACRO rad400
    jsr FP_SIN_FULL              ; FP1 = sin(400 deg) ~= sin(40 deg)
                                 ; ~= +0.6427876 - exercises the
                                 ; mod-2pi wraparound itself
    FP_ERROR_CLEAR_MACRO
t03_recover:
    TEST_CHECK_MACRO_V2 3, msg_t03, 7

    FP_ERROR_INIT_MACRO t04_recover
    FP_LOAD1_MACRO radneg30
    jsr FP_SIN_FULL              ; FP1 = sin(-30 deg) ~= -0.5 -
                                 ; exercises the "FMOD gave a
                                 ; negative result" correction path
    FP_ERROR_CLEAR_MACRO
t04_recover:
    TEST_CHECK_MACRO_V2 4, msg_t04, 7

    rts

.segment "RODATA"
msg_t00:  .asciiz     "sin full (120deg) q2"
msg_t01:  .asciiz     "sin full (200deg) q3"
msg_t02:  .asciiz     "sin full (300deg) q4"
msg_t03:  .asciiz     "sin full (400deg) wrap"
msg_t04:  .asciiz     "sin full (-30deg) neg"
rad120:   .byte $81,$43,$05,$49   ; 2.0943951024 rad = 120 deg
rad200:   .byte $81,$6f,$b3,$79   ; 3.4906585040 rad = 200 deg
rad300:   .byte $82,$53,$c6,$9b   ; 5.2359877560 rad = 300 deg
rad400:   .byte $82,$6f,$b3,$79   ; 6.9813170080 rad = 400 deg
radneg30: .byte $7f,$bc,$fa,$b7   ; -0.5235987756 rad = -30 deg
.endproc
