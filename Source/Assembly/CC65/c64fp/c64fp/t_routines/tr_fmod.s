
.include "tr.inc"

.export tr_fmod

.import FP_FMOD, FP_COMPARE
.import FP_FROM_INT8
.import TEST_PASSED, TEST_FAILED

.proc tr_fmod
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
    rts

.segment "RODATA"
msg_t00:        .asciiz     "mod ( 7 % 3 =  1)"
msg_t01:        .asciiz     "mod (-7 % 3 = -1)"
msg_t02:        .asciiz     "mod (trap %0)"
.endproc
