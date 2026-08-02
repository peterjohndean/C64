
.include "tr.inc"

.export tr_fsub

.import FP_FSUB
.import TEST_FP1CMP

.proc tr_fsub
    ; --- T01: FSUB - confirms the FP2-FP1 convention ---
    ; FP1=-5, FP2=+7 -> result = FP2-FP1 = 7-(-5) = 12. This
    ; doesn't itself exercise the errata (that's LOG's job, T14),
    ; but confirms FSUB's convention independently before anything
    ; downstream (LOG uses FSUB internally) is trusted.
    FP_LOAD1_MACRO TestValue::val_neg5
    FP_LOAD2_MACRO TestValue::val_7
    jsr FP_FSUB
    TEST_FP1CMP_MACRO 0, msg_t00, TestValue::val_12

    ; --- T54: FSUB Zero-Crossing (12.0 - 12.0 = 0.0) ---
    ; Ensures the normalizer correctly catches total cancellation
    ; and returns a canonical zero, not a subnormal float.
    FP_LOAD1_MACRO TestValue::val_12
    FP_LOAD2_MACRO TestValue::val_12
    jsr FP_FSUB
    TEST_FP1CMP_MACRO 1, msg_t01, TestValue::val_0
    rts

.segment "RODATA"
msg_t00:        .asciiz     "fsub (12) ";7 - (-5) = 12"
msg_t01:        .asciiz     "fsub (0.0)";zero-cross"
.endproc
