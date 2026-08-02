.include "labels_fp.s"
.include "macros_fp.s"

.export FP_FROM_UINT16

.import FP_FLOAT
.import FP_FADD

.segment "CODE"
; ============================================================
; PROCEDURE : FP_FROM_UINT16_PROC
; Purpose : Convert an UNSIGNED 16-bit integer to a float.
; Entry   : A = high byte, X = low byte (unsigned 0-65535)
; Exit    : FP1 = float(A:X)
; Destroys: A, X, Y
; Why this needs its own routine instead of just calling FP_FLOAT
; directly (like FP_FROM_INT16_PROC does)
; ---------------------------------------------------------------
; FP_FLOAT always interprets its 16-bit input as SIGNED (bit 15 is
; the sign bit). For values 0-32767 that's the same bit pattern
; either way, so it's safe to float directly. For values
; 32768-65535, the naive bit pattern would be read as NEGATIVE by
; FP_FLOAT - so this clears bit 7 of the high byte (equivalent to
; subtracting 32768), floats the now-safely-signed remainder, then
; adds 32768.0 back to reach the correct unsigned value.
; ============================================================
.proc FP_FROM_UINT16_PROC
    cmp #$80
    bcc @safe_range                     ; high byte < $80: value < 32768,
                                        ; same bit pattern as signed - float
                                        ; it directly, no adjustment needed
    and #$7f                            ; clear the bit FP_FLOAT would read as
    sta FP1_MANT                        ; a sign bit
    stx FP1_MANT+1
    jsr FP_FLOAT
    FP_LOAD2_MACRO thirty_two_k         ; FP2 = 32768.0
    jsr FP_FADD                         ; FP1 += 32768.0, correcting for the
    rts                                 ; bit cleared above

@safe_range:
    sta FP1_MANT
    stx FP1_MANT+1
    jsr FP_FLOAT
    rts

thirty_two_k:   .byte $8f,$40,$00,$00   ; 32768.0 = 2^15
.endproc

; ------------------------------------------------------------
; Short public aliases, matching library_fp.s's FP_FADD-style
; naming (no _PROC suffix) so the whole library presents one
; consistent calling convention. The _PROC names above still work
; too - these are just the preferred names for call sites.
; ------------------------------------------------------------
FP_FROM_UINT16  = FP_FROM_UINT16_PROC
