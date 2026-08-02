
.include "tr.inc"

.export tr_int16

.import FP_FADD
.import FP_FLOAT
.import FP_TO_INT16
.import FP_FROM_UINT16
.import TEST_PASSED, TEST_FAILED

.proc tr_int16
    ; --- T06: FLOAT/FIX round trip, positive (+) ---
    lda #$00
    sta FP1_MANT
    lda #$7b                    ; 16-bit integer $007B = 123
    sta FP1_MANT+1
    jsr FP_FLOAT
    jsr FP_TO_INT16
    lda FP1_MANT
    cmp #$00
    bne t06_fail
    lda FP1_MANT+1
    cmp #123
    beq t06_pass
t06_fail:
    TEST_FAILED_MACRO_V2 0, msg_t00
    jmp t06_done
t06_pass:
    TEST_PASSED_MACRO_V2 0, msg_t00
t06_done:

    ; --- T07: FLOAT/FIX round trip, negative (-), truncate toward
    ;          zero (-61.9's integer part is -61, not -62) ---
    lda #$ff
    sta FP1_MANT
    lda #<(-62)
    sta FP1_MANT+1
    jsr FP_FLOAT                        ; FP1 = -62.0
    FP_LOAD2_MACRO TestValue::val_0_1
    jsr FP_FADD                         ; FP1 = -61.9
    jsr FP_TO_INT16
    lda FP1_MANT
    cmp #$ff
    bne t07_fail
    lda FP1_MANT+1
    cmp #<(-61)
    beq t07_pass
t07_fail:
    TEST_FAILED_MACRO_V2 1, msg_t01
    jmp t07_done
t07_pass:
    TEST_PASSED_MACRO_V2 1, msg_t01
t07_done:

    ; --- T52: FP_TO_INT16 overflow detection at exact boundary --
    ; float(32768) does not fit in a signed 16-bit integer (max 32767).
    ; We construct it safely using the UINT16 parser, then push it to INT16.
    lda #>32768
    ldx #<32768
    jsr FP_FROM_UINT16
    FP_ERROR_INIT_MACRO t52_recover
    jsr FP_TO_INT16
    ; should never reach here - the trap redirects to t52_recover
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 2, msg_t02
    jmp t52_done
t52_recover:
    lda FP_ERROR_CODE
    cmp #0
    bne t52_fail
    TEST_PASSED_MACRO_V2 2, msg_t02
    jmp t52_done
t52_fail:
    TEST_FAILED_MACRO_V2 2, msg_t02
t52_done:
    rts

.segment "RODATA"
msg_t00:    .asciiz     "int16 (123) round trip"
msg_t01:    .asciiz     "int16 (-61) round trip"
msg_t02:    .asciiz     "int16 (32768>max) overflow"
.endproc
