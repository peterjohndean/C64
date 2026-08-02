
.include "tr.inc"

.export tr_log

.import FP_LOG, FP_LOG10
.import FP_TO_ASCII
.import TEST_CHECK, TEST_FP1CMP, TEST_PASSED, TEST_FAILED

.proc tr_log
    ; --- T13: LOG(0.5) - THE ERRATA TEST ---
    ; ln(0.5) = -0.6931472. This is the exact scenario Rankin's
    ; errata fixes: argument < 1.0, so FP_LOG_PROC's internal
    ; power-of-2 exponent is NEGATIVE. Without [ERRATA FIX] applied
    ; in library_fp.s, this comes out wildly wrong (a huge number
    ; of the wrong sign/magnitude) because the un-fixed code zero-
    ; extends that negative exponent instead of sign-extending it.
    ; Expect an exponent around $7F (representing 2^-1, since
    ; |-0.693| is between 0.5 and 1.0) with a NEGATIVE mantissa
    ; (top bit of the second byte set). If you see a large exponent
    ; ($C0-$FF) instead, the errata fix did not take effect - check
    ; lib_fp.s's `cont` label.
    FP_LOAD1_MACRO TestValue::val_0_5
    jsr FP_LOG
    TEST_CHECK_MACRO_V2 0, msg_t00  ; 7fa746f4 = -0.6931

    ; --- T14: LOG(1) - expect ~0.0 ---
    FP_LOAD1_MACRO TestValue::val_1
    jsr FP_LOG
;    TEST_CHECK_MACRO_V2 1, msg_t01  ; 00000000 = 0.0000
    TEST_FP1CMP_MACRO 1, msg_t01, TestValue::val_0

    ; --- T15: LOG10(100) - expect ~2.0 ($81,$40,$xx,$xx) ---
    FP_LOAD1_MACRO TestValue::val_100
    jsr FP_LOG10
    TEST_CHECK_MACRO_V2 2, msg_t02  ; 807fffff = 1.9999 (~2.0000)

    ; --- T32: error handling - log domain error (code 2) ------------
    FP_LOAD1_MACRO TestValue::val_neg5           ; log(-5) is undefined
    FP_ERROR_INIT_MACRO t32_recover
    jsr FP_LOG
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 3, msg_t03
    jmp t32_done
t32_recover:
    lda FP_ERROR_CODE
    cmp #2
    bne t32_fail
    TEST_PASSED_MACRO_V2 3, msg_t03
    jmp t32_done
t32_fail:
    TEST_FAILED_MACRO_V2 3, msg_t03
t32_done:

    ; --- T50: error handling - log domain error (code 2) ------------
    ; LOG(0) is mathematically undefined (approaches -infinity) and
    ; must explicitly trigger the domain error trap, identical to LOG(-5).
    FP_LOAD1_MACRO TestValue::val_0
    FP_ERROR_INIT_MACRO t50_recover
    jsr FP_LOG
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 4, msg_t04
    jmp t50_done
t50_recover:
    lda FP_ERROR_CODE
    cmp #2
    bne t50_fail
    TEST_PASSED_MACRO_V2 4, msg_t04
    jmp t50_done
t50_fail:
    TEST_FAILED_MACRO_V2 4, msg_t04
t50_done:
    rts

.segment "RODATA"
msg_t00:        .asciiz     "log (0.5) -> -0.6931472"
msg_t01:        .asciiz     "log (0)   ->  0.0"
msg_t02:        .asciiz     "log (100) ->  2.0"
msg_t03:        .asciiz     "log (trap -5)"
msg_t04:        .asciiz     "log (trap  0)"
.endproc
