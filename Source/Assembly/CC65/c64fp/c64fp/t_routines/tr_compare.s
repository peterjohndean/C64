.include "tr.inc"

.export tr_compare

.import FP_COMPARE
.import TEST_PASSED, TEST_FAILED, TEST_FP1CMP

.segment "CODE"
.proc tr_compare
    TEST_ROUTINE_HEADER_MACRO msg_header

    ; --- T26: FP_COMPARE_PROC - FP1 = FP2 ---
    FP_LOAD1_MACRO TestValue::val_12
    FP_LOAD2_MACRO TestValue::val_12
    jsr FP_COMPARE
    beq t26_pass
    TEST_FAILED_MACRO_V2 0, msg_t00
    jmp t26_done
t26_pass:
    TEST_PASSED_MACRO_V2 0, msg_t00
t26_done:

    ; --- T27: FP_COMPARE_PROC - FP1 > FP2 ---
    FP_LOAD1_MACRO TestValue::val_12
    FP_LOAD2_MACRO TestValue::val_neg5
    jsr FP_COMPARE
    bmi t27_fail
    beq t27_fail
    TEST_PASSED_MACRO_V2 1, msg_t01
    jmp t27_done
t27_fail:
    TEST_FAILED_MACRO_V2 1, msg_t01
t27_done:

    ; --- T28: FP_COMPARE_PROC - FP1 < FP2 ---
    FP_LOAD1_MACRO TestValue::val_neg5
    FP_LOAD2_MACRO TestValue::val_12
    jsr FP_COMPARE
    bpl t28_fail
    TEST_PASSED_MACRO_V2 2, msg_t02
    jmp t28_done
t28_fail:
    TEST_FAILED_MACRO_V2 2, msg_t02
t28_done:

    ; --- T29: FP_COMPARE_PROC leaves FP1 unchanged (non-destructive) ---
    FP_LOAD1_MACRO TestValue::val_12
    FP_LOAD2_MACRO TestValue::val_neg5
    jsr FP_COMPARE
    TEST_FP1CMP_MACRO 3, msg_t03, TestValue::val_12

    ; --- T30: FP_COMPARE_TO_MACRO ---
    FP_LOAD1_MACRO TestValue::val_12
    FP_COMPARE_TO_MACRO TestValue::val_12
    beq t30_pass
    TEST_FAILED_MACRO_V2 4, msg_t04
    jmp t30_done
t30_pass:
    TEST_PASSED_MACRO_V2 4, msg_t04
t30_done:

    ; ==========================================================
    ; Boundary / robustness tests for the alignment-trampoline
    ; hang (exponent gap >= 25).
    ; ==========================================================

    ; --- T31: 2^-127 < 1.0  (large gap, FP1 < FP2) ---
    FP_LOAD1_MACRO TestValue::val_min_pos
    FP_LOAD2_MACRO TestValue::val_1
    jsr FP_COMPARE
    bpl t31_fail                     ; expect N=1 ($FF)
    TEST_PASSED_MACRO_V2 5, msg_t05
    jmp t31_done
t31_fail:
    TEST_FAILED_MACRO_V2 5, msg_t05
t31_done:

    ; --- T32: 1.0 > 2^-127  (large gap, FP1 > FP2) ---
    FP_LOAD1_MACRO TestValue::val_1
    FP_LOAD2_MACRO TestValue::val_min_pos
    jsr FP_COMPARE
    bmi t32_fail
    beq t32_fail                     ; expect N=0 Z=0 ($01)
    TEST_PASSED_MACRO_V2 6, msg_t06
    jmp t32_done
t32_fail:
    TEST_FAILED_MACRO_V2 6, msg_t06
t32_done:

    ; --- T33: +max > 1.0  (large gap, upper end) ---
    FP_LOAD1_MACRO TestValue::val_max_pos
    FP_LOAD2_MACRO TestValue::val_1
    jsr FP_COMPARE
    bmi t33_fail
    beq t33_fail
    TEST_PASSED_MACRO_V2 7, msg_t07
    jmp t33_done
t33_fail:
    TEST_FAILED_MACRO_V2 7, msg_t07
t33_done:

    ; --- T34: 1.0 < +max  (large gap, upper end) ---
    FP_LOAD1_MACRO TestValue::val_1
    FP_LOAD2_MACRO TestValue::val_max_pos
    jsr FP_COMPARE
    bpl t34_fail
    TEST_PASSED_MACRO_V2 8, msg_t08
    jmp t34_done
t34_fail:
    TEST_FAILED_MACRO_V2 8, msg_t08
t34_done:

    ; --- T35: exponent diff = 24, 1.0 > 2^-24 (still normal path) ---
    FP_LOAD1_MACRO TestValue::val_1
    FP_LOAD2_MACRO val_diff24
    jsr FP_COMPARE
    bmi t35_fail
    beq t35_fail
    TEST_PASSED_MACRO_V2 9, msg_t09
    jmp t35_done
t35_fail:
    TEST_FAILED_MACRO_V2 9, msg_t09
t35_done:

    ; --- T36: exponent diff = 25, 1.0 > 2^-25 (short-circuit path) ---
    FP_LOAD1_MACRO TestValue::val_1
    FP_LOAD2_MACRO val_diff25
    jsr FP_COMPARE
    bmi t36_fail
    beq t36_fail
    TEST_PASSED_MACRO_V2 10, msg_t10
    jmp t36_done
t36_fail:
    TEST_FAILED_MACRO_V2 10, msg_t10
t36_done:

    ; --- T37: exponent diff = 24, 2^-24 < 1.0 ---
    FP_LOAD1_MACRO val_diff24
    FP_LOAD2_MACRO TestValue::val_1
    jsr FP_COMPARE
    bpl t37_fail
    TEST_PASSED_MACRO_V2 11, msg_t11
    jmp t37_done
t37_fail:
    TEST_FAILED_MACRO_V2 11, msg_t11
t37_done:

    ; --- T38: exponent diff = 25, 2^-25 < 1.0 (short-circuit path) ---
    FP_LOAD1_MACRO val_diff25
    FP_LOAD2_MACRO TestValue::val_1
    jsr FP_COMPARE
    bpl t38_fail
    TEST_PASSED_MACRO_V2 12, msg_t12
    jmp t38_done
t38_fail:
    TEST_FAILED_MACRO_V2 12, msg_t12
t38_done:

    ; --- T39: both negative, large gap: -1 < -2^-127 ---
    ;     |-1| > |-2^-127|, both negative -> -1 is the smaller value.
    FP_LOAD1_MACRO TestValue::val_neg1
    FP_LOAD2_MACRO TestValue::val_min_neg
    jsr FP_COMPARE
    bpl t39_fail
    TEST_PASSED_MACRO_V2 13, msg_t13
    jmp t39_done
t39_fail:
    TEST_FAILED_MACRO_V2 13, msg_t13
t39_done:

    ; --- T40: both negative, large gap: -2^-127 > -1 ---
    FP_LOAD1_MACRO TestValue::val_min_neg
    FP_LOAD2_MACRO TestValue::val_neg1
    jsr FP_COMPARE
    bmi t40_fail
    beq t40_fail
    TEST_PASSED_MACRO_V2 14, msg_t14
    jmp t40_done
t40_fail:
    TEST_FAILED_MACRO_V2 14, msg_t14
t40_done:

    ; --- T41: signs differ, large gap: -2^-127 < 1.0 ---
    FP_LOAD1_MACRO TestValue::val_min_neg
    FP_LOAD2_MACRO TestValue::val_1
    jsr FP_COMPARE
    bpl t41_fail
    TEST_PASSED_MACRO_V2 15, msg_t15
    jmp t41_done
t41_fail:
    TEST_FAILED_MACRO_V2 15, msg_t15
t41_done:

    ; --- T42: signs differ, large gap: 1.0 > -2^-127 ---
    FP_LOAD1_MACRO TestValue::val_1
    FP_LOAD2_MACRO TestValue::val_min_neg
    jsr FP_COMPARE
    bmi t42_fail
    beq t42_fail
    TEST_PASSED_MACRO_V2 16, msg_t16
    jmp t42_done
t42_fail:
    TEST_FAILED_MACRO_V2 16, msg_t16
t42_done:

    ; --- T43: canonical zero < 1.0 ---
    FP_LOAD1_MACRO TestValue::val_0
    FP_LOAD2_MACRO TestValue::val_1
    jsr FP_COMPARE
    bpl t43_fail
    TEST_PASSED_MACRO_V2 17, msg_t17
    jmp t43_done
t43_fail:
    TEST_FAILED_MACRO_V2 17, msg_t17
t43_done:

    ; --- T44: 1.0 > canonical zero ---
    FP_LOAD1_MACRO TestValue::val_1
    FP_LOAD2_MACRO TestValue::val_0
    jsr FP_COMPARE
    bmi t44_fail
    beq t44_fail
    TEST_PASSED_MACRO_V2 18, msg_t18
    jmp t44_done
t44_fail:
    TEST_FAILED_MACRO_V2 18, msg_t18
t44_done:

    ; --- T45: non-canonical zero (exp=0, mant!=0) < 1.0 ---
    ;     Zero convention is exp=0 regardless of mantissa.
    FP_LOAD1_MACRO TestValue::val_nczero
    FP_LOAD2_MACRO TestValue::val_1
    jsr FP_COMPARE
    bpl t45_fail
    TEST_PASSED_MACRO_V2 19, msg_t19
    jmp t45_done
t45_fail:
    TEST_FAILED_MACRO_V2 19, msg_t19
t45_done:

    ; --- T46: 1.0 > non-canonical zero ---
    FP_LOAD1_MACRO TestValue::val_1
    FP_LOAD2_MACRO TestValue::val_nczero
    jsr FP_COMPARE
    bmi t46_fail
    beq t46_fail
    TEST_PASSED_MACRO_V2 20, msg_t20
    jmp t46_done
t46_fail:
    TEST_FAILED_MACRO_V2 20, msg_t20
t46_done:

    ; --- T47: zero == zero ---
    FP_LOAD1_MACRO TestValue::val_0
    FP_LOAD2_MACRO TestValue::val_0
    jsr FP_COMPARE
    beq t47_pass
    TEST_FAILED_MACRO_V2 21, msg_t21
    jmp t47_done
t47_pass:
    TEST_PASSED_MACRO_V2 21, msg_t21
t47_done:

    ; --- T48: FP1 unchanged after large-gap compare ---
    FP_LOAD1_MACRO TestValue::val_min_pos
    FP_LOAD2_MACRO TestValue::val_1
    jsr FP_COMPARE
    TEST_FP1CMP_MACRO 22, msg_t22, TestValue::val_min_pos

    rts

.segment "RODATA"
msg_header: .asciiz "comparision: compare"
msg_t00:    .asciiz "fp1 = fp2"
msg_t01:    .asciiz "fp1 > fp2"
msg_t02:    .asciiz "fp1 < fp2"
msg_t03:    .asciiz "fp1 not clobbered"
msg_t04:    .asciiz "macro compare"
msg_t05:    .asciiz "gap 2^-127 < 1"
msg_t06:    .asciiz "gap 1 > 2^-127"
msg_t07:    .asciiz "gap max > 1"
msg_t08:    .asciiz "gap 1 < max"
msg_t09:    .asciiz "diff24 1 > x"
msg_t10:    .asciiz "diff25 1 > x"
msg_t11:    .asciiz "diff24 x < 1"
msg_t12:    .asciiz "diff25 x < 1"
msg_t13:    .asciiz "neg gap -1 < -min"
msg_t14:    .asciiz "neg gap -min > -1"
msg_t15:    .asciiz "mixed -min < 1"
msg_t16:    .asciiz "mixed 1 > -min"
msg_t17:    .asciiz "zero < 1"
msg_t18:    .asciiz "1 > zero"
msg_t19:    .asciiz "nczero < 1"
msg_t20:    .asciiz "1 > nczero"
msg_t21:    .asciiz "zero == zero"
msg_t22:    .asciiz "fp1 kept (gap)"

val_diff24: .byte $68, $40, $00, $00    ; +2^-24 (exp gap 24 vs 1.0)
val_diff25: .byte $67, $40, $00, $00    ; +2^-25 (exp gap 25 vs 1.0)
.endproc
