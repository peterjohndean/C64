.include "labels_fp.s"

.export FP_TO_UINT8

.import FP_TO_INT16

.segment "CODE"
; ============================================================
; PROCEDURE : FP_TO_UINT8_PROC
; Purpose : Truncate FP1 to an unsigned 8-bit integer, toward
;           zero. Negative values, or values >= 256, are reported
;           as overflow.
; Entry   : FP1 = value to truncate
; Exit    : A = truncated value (valid only if carry clear)
;           carry clear = success, carry set = FP1 was negative or
;           its magnitude did not fit in 0..255
; Destroys: A, X, Y; FP1, FP2
; ============================================================
.proc FP_TO_UINT8_PROC
    lda FP1_MANT
    bmi @overflow           ; negative: can't represent as unsigned
    jsr FP_TO_INT16         ; round-toward-zero 16-bit truncation
    lda FP1_MANT            ; high byte must be exactly 0 for a
    bne @overflow           ; value to fit in 0..255
    lda FP1_MANT+1
    clc
    rts

@overflow:
    sec
    rts
.endproc

; ------------------------------------------------------------
; Short public aliases, matching lib_fp.s's FP_FADD-style
; naming (no _PROC suffix) so the whole library presents one
; consistent calling convention. The _PROC names above still work
; too - these are just the preferred names for call sites.
; ------------------------------------------------------------
FP_TO_UINT8  = FP_TO_UINT8_PROC
