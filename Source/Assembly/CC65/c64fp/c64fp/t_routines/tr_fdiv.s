
.include "tr.inc"

.export tr_fdiv

.import FP_FDIV
.import TEST_FP1CMP
.import TEST_PASSED, TEST_FAILED

.proc tr_fdiv
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
    rts

.segment "RODATA"
msg_t00:        .asciiz     "fdiv (-5) "        ;-60 / 12 = -5"
msg_t01:        .asciiz     "fdiv (trap /0)"
.endproc
