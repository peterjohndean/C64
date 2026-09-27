
.include "tr.inc"

.export tr_uint24

.import FP_FROM_INT8
.import FP_FROM_UINT24, FP_TO_UINT24
.import TEST_PASSED, TEST_FAILED

.segment "CODE"
.proc tr_uint24
    TEST_ROUTINE_HEADER_MACRO msg_header

    ; --- T24: FP_FROM_UINT24 / FP_TO_UINT24 round trip (10,000,000)
    ; 10,000,000 > 8,388,608 (2^23) - the 24-bit analogue of T23.
    ; 10,000,000 = $98,$96,$80
    lda #$98
    ldx #$96
    ldy #$80
    jsr FP_FROM_UINT24
    jsr FP_TO_UINT24
    bcs t24_fail
    lda FP1_MANT
    cmp #$98
    bne t24_fail
    lda FP1_MANT+1
    cmp #$96
    bne t24_fail
    lda FP1_MANT+2
    cmp #$80
    beq t24_pass
t24_fail:
    TEST_FAILED_MACRO_V2 0, msg_t00
    jmp t24_done
t24_pass:
    TEST_PASSED_MACRO_V2 0, msg_t00
t24_done:

    ; --- T25: FP_TO_UINT24 rejects negative input ---
    lda #<(-1)
    jsr FP_FROM_INT8        ; FP1 = -1.0
    jsr FP_TO_UINT24
    bcc t25_fail
    TEST_PASSED_MACRO_V2 1, msg_t01
    jmp t25_done
t25_fail:
    TEST_FAILED_MACRO_V2 1, msg_t01
t25_done:
    rts

.segment "RODATA"
msg_header: .asciiz "conversion: uint24"
msg_t00:    .asciiz "10m roundtrip"
msg_t01:    .asciiz "-1 rejects negative"
.endproc

