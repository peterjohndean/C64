.include "labels_fp.s"

.export FP_TO_INT16

.import FP_RTAR

.segment "CODE"
; ============================================================
; PROCEDURE : FP_TO_INT16_PROC
; Purpose : Truncate FP1 to a signed 16-bit integer, toward zero
;           (ENTIER semantics: +24.63 -> +24, -61.2 -> -61), with
;           |value| < 1.0 explicitly zeroed rather than looped
;           through. Adapted from the Apple II ROM's FIX
;           (wozfp3.txt), which corrects the plain right-shift
;           truncation's floor-toward-negative-infinity behaviour
;           for negative values with a nonzero fractional remainder.
; Entry   : FP1 = value to truncate
; Exit    : FP1_MANT = high byte, FP1_MANT+1 = low byte of the
;           truncated integer
; Destroys: A; FP1 (in place)
; ============================================================
.proc FP_TO_INT16_PROC
@fix_conv:
    lda FP1_EXP
    bpl @fix_underflow          ; exponent < 2^0: |value| < 1.0, result 0
    cmp #$8e                    ; already at 16-bit integer scale?
    beq @fix_round
    jsr FP_RTAR                 ; not yet: shift right one bit and retry
    jmp @fix_conv

@fix_round:
    bit FP1_MANT                ; result negative?
    bpl @fix_rts                ; positive (or zero): truncation exact
    lda FP1_MANT+2              ; negative: was anything truncated
    beq @fix_rts                ; off the low end? no: exact
    inc FP1_MANT+1              ; yes: round toward zero (add 1)
    bne @fix_rts
    inc FP1_MANT

@fix_rts:
    rts

@fix_underflow:
    lda #0
    sta FP1_MANT
    sta FP1_MANT+1
    rts
.endproc

; ------------------------------------------------------------
; Short public aliases, matching library_fp.s's FP_FADD-style
; naming (no _PROC suffix) so the whole library presents one
; consistent calling convention. The _PROC names above still work
; too - these are just the preferred names for call sites.
; ------------------------------------------------------------
FP_TO_INT16  = FP_TO_INT16_PROC
