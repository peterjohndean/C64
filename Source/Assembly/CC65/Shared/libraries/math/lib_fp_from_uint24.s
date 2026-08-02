.include "labels_fp.s"
.include "macros_fp.s"

.export FP_FROM_UINT24

.import FP_NORM
.import FP_FADD

.segment "CODE"
; ============================================================
; PROCEDURE : FP_FROM_UINT24_PROC
; Purpose : Convert an UNSIGNED 24-bit integer to a float. Same
;           technique as FP_FROM_UINT16_PROC, one byte wider - see
;           that routine's comment for the reasoning.
; Entry   : A = bits 23-16 (MSB), X = bits 15-8, Y = bits 7-0 (LSB)
;           (unsigned 0-16777215)
; Exit    : FP1 = float(A:X:Y)
; Destroys: A, X, Y
; ============================================================
.proc FP_FROM_UINT24_PROC
    cmp #$80
    bcc @safe_range
    and #$7f
    sta FP1_MANT
    stx FP1_MANT+1
    sty FP1_MANT+2
    lda #$96                        ; seed exponent for a 24-bit integer
    sta FP1_EXP                     ; - see FP_FROM_INT24_PROC's header
    jsr FP_NORM
    FP_LOAD2_MACRO eight_m          ; FP2 = 8,388,608.0 (2^23)
    jsr FP_FADD
    rts

@safe_range:
    sta FP1_MANT
    stx FP1_MANT+1
    sty FP1_MANT+2
    lda #$96
    sta FP1_EXP
    jsr FP_NORM
    rts

eight_m:    .byte $97,$40,$00,$00   ; 8,388,608.0 = 2^23
.endproc

; ------------------------------------------------------------
; Short public aliases, matching library_fp.s's FP_FADD-style
; naming (no _PROC suffix) so the whole library presents one
; consistent calling convention. The _PROC names above still work
; too - these are just the preferred names for call sites.
; ------------------------------------------------------------
FP_FROM_UINT24  = FP_FROM_UINT24_PROC
