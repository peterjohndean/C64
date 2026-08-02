.include "labels_fp.s"

.export FP_LOG10

.import FP_LOG
.import FP_FMUL

.segment "CODE"
; ============================================================
; PROCEDURE : FP_LOG10_PROC
; Purpose : Common (base 10) logarithm. FP1 = log10(FP1).
; Algorithm : log10(x) = ln(x) * log10(e); computes the natural
;             log via FP_LOG_PROC, then multiplies by the constant
;             1/ln(10) = log10(e).
; Entry   : FP1 loaded with the argument; must be > 0
; Exit    : FP1 = log10(FP1)
; Destroys: A, X, Y; FP2 and FP_LOG_PROC's private scratch
; Traps   : shares FP_LOG_PROC's error_trap for arguments <= 0
; ============================================================
.proc FP_LOG10_PROC
    jsr FP_LOG                  ; FP1 = ln(argument)
    ldx #3
@l10:
    lda ln10,x
    sta FP2_EXP,x               ; FP2 = 1/ln(10) = log10(e)
    dex
    bpl @l10
    jsr FP_FMUL                 ; FP1 = ln(x) * log10(e) = log10(x)
    rts

ln10:   .byte $7e,$6f,$2d,$ed   ; 1/ln(10) = 0.4342945
.endproc

; ------------------------------------------------------------
; Short public aliases, matching the rest of the library's
; FP_FADD-style naming (no _PROC suffix).
; ------------------------------------------------------------
FP_LOG10 = FP_LOG10_PROC
