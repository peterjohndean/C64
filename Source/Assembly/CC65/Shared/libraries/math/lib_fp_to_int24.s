.include "labels_fp.s"

.export FP_TO_INT24

.import FP_RTAR

.segment "CODE"
; ============================================================
; PROCEDURE : FP_TO_INT24_PROC
; Purpose : Truncate FP1 to a signed 24-bit integer, toward zero.
;           Same technique as FP_TO_INT16_PROC, targeting the
;           24-bit seed exponent $96 instead of $8E - see the file
;           header for the derivation of both constants.
; Entry   : FP1 = value to truncate
; Exit    : FP1_MANT = high byte, FP1_MANT+1 = mid byte,
;           FP1_MANT+2 = low byte of the truncated integer
; Destroys: A; FP1 (in place)
; ============================================================
.proc FP_TO_INT24_PROC
@fix_conv:
    lda FP1_EXP
    bpl @fix_underflow      ; |value| < 1.0: result 0
    cmp #$96                ; already at 24-bit integer scale?
    beq @fix_round
    jsr FP_RTAR
    jmp @fix_conv

@fix_round:
    bit FP1_MANT            ; result negative?
    bpl @fix_rts
    lda FP_EXT              ; anything truncated off the low end?
                            ; (FP_EXT, not FP1_MANT+2, since all
                            ; 3 mantissa bytes are now part of
                            ; the integer itself)
    beq @fix_rts
    inc FP1_MANT+2          ; round toward zero, propagating
    bne @fix_rts            ; the carry through all 3 bytes
    inc FP1_MANT+1          ; if needed
    bne @fix_rts
    inc FP1_MANT

@fix_rts:
    rts

@fix_underflow:
    lda #0
    sta FP1_MANT
    sta FP1_MANT+1
    sta FP1_MANT+2
    rts
.endproc


; ------------------------------------------------------------
; Short public aliases, matching library_fp.s's FP_FADD-style
; naming (no _PROC suffix) so the whole library presents one
; consistent calling convention. The _PROC names above still work
; too - these are just the preferred names for call sites.
; ------------------------------------------------------------
FP_TO_INT24  = FP_TO_INT24_PROC
