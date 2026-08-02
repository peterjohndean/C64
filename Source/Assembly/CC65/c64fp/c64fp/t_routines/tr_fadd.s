
.include "tr.inc"

.export tr_fadd

.import FP_FADD
.import TEST_FP1CMP, TEST_FAILED
.import OUTPUT_BYTETOHEX

.proc tr_fadd
    ; --- T00: FADD  12 + (-5) = 7 ---
    FP_LOAD1_MACRO TestValue::val_12
    FP_LOAD2_MACRO TestValue::val_neg5
    jsr FP_FADD
    TEST_FP1CMP_MACRO 0, msg_t00, TestValue::val_7

    ; --- T04: FADD 12 + 0 = 12 ---
    FP_LOAD1_MACRO TestValue::val_12
    FP_LOAD2_MACRO TestValue::val_0
    jsr FP_FADD
    TEST_FP1CMP_MACRO 1, msg_t01, TestValue::val_12

    ; --- T05: FADD across a LARGE exponent gap ---
    ; 1,000,000,000.0 + 0.5: FP2's exponent is ~30 less than FP1's,
    ; so the alignment trampoline (fadd/swpalg/algnsw/rtar/rtlog,
    ; see library_fp.s header) has to loop many times in one call.
    ; At this magnitude the smallest representable increment in a
    ; 24-bit mantissa is 128 (2^(29-22)), so 0.5 is genuinely below
    ; the representable precision and the correct answer is exactly
    ; 1,000,000,000.0 again - this is expected rounding behaviour,
    ; not a bug. (Verified computationally, not by hand - at
    ; 1,000,000's magnitude the resolution is only 0.125 and 0.5
    ; would NOT vanish; don't assume "big number + small number"
    ; always rounds away without checking the actual resolution.)
    FP_LOAD1_MACRO TestValue::val_1billion
    FP_LOAD2_MACRO TestValue::val_0_5
    jsr FP_FADD
    TEST_FP1CMP_MACRO 2, msg_t02, TestValue::val_1billion

    ; --- T35: FP_ERROR_INIT_MACRO/FP_ERROR_CLEAR_MACRO on the
    ;          SUCCESS path (no trap) - and, just as importantly,
    ;          proof that an ordinary computation still works
    ;          correctly right after T32-T35 deliberately triggered
    ;          four traps in a row, i.e. no lasting stack or zero
    ;          page corruption survived any of them.
    FP_ERROR_INIT_MACRO t35_unexpected_trap
    FP_LOAD1_MACRO TestValue::val_12
    FP_LOAD2_MACRO TestValue::val_neg5
    jsr FP_FADD                        ; ordinary, non-trapping op
    FP_ERROR_CLEAR_MACRO               ; success: discard T35's own guard
    TEST_FP1CMP_MACRO 3, msg_t03, TestValue::val_7
;    TEST_CHECK_MACRO TestValue::val_7, 35, msg_t35
    jmp t35_done
t35_unexpected_trap:
    ; only reached if the ordinary FADD above somehow trapped - it
    ; shouldn't have, and reaching this is a more serious problem
    ; than an ordinary test failure (test number 99 flags that).
    ; T36's own inner guard's return address was already consumed by
    ; FP_ERROR_PROC's rts to land here, but the OUTER guard armed at
    ; the very top of TEST_FP_PROC is still pending underneath it -
    ; jumps straight to t_final, which accounts for that (deliberately
    ; skipping remaining tests: an unexpected trap here means something is
    ; already wrong, so running more tests on top of it isn't useful).
    TEST_FAILED_MACRO_V2 3, msg_t03
    lda #99
    jsr OUTPUT_BYTETOHEX
    KERNAL_CHROUT_MACRO $0d

    ; Cleanup (trap) and back to BASIC
    lda TestRegistry::ntests
    sta TestData::id_group
    dec TestData::id_group

t35_done:
    rts

.segment "RODATA"
msg_t00:        .asciiz     "fadd (7)  ";(12 + -5   =  7)"
msg_t01:        .asciiz     "fadd (12) ";(12 +  0   = 12)"
msg_t02:        .asciiz     "fadd (0.5)";(1b +  0.5 = 1b)"
msg_t03:        .asciiz     "fadd (non-trap)"
.endproc
