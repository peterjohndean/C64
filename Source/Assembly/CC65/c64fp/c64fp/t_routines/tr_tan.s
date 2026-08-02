
.include "tr.inc"

.export tr_tan

.import FP_TAN
.import TEST_CHECK, TEST_FP1CMP

.proc tr_tan
    ; --------------------------------------------------------
    ; T00-T03: ordinary angles, well away from any asymptote.
    ; T04: DELIBERATELY at 90 degrees - a true mathematical
    ; asymptote for tan(). This is not a mistake left in by
    ; accident (compare tr_sin.s's very first bug) - it is
    ; testing on purpose to see which of lib_fp_tan.s's own
    ; documented possible outcomes actually happens on this
    ; hardware: a division-by-zero trap (if cos(90) happens to
    ; round to exact 0.0), a generic overflow trap (if the
    ; quotient's exponent overflows), or - most likely, per
    ; lib_fp_tan.s's own SCOPE note and this project's own
    ; earlier measurement of cos(90 deg) as ~9.5e-7, not exactly
    ; 0.0 - a large but perfectly finite number with NO trap at
    ; all. Predicted below FROM THIS PROJECT'S OWN EARLIER
    ; MEASURED sin(90)/cos(90) results (not the idealised math
    ; value), specifically so the prediction is honest about what
    ; THIS implementation should do, not what a textbook tan()
    ; would do.
    ;
    ; Expected values (Python math.tan for T00-T03; T04's
    ; prediction is this project's own measured
    ; sin(90)=1.000003576 divided by its own measured
    ; cos(90)=~9.54e-7 - see lib_fp_tan.s's SCOPE note):
    ;   tan(0 deg)  =  0.0000000
    ;   tan(30 deg) =  0.5773503
    ;   tan(45 deg) =  1.0000000
    ;   tan(60 deg) =  1.7320508
    ;   tan(90 deg) ~= 1048222     <- NOT infinity, NOT an error -
    ;                                 see the reasoning above for
    ;                                 why that's expected here
    ; --------------------------------------------------------
    FP_ERROR_INIT_MACRO t00_recover
    FP_LOAD1_MACRO rad0
    jsr FP_TAN                   ; FP1 = tan(0 deg) ~= 0.0
    FP_ERROR_CLEAR_MACRO
t00_recover:
;    TEST_CHECK_MACRO_V2 0, msg_t00, 7
    TEST_FP1CMP_MACRO 0, msg_t00, TestValue::val_0

    FP_ERROR_INIT_MACRO t01_recover
    FP_LOAD1_MACRO rad30
    jsr FP_TAN                   ; FP1 = tan(30 deg) ~= 0.5773503
    FP_ERROR_CLEAR_MACRO
t01_recover:
    TEST_CHECK_MACRO_V2 1, msg_t01, 7

    FP_ERROR_INIT_MACRO t02_recover
    FP_LOAD1_MACRO rad45
    jsr FP_TAN                   ; FP1 = tan(45 deg) ~= 1.0
    FP_ERROR_CLEAR_MACRO
t02_recover:
    TEST_CHECK_MACRO_V2 2, msg_t02, 7

    FP_ERROR_INIT_MACRO t03_recover
    FP_LOAD1_MACRO rad60
    jsr FP_TAN                   ; FP1 = tan(60 deg) ~= 1.7320508
    FP_ERROR_CLEAR_MACRO
t03_recover:
    TEST_CHECK_MACRO_V2 3, msg_t03, 7

    FP_ERROR_INIT_MACRO t04_recover
    FP_LOAD1_MACRO rad90
    jsr FP_TAN                   ; FP1 = tan(90 deg) - the
                                 ; asymptote itself; see the big
                                 ; comment above for what to expect
    FP_ERROR_CLEAR_MACRO
t04_recover:
    ; if a trap DID fire here (division by zero or overflow -
    ; see lib_fp_tan.s SCOPE), execution resumes at this label
    ; with FP_ERROR_CODE set and FP1 in an undefined state -
    ; TEST_CHECK will simply show whatever that looks like, which
    ; is itself useful information about which SCOPE outcome this
    ; hardware actually hits
    TEST_CHECK_MACRO_V2 4, msg_t04, 7

    rts

.segment "RODATA"
msg_t00:  .asciiz     "tan (0deg)"
msg_t01:  .asciiz     "tan (30deg)"
msg_t02:  .asciiz     "tan (45deg)"
msg_t03:  .asciiz     "tan (60deg)"
msg_t04:  .asciiz     "tan (90deg) asymptote"
rad0:     .byte $00,$00,$00,$00   ; 0.0 (canonical zero)
rad30:    .byte $7f,$43,$05,$49   ; 0.5235987756 rad = 30 deg
rad45:    .byte $7f,$64,$87,$ed   ; 0.7853981634 rad = 45 deg
rad60:    .byte $80,$43,$05,$49   ; 1.0471975512 rad = 60 deg
rad90:    .byte $80,$64,$87,$ed   ; 1.5707963268 rad = 90 deg
.endproc
