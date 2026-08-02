
.include "tr.inc"

.export tr_uint8

.import FP_FROM_UINT8, FP_TO_UINT8
.import FP_FROM_UINT16
.import TEST_PASSED, TEST_FAILED

.proc tr_uint8
    ; --- T20: FP_FROM_UINT8 / FP_TO_UINT8 round trip (200) --------
    ; 200 doesn't fit in a SIGNED 8-bit value (max 127) - this is
    ; exactly the case the unsigned routines exist for.
    lda #200
    jsr FP_FROM_UINT8
    jsr FP_TO_UINT8
    bcs t20_fail                  ; carry set = unexpected overflow
    cmp #200
    beq t20_pass
t20_fail:
    TEST_FAILED_MACRO_V2 0, msg_t00
    jmp t20_done
t20_pass:
    TEST_PASSED_MACRO_V2 0, msg_t00
t20_done:

    ; --- T21: FP_TO_UINT8 overflow detection (300 > 255) -----------
    lda #>300
    ldx #<300
    jsr FP_FROM_UINT16
    jsr FP_TO_UINT8
    bcc t21_fail                  ; carry SHOULD be set (overflow)
    TEST_PASSED_MACRO_V2 1, msg_t01
    jmp t21_done
t21_fail:
    TEST_FAILED_MACRO_V2 1, msg_t01
t21_done:
    rts

.segment "RODATA"
msg_t00:        .asciiz     "uint8 (200) round trip"
msg_t01:        .asciiz     "uint8 (300>200) overflow"
.endproc

