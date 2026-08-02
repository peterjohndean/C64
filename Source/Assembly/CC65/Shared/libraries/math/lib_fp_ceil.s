.include "labels_fp.s"
.include "macros_fp.s"

.export FP_CEIL

.import FP_FSUB
.import FP_COMPARE
.import FP_TRUNC

.segment "CODE"
; ============================================================
; PROCEDURE : FP_CEIL_PROC
; Purpose : Round FP1 toward +infinity, in place.
; Entry   : FP1 loaded
; Exit    : FP1 = ceil(FP1)
; Destroys: A, X, Y; FP2
; Algorithm: mirror of FP_FLOOR_PROC - ceil(x) equals trunc(x) for
;            x <= 0, and trunc(x) + 1 for positive, non-integer x.
; ============================================================
.proc FP_CEIL_PROC
    lda FP1_MANT
    sta orig_sign
    FP_STORE1_MACRO orig_backup
    jsr FP_TRUNC
    lda orig_sign
    bmi @done                       ; original was negative: ceil == trunc
    FP_COMPARE_TO_MACRO orig_backup
    beq @done                       ; original was already whole
    FP_COPY1TO2_MACRO               ; FP2 = trunc(x)
    FP_LOAD1_MACRO neg_one_const    ; FP1 = -1.0
    jsr FP_FSUB                     ; FP1 = FP2 - FP1
                                    ; = trunc(x) - (-1.0)
                                    ; = trunc(x) + 1.0
@done:
    rts

orig_sign:      .byte 0
orig_backup:    .res 4,0
neg_one_const:  .byte $7f,$80,$00,$00
; -1.0 (NOTE: NOT the naive 2's
; complement of +1.0's bytes ($80,$C0,$00,$00) - that pattern isn't
; normalized. 1.0's mantissa sits exactly at the positive boundary
; (an exact power of 2), and negating a boundary mantissa needs an
; extra renormalization step (shift left, decrement exponent) to
; become valid again - the same class of edge case documented at
; length in library_fp_ieee754.s. Verified against the real NORM
; algorithm, not just computed by hand.
.endproc

; ------------------------------------------------------------
; Short public aliases, matching the rest of the library's
; FP_FADD-style naming (no _PROC suffix).
; ------------------------------------------------------------
FP_CEIL = FP_CEIL_PROC
