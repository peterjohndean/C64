.include "labels_fp.s"
.include "macros_fp.s"

.export FP_TO_UINT16

.import FP_FSUB
.import FP_TO_INT16
.import FP_COMPARE

.segment "CODE"
; ============================================================
; PROCEDURE : FP_TO_UINT16_PROC
; Purpose : Truncate FP1 to an unsigned 16-bit integer, toward
;           zero. Negative values are reported as overflow.
; Entry   : FP1 = value to truncate
; Exit    : FP1_MANT = high byte, FP1_MANT+1 = low byte of the
;           truncated integer (valid only if carry clear on exit)
;           carry clear = success, carry set = FP1 was negative
; Destroys: A, X; FP1, FP2
; Why this can't just be FP_TO_INT16_PROC
; -------------------------------------------
; FP_TO_INT16_PROC's rounding correction (the "round toward zero"
; fix for negative values) decides whether a value is negative by
; checking the TOP BIT of the truncated result - which is wrong for
; a genuinely large positive unsigned value like 40000 (bit 15 set,
; but not negative). This routine rejects negative inputs up front
; (checked on the ORIGINAL value, before any truncation) instead.
; A SECOND, LESS OBVIOUS PROBLEM (this is the bug fix)
; --------------------------------------------------------
; An earlier version of this routine reused FP_TO_INT16_PROC's
; "shift right until the exponent reaches $8E" technique directly.
; That's wrong: values in [32768,65536) have a natural normalized
; exponent of $8F, not $8E or lower - one MORE than the target.
; Right-shifting only ever INCREASES the exponent, so for these
; values the loop can never converge; it spins the exponent up
; through $FF and wraps to $00, which triggers FP_CORE_PROC's
; overflow trap - and if that fires somewhere no
; FP_ERROR_INIT_MACRO has armed a recovery point yet, the "safe"
; unwind restores a garbage stack pointer and RTS's to a random
; address (verified as the actual cause of a real hang/reset on
; hardware, not a hypothetical). The fix: for values >= 32768,
; subtract 32768.0 first (bringing the remainder into
; FP_TO_INT16_PROC's proven-correct [0,32767] range), truncate
; that with the already-tested routine, then set bit 15 of the
; result to add the 32768 back as an integer. Values below 32768
; skip the subtraction entirely and go straight to FP_TO_INT16_PROC.
; ============================================================
.proc FP_TO_UINT16_PROC
    lda FP1_MANT
    bmi @overflow
    lda #0
    sta need_adjust                     ; [BUG FIX] memory, not a register -
                                        ; see the note below
    FP_COMPARE_TO_MACRO thirty_two_k
    bmi @below_threshold                ; FP1 < 32768: safe range as-is
    FP_COPY1TO2_MACRO
    FP_LOAD1_MACRO thirty_two_k
    jsr FP_FSUB                         ; FP1 = original - 32768.0, now
                                        ; safely inside [0,32767]
    lda #1
    sta need_adjust                     ; remember to restore bit 15

@below_threshold:
    jsr FP_TO_INT16                     ; proven-correct signed truncation
    lda need_adjust
    beq @no_adjust
    lda FP1_MANT
    ora #$80                            ; add 32768 back as an integer
    sta FP1_MANT

@no_adjust:
    clc
    rts

@overflow:
    sec
    rts

thirty_two_k:   .byte $8f,$40,$00,$00   ; 32768.0 = 2^15
need_adjust:    .byte 0
; [BUG FIX] this was originally X, set once before the call above and
; checked once after it - reasonable-looking, but wrong: FP_TO_INT16's
; internal loop calls FP_RTAR whenever the value needs shifting to reach
; the target exponent, and FP_RTAR's own shift loop (rtlog1, in
; library_fp.s) uses X as an index, ending at 0 regardless of what it
; held on entry. For a value whose remainder happens to already sit at
; the target exponent (no shift needed - true for T23's specific test
; value, 50000), FP_RTAR is never called and X survives untouched,
; masking the bug entirely. For a remainder that needs even one shift
; (true for T25's, 10,000,000), X gets silently reset to 0 mid-call,
; and the "add 32768 back" step never ran - it looked correct until
; tested against a value with a different shift count. A dedicated
; memory byte has no such issue: nothing else touches it.
.endproc

; ------------------------------------------------------------
; Short public aliases, matching lib_fp.s's FP_FADD-style
; naming (no _PROC suffix) so the whole library presents one
; consistent calling convention. The _PROC names above still work
; too - these are just the preferred names for call sites.
; ------------------------------------------------------------
FP_TO_UINT16  = FP_TO_UINT16_PROC
