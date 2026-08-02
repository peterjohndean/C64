.include "labels_fp.s"
.include "macros_fp.s"

.export FP_TO_UINT24

.import FP_FSUB
.import FP_TO_INT24
.import FP_COMPARE

.segment "CODE"
; ============================================================
; PROCEDURE : FP_TO_UINT24_PROC
; Purpose : Truncate FP1 to an unsigned 24-bit integer, toward
;           zero. Same technique as FP_TO_UINT16_PROC (see that
;           routine's header for the exponent-boundary bug this
;           fixes), one byte wider: the threshold is 8,388,608
;           (2^23) instead of 32768 (2^15).
; Entry   : FP1 = value to truncate
; Exit    : FP1_MANT = high byte, FP1_MANT+1 = mid byte,
;           FP1_MANT+2 = low byte (valid only if carry clear)
;           carry clear = success, carry set = FP1 was negative
; Destroys: A, X; FP1, FP2
; ============================================================
.proc FP_TO_UINT24_PROC
    lda FP1_MANT
    bmi @overflow
    lda #0
    sta need_adjust
    FP_COMPARE_TO_MACRO eight_m
    bmi @below_threshold
    FP_COPY1TO2_MACRO
    FP_LOAD1_MACRO eight_m
    jsr FP_FSUB                         ; FP1 = original - 8,388,608.0
    lda #1
    sta need_adjust

@below_threshold:
    jsr FP_TO_INT24                     ; proven-correct signed truncation
    lda need_adjust
    beq @no_adjust
    lda FP1_MANT
    ora #$80                            ; add 8,388,608 back
    sta FP1_MANT

@no_adjust:
    clc
    rts

@overflow:
    sec
    rts

eight_m:        .byte $97,$40,$00,$00   ; 8,388,608.0 = 2^23
need_adjust:    .byte 0
; see FP_TO_UINT16_PROC's [BUG FIX] note for why this is a memory byte
; and not X - this is the routine where the bug actually manifested
; (T25's remainder needs 2 FP_RTAR shifts inside FP_TO_INT24, T23's
; needed zero, which is exactly why one test caught this and the other
; didn't).
.endproc


; ------------------------------------------------------------
; Short public aliases, matching lib_fp.s's FP_FADD-style
; naming (no _PROC suffix) so the whole library presents one
; consistent calling convention. The _PROC names above still work
; too - these are just the preferred names for call sites.
; ------------------------------------------------------------
FP_TO_UINT24  = FP_TO_UINT24_PROC
