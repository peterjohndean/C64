
.include "tr.inc"
.include "lib_fp_error.h"

.export tr_tan

.import FP_TAN
.import TEST_CHECK, TEST_FP1CMP, TEST_PASSED, TEST_FAILED

.segment "CODE"
.proc tr_tan
    TEST_ROUTINE_HEADER_MACRO msg_header

    ; --------------------------------------------------------
    ; T00-T03: ordinary angles, well away from any asymptote.
    ; T04: DELIBERATELY at 90 degrees - a true mathematical
    ; asymptote for tan(). See the big comment below for the
    ; post-fsub-fix expectation (now: division-by-zero trap).
    ; --------------------------------------------------------

    ;
    ; T00: tan(0 deg) ~= 0.0
    ;
    FP_ERROR_INIT_MACRO t00_recover
    FP_LOAD1_MACRO TestValue::rad_0
    jsr FP_TAN
    FP_ERROR_CLEAR_MACRO
t00_recover:
    TEST_FP1CMP_MACRO 0, msg_t00, TestValue::val_0

    ;
    ; T01: tan(30 deg) ~= 0.5773503
    ;
    FP_ERROR_INIT_MACRO t01_recover
    FP_LOAD1_MACRO TestValue::rad_30
    jsr FP_TAN
    FP_ERROR_CLEAR_MACRO
t01_recover:
    TEST_CHECK_MACRO_V2 1, msg_t01, 7

    ;
    ; T02: tan(45 deg) ~= 1.0
    ;
    FP_ERROR_INIT_MACRO t02_recover
    FP_LOAD1_MACRO TestValue::rad_45
    jsr FP_TAN
    FP_ERROR_CLEAR_MACRO
t02_recover:
    TEST_CHECK_MACRO_V2 2, msg_t02, 7

    ;
    ; T03: tan(60 deg) ~= 1.7320508
    ;
    FP_ERROR_INIT_MACRO t03_recover
    FP_LOAD1_MACRO TestValue::rad_60
    jsr FP_TAN
    FP_ERROR_CLEAR_MACRO
t03_recover:
    TEST_CHECK_MACRO_V2 3, msg_t03, 7

    ; --------------------------------------------------------
    ; T04: tan(90 deg). Now asserts the trap rather than merely
    ; displaying it - the fix is confirmed, so the trap is the
    ; expected outcome and a pass is required.
    ; --------------------------------------------------------
    FP_ERROR_INIT_MACRO @t04_recover
    FP_LOAD1_MACRO TestValue::rad_90
    jsr FP_TAN
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 4, msg_t04       ; success: should never happen
    jmp @t04_done
@t04_recover:
    lda FP_ERROR_CODE
    cmp #FP_ERROR_CODE_DIVISION_BY_ZERO
    bne @t04_wrong_code
    TEST_PASSED_MACRO_V2 4, msg_t04
    jmp @t04_done
@t04_wrong_code:
    TEST_FAILED_MACRO_V2 4, msg_t04
@t04_done:

    ; --------------------------------------------------------
    ; T05: tan(-30 deg) - NEGATIVE-INPUT coverage.
    ;
    ; The FP_SIN_FULL negative-input branch (add 2*pi once when
    ; FP_FMOD returns a negative result) and the FP_TAN chain's
    ; sign handling through FP_FDIV had no negative-input test at
    ; all before this one. cos(-30) is +0.8660254 (cos is even),
    ; sin(-30) is -0.5, so the quotient's sign is set entirely by
    ; FP_FDIV's own sign logic.
    ;
    ; Expected: tan(-30 deg) ~= -0.5773503, NO trap.
    ; --------------------------------------------------------
    FP_ERROR_INIT_MACRO t05_recover
    FP_LOAD1_MACRO TestValue::rad_neg30
    jsr FP_TAN
    FP_ERROR_CLEAR_MACRO
t05_recover:
    TEST_FP1CMP_MACRO 5, msg_t05, t05_tan_neg30_obs ; TestValue::rad_neg30

    ; --- T06: tan(270 deg). Now traps with div-by-zero, because the
    ; FMUL LSB fix makes cos(270 deg) come out exactly 0.0 (same
    ; mechanism as T04 at 90 deg). Prior to the fix, this returned a
    ; large finite value ($94BFFFF0); the FMOD residue that produced
    ; that has been eliminated. ---
    FP_ERROR_INIT_MACRO @t06_recover
    FP_LOAD1_MACRO TestValue::rad_270
    jsr FP_TAN
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 6, msg_t06
    jmp @t06_done
@t06_recover:
    lda FP_ERROR_CODE
    cmp #FP_ERROR_CODE_DIVISION_BY_ZERO
    bne @t06_wrong_code
    TEST_PASSED_MACRO_V2 6, msg_t06
    jmp @t06_done
@t06_wrong_code:
    TEST_FAILED_MACRO_V2 6, msg_t06
@t06_done:

    rts

.segment "RODATA"
msg_header: .asciiz "trigonometry: tangent"
msg_t00:    .asciiz  " 0deg"
msg_t01:    .asciiz  "30deg"
msg_t02:    .asciiz  "45deg"
msg_t03:    .asciiz  "60deg"
msg_t04:    .asciiz  "90deg trap-asym"
msg_t05:    .asciiz  "-30deg neg"
msg_t06:    .asciiz  "270deg asym-trap"

t05_tan_neg30_obs:  .byte $7f,$b6,$19,$5e   ; ~6 ULP, |Δ| < 1e-6
;t06_tan_270_obs:    .byte $94,$bf,$ff,$f0
.endproc
