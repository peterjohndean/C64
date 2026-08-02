
.include "tr.inc"

.export tr_floor

.import FP_FLOOR
.import FP_COMPARE
.import FP_FROM_ASCII
.import FP_FROM_INT8
.import TEST_PASSED, TEST_FAILED

.proc tr_floor
    ; --- T42: FP_FLOOR_PROC, positive fractional (42.25 -> 42.0) ---
    lda #<str_test00
    ldy #>str_test00
    jsr FP_FROM_ASCII
    jsr FP_FLOOR
    FP_STORE1_MACRO TestData::fac_snapshot
    lda #42
    jsr FP_FROM_INT8
    FP_COMPARE_TO_MACRO TestData::fac_snapshot
    beq t42_pass
    TEST_FAILED_MACRO_V2 0, msg_t00
    jmp t42_done
t42_pass:
    TEST_PASSED_MACRO_V2 0, msg_t00
t42_done:

    ; --- T43: FP_FLOOR_PROC, negative fractional - the interesting
    ;          case: floor(-42.25) = -43.0, NOT -42.0 (trunc's answer)
    lda #<str_test01
    ldy #>str_test01
    jsr FP_FROM_ASCII
    jsr FP_FLOOR
    FP_STORE1_MACRO TestData::fac_snapshot
    lda #<(-43)
    jsr FP_FROM_INT8
    FP_COMPARE_TO_MACRO TestData::fac_snapshot
    beq t43_pass
    TEST_FAILED_MACRO_V2 1, msg_t01
    jmp t43_done
t43_pass:
    TEST_PASSED_MACRO_V2 1, msg_t01
t43_done:

    ; --- T44: FP_FLOOR_PROC, already a whole number (-5.0 -> -5.0)
    ;          - exercises the "no adjustment needed" path specifically
    lda #<(-5)
    jsr FP_FROM_INT8
    jsr FP_FLOOR
    FP_STORE1_MACRO TestData::fac_snapshot
    lda #<(-5)
    jsr FP_FROM_INT8
    FP_COMPARE_TO_MACRO TestData::fac_snapshot
    beq t44_pass
    TEST_FAILED_MACRO_V2 2, msg_t02
    jmp t44_done
t44_pass:
    TEST_PASSED_MACRO_V2 2, msg_t02
t44_done:
    rts

.segment "RODATA"
msg_t00:    .asciiz "floor ( 42.25 ->  42.0)"
msg_t01:    .asciiz "floor (-42.25 -> -43.0)"
msg_t02:    .asciiz "floor ( -5.0  ->  -5.0)"
;
str_test00: .asciiz "42.25"
str_test01: .asciiz "-42.25"
.endproc
