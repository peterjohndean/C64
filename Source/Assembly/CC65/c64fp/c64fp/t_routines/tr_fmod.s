
.include "tr.inc"

.export tr_fmod

.import FP_FMOD, FP_COMPARE
.import FP_FROM_INT8
.import TEST_PASSED, TEST_FAILED, TEST_CHECK, TEST_FP1CMP

.segment "CODE"
.proc tr_fmod
    TEST_ROUTINE_HEADER_MACRO msg_header

    ; --- T47: FP_FMOD_PROC, basic case: 7 mod 3 = 1 ---
    lda #3
    jsr FP_FROM_INT8
    FP_COPY1TO2_MACRO                   ; FP2 = 3.0 (divisor)
    lda #7
    jsr FP_FROM_INT8                    ; FP1 = 7.0 (dividend)
    jsr FP_FMOD
    FP_STORE1_MACRO TestData::fac_snapshot
    lda #1
    jsr FP_FROM_INT8
    FP_COMPARE_TO_MACRO TestData::fac_snapshot
    beq t47_pass
    TEST_FAILED_MACRO_V2 0, msg_t00
    jmp t47_done
t47_pass:
    TEST_PASSED_MACRO_V2 0, msg_t00
t47_done:

    ; --- T48: FP_FMOD_PROC, negative dividend: -7 mod 3 = -1 ---
    lda #3
    jsr FP_FROM_INT8
    FP_COPY1TO2_MACRO
    lda #<(-7)
    jsr FP_FROM_INT8
    jsr FP_FMOD
    FP_STORE1_MACRO TestData::fac_snapshot
    lda #<(-1)
    jsr FP_FROM_INT8
    FP_COMPARE_TO_MACRO TestData::fac_snapshot
    beq t48_pass
    TEST_FAILED_MACRO_V2 1, msg_t01
    jmp t48_done
t48_pass:
    TEST_PASSED_MACRO_V2 1, msg_t01
t48_done:

    ; --- T49: FP_FMOD_PROC by zero traps (inherits FP_FDIV's own
    ;          division-by-zero detection, error code 1)
    lda #0
    jsr FP_FROM_INT8
    FP_COPY1TO2_MACRO                   ; FP2 = 0.0 (divisor)
    lda #5
    jsr FP_FROM_INT8                    ; FP1 = 5.0 (dividend)
    FP_ERROR_INIT_MACRO t49_recover
    jsr FP_FMOD
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 2, msg_t02
    jmp t49_done
t49_recover:
    lda FP_ERROR_CODE
    cmp #1
    bne t49_fail
    TEST_PASSED_MACRO_V2 2, msg_t02
    jmp t49_done
t49_fail:
    TEST_FAILED_MACRO_V2 2, msg_t02
t49_done:

    ; ========================================================
    ; T50-T57: FP_FMOD(x, x) boundary characterization
    ; ========================================================
    ; x mod x is mathematically zero. The trig test run shows that
    ; FP_FMOD(2*pi, 2*pi) returns a small residue (~9.5e-7) instead,
    ; which then propagates into sin(2*pi) and cos(270 deg). These
    ; tests pin down whether the residue is:
    ;   - constant magnitude regardless of x (a threshold artefact)
    ;   - proportional to x (a cancellation-precision artefact)
    ;   - dependent on the exponent of x (an FP_FDIV/FSUB boundary
    ;     artefact)
    ; ...because the fix (or the documented workaround) depends on
    ; which of those is true.
    ;
    ; Format: each test computes x mod x for an exact x, then stores
    ; the result raw. TEST_CHECK prints the bytes so the pattern
    ; becomes visible; no exact comparison is asserted here because
    ; the whole point is to characterise an unknown.
    ; ========================================================

    ; --- T50: 2*pi mod 2*pi (the value the trig tests hit) ---
    FP_LOAD1_MACRO TestValue::rad_360
    FP_COPY1TO2_MACRO
    FP_LOAD1_MACRO TestValue::rad_360
    jsr FP_FMOD
    TEST_FP1CMP_MACRO 3, msg_t50, TestValue::val_0
;    TEST_CHECK_MACRO_V2 3, msg_t50, 7

    ; --- T51: 10.0 mod 10.0 ---
    lda #10
    jsr FP_FROM_INT8
    FP_COPY1TO2_MACRO
    lda #10
    jsr FP_FROM_INT8
    jsr FP_FMOD
    TEST_FP1CMP_MACRO 4, msg_t51, TestValue::val_0

    ; --- T52: 3.0 mod 3.0 ---
    lda #3
    jsr FP_FROM_INT8
    FP_COPY1TO2_MACRO
    lda #3
    jsr FP_FROM_INT8
    jsr FP_FMOD
    TEST_FP1CMP_MACRO 5, msg_t52, TestValue::val_0
;    TEST_CHECK_MACRO_V2 5, msg_t52, 7

    ; --- T53: 1.0 mod 1.0 ---
    lda #1
    jsr FP_FROM_INT8
    FP_COPY1TO2_MACRO
    lda #1
    jsr FP_FROM_INT8
    jsr FP_FMOD
    TEST_FP1CMP_MACRO 6, msg_t53, TestValue::val_0
;    TEST_CHECK_MACRO_V2 6, msg_t53, 7

    ; --- T54: 100.0 mod 100.0 ---
    lda #100
    jsr FP_FROM_INT8
    FP_COPY1TO2_MACRO
    lda #100
    jsr FP_FROM_INT8
    jsr FP_FMOD
    TEST_FP1CMP_MACRO 7, msg_t54, TestValue::val_0
;    TEST_CHECK_MACRO_V2 7, msg_t54, 7

    ; --- T55: pi mod pi ---
    FP_LOAD1_MACRO TestValue::val_pi
    FP_COPY1TO2_MACRO
    FP_LOAD1_MACRO TestValue::val_pi
    jsr FP_FMOD
    TEST_FP1CMP_MACRO 8, msg_t55, TestValue::val_0
;    TEST_CHECK_MACRO_V2 8, msg_t55, 7

    ; --- T56: 0.5 mod 0.5 ---
    FP_LOAD1_MACRO TestValue::val_0_5
    FP_COPY1TO2_MACRO
    FP_LOAD1_MACRO TestValue::val_0_5
    jsr FP_FMOD
    TEST_FP1CMP_MACRO 9, msg_t56, TestValue::val_0
;    TEST_CHECK_MACRO_V2 9, msg_t56, 7

    ; --- T57: 1.5 mod 1.5 ---
    FP_LOAD1_MACRO TestValue::val_1_5
    FP_COPY1TO2_MACRO
    FP_LOAD1_MACRO TestValue::val_1_5
    jsr FP_FMOD
    TEST_FP1CMP_MACRO 10, msg_t57, TestValue::val_0
;    TEST_CHECK_MACRO_V2 10, msg_t57, 7

    rts

.segment "RODATA"
msg_header: .asciiz "mathematics: modulo"
msg_t00:    .asciiz " 7 % 3 =  1)"
msg_t01:    .asciiz "-7 % 3 = -1)"
msg_t02:    .asciiz " 5 % 0 = trap"
msg_t50:    .asciiz "2pi % 2pi "
msg_t51:    .asciiz "10  % 10  "
msg_t52:    .asciiz "3   % 3   "
msg_t53:    .asciiz "1   % 1   "
msg_t54:    .asciiz "100 % 100 "
msg_t55:    .asciiz "pi  % pi  "
msg_t56:    .asciiz "0.5 % 0.5 "
msg_t57:    .asciiz "1.5 % 1.5"
.endproc
