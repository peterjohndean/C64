
.include "tr.inc"

.export tr_int24

.import FP_FROM_INT24, FP_TO_INT24
.import FP_FROM_UINT24
.import TEST_PASSED, TEST_FAILED

.proc tr_int24
    ; --- T09: FP_FROM_INT24 / FP_TO_INT24 round trip ---
    ; 1,048,575 = $0FFFFF (largest 24-bit value with all mantissa
    ; bits set except the sign - exercises all 3 bytes)
    lda #$0f
    ldx #$ff
    ldy #$ff
    jsr FP_FROM_INT24
    jsr FP_TO_INT24
    lda FP1_MANT
    cmp #$0f
    bne t09_fail
    lda FP1_MANT+1
    cmp #$ff
    bne t09_fail
    lda FP1_MANT+2
    cmp #$ff
    beq t09_pass
t09_fail:
    TEST_FAILED_MACRO_V2 0, msg_t00
    jmp t09_done
t09_pass:
    TEST_PASSED_MACRO_V2 0, msg_t00
t09_done:

    ; --- T53: FP_TO_INT24 overflow detection at exact boundary --
    ; float(8,388,608) does not fit in a signed 24-bit integer (max 8,388,607).
    ; 8,388,608 is $800000 in hex, which flips the 24-bit sign bit.
    lda #$80
    ldx #$00
    ldy #$00
    jsr FP_FROM_UINT24
    FP_ERROR_INIT_MACRO t53_recover
    jsr FP_TO_INT24
    ; should never reach here - the trap redirects to t53_recover
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 1, msg_t01
    jmp t53_done
t53_recover:
    lda FP_ERROR_CODE
    cmp #0                          ; Expect Code 0: Generic Overflow
    bne t53_fail
    TEST_PASSED_MACRO_V2 1, msg_t01
    jmp t53_done
t53_fail:
    TEST_FAILED_MACRO_V2 1, msg_t01
t53_done:
    rts

.segment "RODATA"
msg_t00:    .asciiz     "int24 (1,048,575) round trip"
msg_t01:    .asciiz     "int24 (8388608>max) overflow"
.endproc
