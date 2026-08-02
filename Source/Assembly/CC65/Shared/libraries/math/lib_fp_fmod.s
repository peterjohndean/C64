.include "labels_fp.s"
.include "macros_fp.s"

.export FP_FMOD

.import FP_FDIV
.import FP_FMUL
.import FP_FSUB
.import FP_TRUNC

.segment "CODE"
; ============================================================
; PROCEDURE : FP_MOD_PROC
; Purpose : FP1 = FP1 mod FP2 (remainder after division).
; Entry   : FP1 = A (dividend), FP2 = B (divisor)
; Exit    : FP1 = A - B*trunc(A/B)
; Destroys: A, X, Y; FP2
; Traps   : if B is exactly 0.0, traps via FP_FDIV's own division-
;           by-zero detection (error code 1 - see library_fp.s and
;           library_fp_error.s) - no separate check needed here
; Sign convention
; -----------------
; This is "C-style" fmod: the result has the SAME SIGN AS THE
; DIVIDEND (A), matching trunc-based division. For example,
; -7 mod 3 = -1, not 2. If you want the "same sign as the divisor"
; convention some languages use instead (Python's %, for instance;
; -7 mod 3 = 2 there), replace the FP_TRUNC_PROC call below with
; FP_FLOOR_PROC - everything else in this routine stays the same,
; since the only difference between the two conventions is whether
; the intermediate quotient A/B is rounded toward zero or toward
; -infinity before being multiplied back out.
; ============================================================
.proc FP_FMOD_PROC
    FP_STORE1_MACRO a_backup    ; save A - both FP1 and FP2 get
    FP_STORE2_MACRO b_backup    ; overwritten by the calls below

    FP_LOAD1_MACRO b_backup     ; FP1 = B (divisor)
    FP_LOAD2_MACRO a_backup     ; FP2 = A (dividend)
    jsr FP_FDIV                 ; FP1 = A / B

    jsr FP_TRUNC                ; FP1 = trunc(A/B) - see the
                                ; sign-convention note above
                                ; for the one-line change to
                                ; get floor-based mod instead

    FP_LOAD2_MACRO b_backup     ; FP2 = B
    jsr FP_FMUL                 ; FP1 = trunc(A/B) * B

    FP_LOAD2_MACRO a_backup     ; FP2 = A
    jsr FP_FSUB                 ; FP1 = A - trunc(A/B)*B
    rts

a_backup: .res 4,0
b_backup: .res 4,0
.endproc

; ------------------------------------------------------------
; Short public aliases, matching the rest of the library's
; FP_FADD-style naming (no _PROC suffix).
; ------------------------------------------------------------
FP_FMOD   = FP_FMOD_PROC
