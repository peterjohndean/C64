.include "labels_fp.s"

.export FP_TO_INT8

.import FP_TO_INT16

.segment "CODE"
; ============================================================
; PROCEDURE : FP_TO_INT8_PROC
; Purpose : Truncate FP1 to a signed 8-bit integer, toward zero,
;           with an explicit overflow check.
; Entry   : FP1 = value to truncate
; Exit    : A = truncated value (valid only if carry clear on exit)
;           carry clear = success, carry set = FP1's magnitude did
;           not fit in -128..127
; Destroys: A, X, Y; FP1, FP2
; ============================================================
.proc FP_TO_INT8_PROC
    jsr FP_TO_INT16             ; reuse the round-toward-zero 16-bit
                                ; truncation, then range-check the result
    lda FP1_MANT                ; high byte must be a valid sign
    beq @check_low_positive     ; extension of the low byte
    cmp #$ff
    bne @overflow               ; high byte neither $00 nor $ff
    lda FP1_MANT+1
    bmi @in_range               ; high=$FF, low bit7 set: valid negative
    bpl @overflow               ; high=$FF, low bit7 clear: out of range

@check_low_positive:
    lda FP1_MANT+1
    bmi @overflow               ; high=$00, low bit7 set: > 127

@in_range:
    lda FP1_MANT+1
    clc
    rts
    
@overflow:
    lda FP1_MANT+1
    sec
    rts
.endproc

; ------------------------------------------------------------
; Short public aliases, matching library_fp.s's FP_FADD-style
; naming (no _PROC suffix) so the whole library presents one
; consistent calling convention. The _PROC names above still work
; too - these are just the preferred names for call sites.
; ------------------------------------------------------------
FP_TO_INT8  = FP_TO_INT8_PROC
