
.include "tr.inc"

.export tr_fdiv

.import FP_FDIV, FP_FROM_INT8
.import TEST_FP1CMP
.import TEST_PASSED, TEST_FAILED

.segment "CODE"
.proc tr_fdiv
    TEST_ROUTINE_HEADER_MACRO msg_header

    ; --- T03: FDIV  -60 / 12 = -5 (FP1=divisor, FP2=dividend) ---
    FP_LOAD1_MACRO TestValue::val_12
    FP_LOAD2_MACRO TestValue::val_neg60
    jsr FP_FDIV
    TEST_FP1CMP_MACRO 0, msg_t00, TestValue::val_neg5

    ; --- T31: error handling - division by zero (code 1) ------------
    ; This is the real objective from here through T35: prove the
    ; trap-and-recover mechanism actually works, under an emulator
    ; AND on hardware, with no crash, no warm boot, no hang - not
    ; just that the arithmetic that triggers the trap is correct
    ; (that part was already verified separately - see
    ; lib_fp.s's fdiv comments).
    FP_LOAD1_MACRO TestValue::val_0                ; divisor = 0.0
    FP_LOAD2_MACRO TestValue::val_12               ; dividend = 12.0
    FP_ERROR_INIT_MACRO t31_recover
    jsr FP_FDIV
    ; should never reach here - the trap redirects to t32_recover
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 1, msg_t01
    jmp t31_done
t31_recover:
    lda FP_ERROR_CODE
    cmp #1
    bne t31_fail
    TEST_PASSED_MACRO_V2 1, msg_t01
    jmp t31_done
t31_fail:
    TEST_FAILED_MACRO_V2 1, msg_t01
t31_done:

    ; ========================================================
    ; T02-T05: FP_FDIV(A, A) == 1.0 - precision check at
    ; ordinary exponents.
    ;
    ; Motivated by tr_fmod.s T50-T57: x mod x gave exact 0 for
    ; "simple" mantissas (10, 3, 1, 100, 0.5, 1.5 - all with
    ; trailing zeros in the mantissa) but a half-ulp residue for
    ; pi and 2pi (full 24-bit mantissas). FP_FMOD computes
    ; A - B*floor(A/B), so a half-ulp residue in the result is
    ; most simply explained by FP_FDIV(A, A) itself not returning
    ; exactly 1.0 when A has a full mantissa - which would make
    ; this an FP_FDIV precision issue, not an FP_FMOD one, and
    ; would affect every division with a nontrivial mantissa.
    ;
    ; These four tests isolate that hypothesis:
    ;   T02/T03 - full-mantissa inputs (pi, 2pi) - the "suspects"
    ;   T04/T05 - trailing-zero mantissas (10, 3) - the "controls"
    ;
    ; Interpretation:
    ;   T02/T03 fail, T04/T05 pass  -> FP_FDIV is the culprit; the
    ;       FP_FMOD residue is a downstream symptom, and every
    ;       division of full-mantissa values is potentially off
    ;       by up to one ulp.
    ;   T02/T03 pass                -> FP_FDIV is exact for A/A;
    ;       the residue in FP_FMOD(pi, pi) must come from FP_FIX,
    ;       FP_FMUL, or FP_FSUB - next test should isolate which.
    ;   Any test failing           -> also reveals whether the
    ;       precision loss affects ordinary-exponent division
    ;       generally, or only certain mantissa patterns.
    ;
    ; Entry convention for FP_FDIV: FP1 = divisor, FP2 = dividend.
    ; Result lands in FP1 = FP2/FP1. FP_COPY1TO2_MACRO copies FP1
    ; into FP2 without touching FP1, so loading A once, then
    ; copying, gives both operands the same value.
    ; ========================================================

    ; --- T02: pi / pi == 1.0 ---
    FP_LOAD1_MACRO TestValue::val_pi
    FP_COPY1TO2_MACRO
    jsr FP_FDIV
    TEST_FP1CMP_MACRO 2, msg_t02, TestValue::val_1

    ; --- T03: 2pi / 2pi == 1.0 ---
    FP_LOAD1_MACRO TestValue::val_2pi
    FP_COPY1TO2_MACRO
    jsr FP_FDIV
    TEST_FP1CMP_MACRO 3, msg_t03, TestValue::val_1

    ; --- T04: 10 / 10 == 1.0 (control - trailing-zero mantissa) ---
    lda #10
    jsr FP_FROM_INT8
    FP_COPY1TO2_MACRO
    jsr FP_FDIV
    TEST_FP1CMP_MACRO 4, msg_t04, TestValue::val_1

    ; --- T05: 3 / 3 == 1.0 (control - trailing-zero mantissa) ---
    lda #3
    jsr FP_FROM_INT8
    FP_COPY1TO2_MACRO
    jsr FP_FDIV
    TEST_FP1CMP_MACRO 5, msg_t05, TestValue::val_1

    rts

.segment "RODATA"
msg_header:     .asciiz "mathematics: division"
msg_t00:        .asciiz "-60 / 12 = -5"
msg_t01:        .asciiz " 12 /  0 = trap"
msg_t02:        .asciiz "pi  / pi  = 1.0"
msg_t03:        .asciiz "2pi / 2pi = 1.0"
msg_t04:        .asciiz "10  / 10  = 1.0"
msg_t05:        .asciiz "3   / 3   = 1.0"
.endproc
