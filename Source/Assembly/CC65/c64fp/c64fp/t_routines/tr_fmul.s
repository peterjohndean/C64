
.include "tr.inc"

.export tr_fmul

.import FP_FMUL
.import FP_FROM_UINT16
.import TEST_FP1CMP, TEST_PASSED, TEST_FAILED

.proc tr_fmul
    ; --- T02: FMUL  12 * -5 = -60 ---
    FP_LOAD1_MACRO TestValue::val_12
    FP_LOAD2_MACRO TestValue::val_neg5
    jsr FP_FMUL
    TEST_FP1CMP_MACRO 0, msg_t00, TestValue::val_neg60

    ; --- T34: error handling - generic overflow (code 0) -------------
    ; Repeated squaring of 10,000.0 guarantees overflow within a
    ; handful of iterations regardless of exact starting value or
    ; exponent boundary arithmetic (10000^2=10^8, ^2=10^16, ^2=10^32,
    ; ^2=10^64 - already far past ~1.7*10^38 by the 4th squaring) -
    ; deliberately not relying on hitting an exact boundary byte
    ; pattern, which would be far more fragile to get right by hand.
    lda #>10000
    ldx #<10000
    jsr FP_FROM_UINT16                  ; FP1 = 10000.0
    FP_ERROR_INIT_MACRO t34_recover
    ldy #10                             ; well more iterations than needed
t34_loop:
    FP_COPY1TO2_MACRO
    jsr FP_FMUL                         ; FP1 = FP1 * FP1
    dey
    bne t34_loop
    ; should never reach here - see comment above
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 1, msg_t01
    jmp t34_done
t34_recover:
    lda FP_ERROR_CODE
    cmp #0
    bne t34_fail
    TEST_PASSED_MACRO_V2 1, msg_t01
    jmp t34_done
t34_fail:
    TEST_FAILED_MACRO_V2 1, msg_t01
t34_done:
    rts

.segment "RODATA"
msg_t00:        .asciiz     "fmul (-60)"            ;12 * -5 = -60"
msg_t01:        .asciiz     "fmul (trap overflow)"
.endproc
