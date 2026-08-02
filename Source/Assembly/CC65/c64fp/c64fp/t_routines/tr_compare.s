
.include "tr.inc"

.export tr_compare

.import FP_COMPARE
.import TEST_PASSED, TEST_FAILED, TEST_FP1CMP

.proc tr_compare
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
    bmi t27_fail                    ; must not be "less"
    beq t27_fail                    ; must not be "equal"
    TEST_PASSED_MACRO_V2 1, msg_t01
    jmp t27_done
t27_fail:
    TEST_FAILED_MACRO_V2 1, msg_t01
t27_done:

    ; --- T28: FP_COMPARE_PROC - FP1 < FP2 ---
    FP_LOAD1_MACRO TestValue::val_neg5
    FP_LOAD2_MACRO TestValue::val_12
    jsr FP_COMPARE
    bpl t28_fail                     ; must be "less" ($FF, negative)
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
    rts

.segment "RODATA"
msg_t00:    .asciiz "compare (fp1=fp2)"
msg_t01:    .asciiz "compare (fp1>fp2)"
msg_t02:    .asciiz "compare (fp1<fp2)"
msg_t03:    .asciiz "compare (!clobbered)"
msg_t04:    .asciiz "compare (macro)"
.endproc
