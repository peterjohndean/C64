
.include "tr.inc"

.export tr_ieee754

.import FP_FROM_IEEE754, FP_TO_IEEE754
.import FP_COMPARE
.import FP_FROM_INT8
.import TEST_FP1CMP
.import TEST_PASSED, TEST_FAILED

.proc tr_ieee754
    ; --- T36: FP_TO_IEEE754_PROC / FP_FROM_IEEE754_PROC round trip ---
    FP_LOAD1_MACRO TestValue::val_12
    jsr FP_TO_IEEE754
    jsr FP_FROM_IEEE754
    TEST_FP1CMP_MACRO 0, msg_t00, TestValue::val_12

    ; --- T37: same round trip, at the boundary case that needed the
    ;          extra care documented in lib_fp_ieee754.s (a
    ;          negative value whose magnitude is an exact power of
    ;          2) - verified separately against the real hardware
    ;          negation behaviour before this test was written.
    lda #<(-1)
    jsr FP_FROM_INT8              ; FP1 = -1.0
    FP_STORE1_MACRO TestData::fac_snapshot
    jsr FP_TO_IEEE754
    jsr FP_FROM_IEEE754
    FP_COMPARE_TO_MACRO TestData::fac_snapshot
    beq t37_pass
    TEST_FAILED_MACRO_V2 1, msg_t01
    jmp t37_done
t37_pass:
    TEST_PASSED_MACRO_V2 1, msg_t01
t37_done:

    ; --- T38: IEEE-754 round trip of zero ---
    FP_LOAD1_MACRO TestValue::val_0
    jsr FP_TO_IEEE754
    jsr FP_FROM_IEEE754
    TEST_FP1CMP_MACRO 2, msg_t02, TestValue::val_0

t39:
    ; --- T39: FP_FROM_IEEE754_PROC traps on Infinity (error code 4) ---
    ; $7F800000 is IEEE-754 +Infinity - poked directly since Woz
    ; format has no way to construct this itself (that's the point).
    lda #$7f
    sta FP1_EXP
    lda #$80
    sta FP1_MANT
    lda #$00
    sta FP1_MANT+1
    sta FP1_MANT+2
    FP_ERROR_INIT_MACRO t39_recover
    jsr FP_FROM_IEEE754
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 3, msg_t03
    jmp t39_done
t39_recover:
    lda FP_ERROR_CODE
    cmp #4
    bne t39_fail
    TEST_PASSED_MACRO_V2 3, msg_t03
    jmp t39_done
t39_fail:
    TEST_FAILED_MACRO_V2 3, msg_t03
t39_done:

    ; --- T51: FP_FROM_IEEE754_PROC traps on NaN (error code 4) ---
    ; $7FC00000 is an IEEE-754 Quiet NaN. Exponent is $FF (all 1s),
    ; and the mantissa is non-zero. The parser must explicitly reject it.
    lda #$7f
    sta FP1_EXP
    lda #$c0
    sta FP1_MANT
    lda #$00
    sta FP1_MANT+1
    sta FP1_MANT+2
    FP_ERROR_INIT_MACRO t51_recover
    jsr FP_FROM_IEEE754
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 4, msg_t04
    jmp t51_done
t51_recover:
    lda FP_ERROR_CODE
    cmp #5
    bne t51_fail
    TEST_PASSED_MACRO_V2 4, msg_t04
    jmp t51_done
t51_fail:
    TEST_FAILED_MACRO_V2 4, msg_t04
t51_done:

    ;
    FP_LOAD1_MACRO TestValue::ieee754_pi
    jsr FP_FROM_IEEE754
;    TEST_CHECK_MACRO_V2 5, msg_t05, 7
    TEST_FP1CMP_MACRO 5, msg_t05, TestValue::val_pi

    ;
    FP_LOAD1_MACRO TestValue::ieee754_neg5
    jsr FP_FROM_IEEE754
    TEST_FP1CMP_MACRO 6, msg_t06, TestValue::val_neg5

    ;
    FP_LOAD1_MACRO TestValue::ieee754_0_1
    jsr FP_FROM_IEEE754
    TEST_FP1CMP_MACRO 7, msg_t07, TestValue::val_0_1

    ;
    FP_LOAD1_MACRO TestValue::ieee754_2pi
    jsr FP_FROM_IEEE754
    TEST_FP1CMP_MACRO 8, msg_t08, TestValue::val_2pi
    rts

.segment "RODATA"
msg_t00:    .asciiz "ieee754 (12)  "        ;round trip"
msg_t01:    .asciiz "ieee754 (edge)"        ;round trip (edge)"
msg_t02:    .asciiz "ieee754 (0)   "        ;round trip (0)"
msg_t03:    .asciiz "ieee754 (trap +inf)"
msg_t04:    .asciiz "ieee754 (trap nan)"
msg_t05:    .asciiz "ieee754->fp (pi) "
msg_t06:    .asciiz "ieee754->fp (-5) "
msg_t07:    .asciiz "ieee754->fp (0.1)"
msg_t08:    .asciiz "ieee754->fp (2pi)"
.endproc
