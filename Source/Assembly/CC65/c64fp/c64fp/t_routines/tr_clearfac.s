
.include "tr.inc"

.export tr_clearfac

.import FP_CLEANUP_FAC1FAC2
.import TEST_PASSED, TEST_FAILED

.segment "CODE"
.proc tr_clearfac
    TEST_ROUTINE_HEADER_MACRO msg_header

    ; --- T19: FP_CLEANUP_FAC1FAC2 zeroes the full $61-$70 workspace ---
    FP_LOAD1_MACRO TestValue::val_12
    FP_LOAD2_MACRO TestValue::val_neg5
    jsr FP_CLEANUP_FAC1FAC2
    ldx #0
t19_check:
    lda $61,x
    bne t19_fail
    inx
    cpx #16
    bne t19_check
    TEST_PASSED_MACRO_V2 0, msg_t00
    jmp t19_done
t19_fail:
    TEST_FAILED_MACRO_V2 0, msg_t00
t19_done:
    rts

.segment "RODATA"
msg_header: .asciiz "c64 basic fac1 & fac2 cleanup"
msg_t00:    .asciiz "cleanup fac1/fac2"
.endproc
