.include "labels_fp.s"

.export FP_FROM_UINT8

.import FP_FLOAT

.segment "CODE"
; ============================================================
; PROCEDURE : FP_FROM_UINT8_PROC
; Purpose : Convert an UNSIGNED 8-bit integer to a float. Simpler
;           than the signed version - an 8-bit value zero-extended
;           to 16 bits is always non-negative in the 16-bit
;           representation FP_FLOAT expects, so there's no sign
;           edge case to handle at all.
; Entry   : A = unsigned 8-bit value (0-255)
; Exit    : FP1 = float(A)
; Destroys: A, X, Y
; ============================================================
.proc FP_FROM_UINT8_PROC
    ldx #0
    sta FP1_MANT+1
    stx FP1_MANT
    jsr FP_FLOAT
    rts
.endproc

; ------------------------------------------------------------
; Short public aliases, matching library_fp.s's FP_FADD-style
; naming (no _PROC suffix) so the whole library presents one
; consistent calling convention. The _PROC names above still work
; too - these are just the preferred names for call sites.
; ------------------------------------------------------------
FP_FROM_UINT8  = FP_FROM_UINT8_PROC
