
.export FP_CLEANUP_FAC1FAC2

.segment "CODE"

; ============================================================
; PROCEDURE : FP_CLEANUP_FAC1FAC2
; Purpose : Zero the complete 16-byte BASIC floating point
;           workspace ($61-$70) this library shares with BASIC's
;           own FAC1/FAC2 (see labels_fp.s's ZP MAP for why that
;           sharing exists). Call this before returning control to
;           BASIC (e.g. right before your program's own final RTS
;           back to whatever SYS'd into it).
; Why 16 bytes, not just FP1/FP2's 12?
; -----------------------------------------
; FP1/FP2 only occupy $61-$6C, but BASIC's own FAC1/FAC2 extend
; through $70 - it uses the extra bytes ($6D-$70) as working space
; during its own number conversion (e.g. LIST-ing a program that
; contains floating point constants). Leaving stale bytes there,
; even outside the range this library's own routines touch, can
; make BASIC commands run immediately afterward behave oddly.
; Zeroing all 16 bytes is cheap and removes the ambiguity.
; Entry   : none
; Exit    : $61-$70 all zero
; Destroys: A, X
; ============================================================
.proc FP_CLEANUP_FAC1FAC2_PROC
    lda #0
    ldx #($70-$61)           ; 16 bytes ($61-$70)
    
@clear_fp:
    sta $61,x
    dex
    bpl @clear_fp
    rts
.endproc

; ------------------------------------------------------------
; Short public aliases, matching the rest of the library's
; FP_FADD-style naming (no _PROC suffix).
; ------------------------------------------------------------
FP_CLEANUP_FAC1FAC2 = FP_CLEANUP_FAC1FAC2_PROC
