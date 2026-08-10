
.include "tr.inc"

.export tr_cos

.import FP_COS
.import TEST_CHECK, TEST_FP1CMP

.proc tr_cos
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

    FP_ERROR_INIT_MACRO t04_recover
    FP_LOAD1_MACRO TestValue::rad_270
    jsr FP_COS                   ; FP1 = cos(270 deg) ~= 0.0 -
                                 ; phase-shifted argument lands
                                 ; exactly on 2*pi, the FP_FMOD
                                 ; wraparound point itself
    FP_ERROR_CLEAR_MACRO
t04_recover:
;    TEST_CHECK_MACRO_V2 4, msg_t04, 7
    TEST_FP1CMP_MACRO 4, msg_t04, TestValue::val_0
    rts

.segment "RODATA"
msg_t00:  .asciiz     "cos (0deg)"
msg_t01:  .asciiz     "cos (45deg)"
msg_t02:  .asciiz     "cos (90deg) boundary"
msg_t03:  .asciiz     "cos (180deg)"
msg_t04:  .asciiz     "cos (270deg) wrap"
.endproc
