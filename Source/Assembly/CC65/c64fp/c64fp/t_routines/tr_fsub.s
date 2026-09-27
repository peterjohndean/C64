
.include "tr.inc"

.export tr_fsub

.import FP_FSUB
.import TEST_FP1CMP

.segment "CODE"
.proc tr_fsub
    TEST_ROUTINE_HEADER_MACRO msg_header

    ; --- T01: FSUB - confirms the FP2-FP1 convention ---
    ; FP1=-5, FP2=+7 -> result = FP2-FP1 = 7-(-5) = 12. This
    ; doesn't itself exercise the errata (that's LOG's job, T14),
    ; but confirms FSUB's convention independently before anything
    ; downstream (LOG uses FSUB internally) is trusted.
    FP_LOAD1_MACRO TestValue::val_neg5
    FP_LOAD2_MACRO TestValue::val_7
    jsr FP_FSUB
    TEST_FP1CMP_MACRO 0, msg_t00, TestValue::val_12

    ; --- T54: FSUB Zero-Crossing (12.0 - 12.0 = 0.0) ---
    ; Ensures the normalizer correctly catches total cancellation
    ; and returns a canonical zero, not a subnormal float.
    FP_LOAD1_MACRO TestValue::val_12
    FP_LOAD2_MACRO TestValue::val_12
    jsr FP_FSUB
    TEST_FP1CMP_MACRO 1, msg_t01, TestValue::val_0

    ; ========================================================
    ; T55-T57: FP_FSUB(x, x) == 0 - self-cancellation precision.
    ;
    ; Third leg of the FP_FMOD(x, x) residue investigation started
    ; in tr_fmod.s T50-T57. tr_fdiv.s T02-T05 ruled out FP_FDIV.
    ; tr_fmul.s T55-T57 (in that file) test the other half of the
    ; decomposition. If both pass, FP_FSUB's own all-bits-cancel
    ; path is the last remaining candidate:
    ;     res = FP_FSUB(A, FP_FMUL(FP_FIX(FP_FDIV(A,A)), A))
    ; When A/B == 1.0 and 1.0*A == A both hold exactly, the
    ; subtraction is A - A, and any nonzero result must come from
    ; FP_FSUB failing to recognise the total-cancellation case.
    ;
    ; The same mantissa-class split as the previous tests applies:
    ;   T02/T03 - full-mantissa inputs (pi, 2pi) - suspects
    ;   T04     - trailing-zero mantissa (10)     - control
    ;
    ; Interpretation:
    ;   T02/T03 fail, T04 passes -> FP_FSUB's cancellation case is
    ;       mantissa-sensitive. Blast radius: any subtraction that
    ;       cancels to zero, which is not just FP_FMOD - FP_COMPARE
    ;       is built on FP_FSUB (see lib_fp_compare.s), so equality
    ;       tests on full-mantissa values could be affected too.
    ;   All three pass -> all three primitives are exact in
    ;       isolation; the residue must come from an internal path
    ;       in FP_FMOD that bypasses one of the FP_FDIV/FP_FIX/
    ;       FP_FMUL/FP_FSUB entries exercised by these tests.
    ; ========================================================

    ; --- T02: FSUB pi - pi == 0 ---
    FP_LOAD1_MACRO TestValue::val_pi
    FP_LOAD2_MACRO TestValue::val_pi
    jsr FP_FSUB
    TEST_FP1CMP_MACRO 2, msg_t02, TestValue::val_0

    ; --- T03: FSUB 2pi - 2pi == 0 ---
    FP_LOAD1_MACRO TestValue::val_2pi
    FP_LOAD2_MACRO TestValue::val_2pi
    jsr FP_FSUB
    TEST_FP1CMP_MACRO 3, msg_t03, TestValue::val_0

    ; --- T04: FSUB 10 - 10 == 0 (control) ---
    FP_LOAD1_MACRO TestValue::val_10
    FP_LOAD2_MACRO TestValue::val_10
    jsr FP_FSUB
    TEST_FP1CMP_MACRO 4, msg_t04, TestValue::val_0

    rts

.segment "RODATA"
msg_header: .asciiz "mathematics: subtraction"
msg_t00:    .asciiz " 7 - (-5) = 12"
msg_t01:    .asciiz "12 - 12   =  0"
msg_t02:    .asciiz "pi  - pi  = 0"
msg_t03:    .asciiz "2pi - 2pi = 0"
msg_t04:    .asciiz "10  - 10  = 0"
.endproc
