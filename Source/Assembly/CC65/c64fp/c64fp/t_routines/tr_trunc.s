
.include "tr.inc"

.export tr_trunc

.import FP_TRUNC
.import FP_COMPARE
.import FP_FROM_ASCII
.import FP_FROM_INT8
.import TEST_PASSED, TEST_FAILED

.proc tr_trunc
    ; --- T40: FP_TRUNC_PROC, positive fractional (42.25 -> 42.0) ---
    lda #<str_test00
    ldy #>str_test00
    jsr FP_FROM_ASCII
    jsr FP_TRUNC
    FP_STORE1_MACRO TestData::fac_snapshot
    lda #42
    jsr FP_FROM_INT8
    FP_COMPARE_TO_MACRO TestData::fac_snapshot
    beq t40_pass
    TEST_FAILED_MACRO_V2 0, msg_t00
    jmp t40_done
t40_pass:
    TEST_PASSED_MACRO_V2 0, msg_t00
t40_done:

    ; --- T41: FP_TRUNC_PROC, negative fractional (-42.25 -> -42.0) ---
    lda #<str_test01
    ldy #>str_test01
    jsr FP_FROM_ASCII
    jsr FP_TRUNC
    FP_STORE1_MACRO TestData::fac_snapshot
    lda #<(-42)
    jsr FP_FROM_INT8
    FP_COMPARE_TO_MACRO TestData::fac_snapshot
    beq t41_pass
    TEST_FAILED_MACRO_V2 1, msg_t01
    jmp t41_done
t41_pass:
    TEST_PASSED_MACRO_V2 1, msg_t01
t41_done:
    rts

.segment "RODATA"
msg_t00:    .asciiz "trunc ( 42.25 ->  42.0)"
msg_t01:    .asciiz "trunc (-42.25 -> -42.0)"
;
str_test00: .asciiz "42.25"
str_test01: .asciiz "-42.25"
.endproc
