.include "labels_fp.s"

.export FP_FROM_INT8

.import FP_FLOAT

.segment "CODE"
; ============================================================
; PROCEDURE : FP_FROM_INT8_PROC
; Purpose : Convert a signed 8-bit integer to a float.
; Entry   : A = signed 8-bit value
; Exit    : FP1 = float(A)
; Destroys: A, X, Y
; ============================================================
.proc FP_FROM_INT8_PROC
    ldx #0
    cmp #$80            ; [BUG FIX] unsigned compare against $80 sets
                        ; carry iff A >= $80 (i.e. A's sign bit is set)
                        ; - CMP doesn't touch A, so this correctly
                        ; tests A's actual sign. The previous version
                        ; did `ldx #0` immediately before `bpl`, which
                        ; clobbers N/Z from A's load with N/Z from
                        ; loading 0 into X - the branch always saw
                        ; N=0 and always took the "positive" path
                        ; regardless of A, so negative inputs were
                        ; silently zero-extended instead of sign-
                        ; extended (verified: -100 came out as +156).
    bcc @positive       ; A < $80: positive, X stays 0
    dex                 ; A >= $80: negative, sign-extend to $FF
@positive:
    sta FP1_MANT+1      ; low byte = the value as given
    stx FP1_MANT        ; sign-extended high byte
    jsr FP_FLOAT
    rts
.endproc

; ------------------------------------------------------------
; Short public aliases, matching library_fp.s's FP_FADD-style
; naming (no _PROC suffix) so the whole library presents one
; consistent calling convention. The _PROC names above still work
; too - these are just the preferred names for call sites.
; ------------------------------------------------------------
FP_FROM_INT8  = FP_FROM_INT8_PROC
