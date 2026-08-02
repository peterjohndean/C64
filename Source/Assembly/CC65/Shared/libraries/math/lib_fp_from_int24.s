.include "labels_fp.s"

.export FP_FROM_INT24

.import FP_NORM

.segment "CODE"
; ============================================================
; PROCEDURE : FP_FROM_INT24_PROC
; Purpose : Convert a signed 24-bit integer to a float, without
;           routing through FP_FLOAT's 16-bit-only entry (which
;           always zeroes the mantissa's 3rd byte).
; Entry   : A = bits 23-16 (MSB), X = bits 15-8, Y = bits 7-0 (LSB)
; Exit    : FP1 = float(A:X:Y)
; Destroys: A, X, Y
; ============================================================
.proc FP_FROM_INT24_PROC
    sta FP1_MANT
    stx FP1_MANT+1
    sty FP1_MANT+2
    lda #$96                ; seed exponent for a 24-bit integer - see
    sta FP1_EXP             ; the file header derivation
    jsr FP_NORM             ; normalize directly; all 3 mantissa bytes
                            ; are already populated, so we skip
                            ; FP_FLOAT's 16-bit setup entirely
    rts
.endproc

; ------------------------------------------------------------
; Short public aliases, matching library_fp.s's FP_FADD-style
; naming (no _PROC suffix) so the whole library presents one
; consistent calling convention. The _PROC names above still work
; too - these are just the preferred names for call sites.
; ------------------------------------------------------------
FP_FROM_INT24  = FP_FROM_INT24_PROC
