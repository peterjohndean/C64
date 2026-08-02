.include "labels_fp.s"

.export FP_FROM_INT16

.import FP_FLOAT

.segment "CODE"
; ============================================================
; PROCEDURE : FP_FROM_INT16_PROC
; Purpose : Convert a signed 16-bit integer to a float. Thin
;           wrapper around FP_FLOAT for callers who prefer to
;           pass the value in registers rather than pre-loading
;           FP1_MANT/FP1_MANT+1 themselves.
; Entry   : A = high byte, X = low byte
; Exit    : FP1 = float(A:X)
; Destroys: A, X, Y
; ============================================================
.proc FP_FROM_INT16_PROC
    sta FP1_MANT
    stx FP1_MANT+1
    jsr FP_FLOAT
    rts
.endproc

; ------------------------------------------------------------
; Short public aliases, matching library_fp.s's FP_FADD-style
; naming (no _PROC suffix) so the whole library presents one
; consistent calling convention. The _PROC names above still work
; too - these are just the preferred names for call sites.
; ------------------------------------------------------------
FP_FROM_INT16  = FP_FROM_INT16_PROC
