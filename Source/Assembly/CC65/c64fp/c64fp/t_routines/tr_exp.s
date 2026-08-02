
.include "tr.inc"

.export tr_exp

.import FP_EXP
.import FP_FROM_UINT16
.import TEST_CHECK, TEST_FP1CMP
.import TEST_PASSED, TEST_FAILED

.proc tr_exp
    ; --- T16: EXP(0) - expect ~1.0 ($80,$40,$xx,$xx) ---
    FP_LOAD1_MACRO TestValue::val_0
    jsr FP_EXP
;    TEST_CHECK_MACRO_V2 0, msg_t00  ; 80400000 = 1.0000
    TEST_FP1CMP_MACRO 0, msg_t00, TestValue::val_1

    ; --- T33: error handling - exp overflow (code 3) ---
    ; e^1000 is astronomically beyond this format's ~1.7*10^38 range.
    lda #>1000
    ldx #<1000
    jsr FP_FROM_UINT16
    FP_ERROR_INIT_MACRO t33_recover
    jsr FP_EXP
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 1, msg_t01
    jmp t33_done
t33_recover:
    lda FP_ERROR_CODE
    cmp #3
    bne t33_fail
    TEST_PASSED_MACRO_V2 1, msg_t01
    jmp t33_done
t33_fail:
    TEST_FAILED_MACRO_V2 1, msg_t01
t33_done:
    rts

.segment "RODATA"
msg_t00:        .asciiz     "exp (0) -> 1.0"
msg_t01:        .asciiz     "exp (trap overflow)"
.endproc
