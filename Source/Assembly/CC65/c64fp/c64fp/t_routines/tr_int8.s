
.include "tr.inc"

.export tr_int8

.import FP_FROM_INT8, FP_TO_INT8
.import FP_FROM_INT16
.import TEST_PASSED, TEST_FAILED

.proc tr_int8
    ; --- T08: FP_FROM_INT8 / FP_TO_INT8 round trip, negative ---
    lda #<(-100)
    jsr FP_FROM_INT8
    jsr FP_TO_INT8
    bcs t08_fail                  ; carry set = unexpected overflow
    cmp #<(-100)
    beq t08_pass
t08_fail:
    TEST_FAILED_MACRO_V2 0, msg_t00
    jmp t08_done
t08_pass:
    TEST_PASSED_MACRO_V2 0, msg_t00
t08_done:

    ; --- T10: FP_TO_INT8 overflow detection --------------------
    ; float(200) does not fit in a signed 8-bit integer (-128..127)
    lda #$00
    ldx #200
    jsr FP_FROM_INT16
    jsr FP_TO_INT8
    bcc t10_fail                  ; carry SHOULD be set (overflow)
    TEST_PASSED_MACRO_V2 1, msg_t01
    jmp t10_done
t10_fail:
    TEST_FAILED_MACRO_V2 1, msg_t01
t10_done:
    rts

.segment "RODATA"
msg_t00:    .asciiz "int8 (-100) round trip"
msg_t01:    .asciiz "int8 (200>max) overflow"
.endproc

