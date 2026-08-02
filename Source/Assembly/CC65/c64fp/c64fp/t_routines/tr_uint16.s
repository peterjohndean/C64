
.include "tr.inc"

.export tr_uint16

.import FP_FROM_INT8
.import FP_FROM_UINT16, FP_TO_UINT16
.import TEST_PASSED, TEST_FAILED

.proc tr_uint16
    ; --- T22: FP_FROM_UINT16 / FP_TO_UINT16 round trip (50000) -----
    ; 50000 > 32767, so its raw 16-bit bit pattern has bit 15 set -
    ; exactly the case that would be misread as negative without the
    ; explicit unsigned handling (see FP_FROM_UINT16_PROC's header).
    lda #>50000
    ldx #<50000
    jsr FP_FROM_UINT16
    jsr FP_TO_UINT16
    bcs t22_fail                   ; carry set = unexpected overflow
    lda FP1_MANT
    cmp #>50000
    bne t22_fail
    lda FP1_MANT+1
    cmp #<50000
    beq t22_pass
t22_fail:
    TEST_FAILED_MACRO_V2 0, msg_t00
    jmp t22_done
t22_pass:
    TEST_PASSED_MACRO_V2 0, msg_t00
t22_done:

    ; --- T23: FP_TO_UINT16 rejects negative input -------------------
    lda #<(-5)
    jsr FP_FROM_INT8                ; FP1 = -5.0
    jsr FP_TO_UINT16
    bcc t23_fail                    ; carry SHOULD be set (negative)
    TEST_PASSED_MACRO_V2 1, msg_t01
    jmp t23_done
t23_fail:
    TEST_FAILED_MACRO_V2 1, msg_t01
t23_done:
    rts

.segment "RODATA"
msg_t00:        .asciiz     "uint16 (50k) round trip"
msg_t01:        .asciiz     "uint16 (-5) rejects negative"
.endproc

