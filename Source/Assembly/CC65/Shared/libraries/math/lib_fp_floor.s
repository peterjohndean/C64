.include "labels_fp.s"
.include "macros_fp.s"

.export FP_FLOOR

.import FP_FSUB
.import FP_COMPARE
.import FP_TRUNC

.segment "CODE"

; ============================================================
; PROCEDURE : FP_FLOOR_PROC
; Purpose : Round FP1 toward -infinity, in place.
; Entry   : FP1 loaded
; Exit    : FP1 = floor(FP1)
; Destroys: A, X, Y; FP2
; Algorithm: floor(x) equals trunc(x) for x >= 0 (truncating toward
;            zero and toward -infinity are the same thing once you
;            aren't crossing zero), and equals trunc(x) - 1 for
;            negative, non-integer x (truncating a negative value
;            moves toward zero, i.e. away from -infinity, so floor
;            needs one more step past it - unless x was already a
;            whole number, in which case trunc(x) == x and no
;            adjustment is needed).
; ============================================================
.proc FP_FLOOR_PROC
    lda FP1_MANT
    sta orig_sign
    FP_STORE1_MACRO orig_backup
    jsr FP_TRUNC
    lda orig_sign
    bpl @done                       ; original was >= 0: floor == trunc
    FP_COMPARE_TO_MACRO orig_backup
    beq @done                       ; original was already a whole
                                    ; number: no adjustment needed
    FP_COPY1TO2_MACRO               ; FP2 = trunc(x)
    FP_LOAD1_MACRO one_const        ; FP1 = 1.0
    jsr FP_FSUB                     ; FP1 = FP2 - FP1 = trunc(x) - 1.0

@done:
    rts

orig_sign:      .byte 0
orig_backup:    .res 4,0
one_const:      .byte $80,$40,$00,$00   ; 1.0
.endproc

; ------------------------------------------------------------
; Short public aliases, matching the rest of the library's
; FP_FADD-style naming (no _PROC suffix).
; ------------------------------------------------------------
FP_FLOOR = FP_FLOOR_PROC
