
.include "tr.inc"

.export tr_swap

.import FP_SWAP
.import TEST_FP1CMP

.proc tr_swap
    ; --- T18: FP_SWAP round trip - swapping twice must restore FP1.
    ;          (FP_SWAP itself already existed - FP_CORE_PROC.swap,
    ;          aliased in lib_fp.s - this just gives it a direct
    ;          test of its own rather than only exercising it
    ;          indirectly through LOG/EXP.) ---
    FP_LOAD1_MACRO TestValue::val_12
    FP_LOAD2_MACRO TestValue::val_neg5
    jsr FP_SWAP
    jsr FP_SWAP
    TEST_FP1CMP_MACRO 0, msg_t00, TestValue::val_12
    rts

.segment "RODATA"
msg_t00:   .asciiz "swap (round trip)"
.endproc
