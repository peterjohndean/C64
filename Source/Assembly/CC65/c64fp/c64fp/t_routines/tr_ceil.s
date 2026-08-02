
.include "tr.inc"

.export tr_ceil

.import FP_CEIL
.import FP_COMPARE
.import FP_FROM_ASCII
.import FP_FROM_INT8
.import TEST_PASSED, TEST_FAILED

.proc tr_ceil
    ; --- T45: FP_CEIL_PROC, positive fractional (42.25 -> 43.0) ---
    lda #<str_test00
    ldy #>str_test00
    jsr FP_FROM_ASCII
    jsr FP_CEIL
    FP_STORE1_MACRO TestData::fac_snapshot
    lda #43
    jsr FP_FROM_INT8
    FP_COMPARE_TO_MACRO TestData::fac_snapshot
    beq t45_pass
    TEST_FAILED_MACRO_V2 0, msg_t00
    jmp t45_done
t45_pass:
    TEST_PASSED_MACRO_V2 0, msg_t00
t45_done:

    ; --- T46: FP_CEIL_PROC, negative fractional (-42.25 -> -42.0) ---
    lda #<str_test01
    ldy #>str_test01
    jsr FP_FROM_ASCII
    jsr FP_CEIL
    FP_STORE1_MACRO TestData::fac_snapshot
    lda #<(-42)
    jsr FP_FROM_INT8
    FP_COMPARE_TO_MACRO TestData::fac_snapshot
    beq t46_pass
    TEST_FAILED_MACRO_V2 1, msg_t01
    jmp t46_done
t46_pass:
    TEST_PASSED_MACRO_V2 1, msg_t01
t46_done:
    rts

.segment "RODATA"
msg_t00:    .asciiz "ceil  ( 42.25 ->  43.0)"
msg_t01:    .asciiz "ceil  (-42.25 -> -42.0)"
;
str_test00:     .asciiz     "42.25"
str_test01:     .asciiz     "-42.25"
.endproc
