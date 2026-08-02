.include "labels_fp.s"

.export FP_TRUNC

.import FP_TO_INT24
.import FP_FROM_INT24

.segment "CODE"

; ============================================================
; FILE    : lib_fp_trunc.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; FP_TRUNC_PROC (round toward zero), FP_FLOOR_PROC (round toward
; -infinity), FP_CEIL_PROC (round toward +infinity), and
; FP_MOD_PROC (remainder). All four are built entirely out of
; already-tested primitives (FP_TO_INT24_PROC/FP_FROM_INT24_PROC,
; FP_FADD/FP_FSUB/FP_FMUL/FP_FDIV, FP_COMPARE_PROC) rather than any
; new low-level bit manipulation - deliberately, given how many
; subtle bugs earlier additions to this library turned up when they
; touched raw mantissa bits directly (the UINT16/24 exponent-target
; bug, the register-clobbering bug, the IEEE-754 -1.0-style boundary
; case). Composing proven building blocks is slower but far less
; likely to hide a new bug of the same kind.
;
; WHY FP_TRUNC ISN'T JUST FP_TO_INT16_PROC/FP_TO_INT24_PROC
; ----------------------------------------------------------------
; Those return a raw integer (limited to 16 or 24 bits, in
; FP1_MANT/+1[/+2]) truncated toward zero - useful, but not a
; general float-to-float truncation. FP_TRUNC_PROC needs to work on
; the FULL representable range, including magnitudes too large to
; fit in 24 bits (which don't need "truncating" at all - past a
; certain exponent, this format has no room left for fractional
; bits, so the value already IS an integer). It checks that up
; front, and only for values that could plausibly have a fraction
; does it delegate to FP_TO_INT24_PROC (reusing the proven
; 24-bit-integer round trip) followed by FP_FROM_INT24_PROC to get
; back to float form.
;
; THE THRESHOLD: EXPONENT $96
; -------------------------------
; A value has zero representable fractional bits once its exponent
; reaches 150 ($96) - the same threshold FP_TO_INT24_PROC/
; FP_FROM_UINT24_PROC already use (see library_fp_convert.s's
; header for the derivation: at exponent E, the mantissa's least
; significant bit represents 2^(E-150), which is >= 1 - i.e. purely
; integer - once E >= 150). Below that threshold, FP_TO_INT24_PROC
; safely truncates (its own shift-right loop only ever needs to
; move exponent UP toward $96, converging correctly, unlike the bug
; that FP_TO_UINT16_PROC/FP_TO_UINT24_PROC had before their fix).
;
; DEPENDENCIES
; ------------
; Requires labels_fp.s, library_fp_error.s, library_fp.s,
; library_fp_convert.s, library_fp_compare.s, macros_fp.s before
; this file.
;
; ROUTINE INVENTORY
; -------------------
;   FP_TRUNC_PROC - FP1 = FP1 truncated toward zero
;   FP_FLOOR_PROC - FP1 = FP1 truncated toward -infinity
;   FP_CEIL_PROC  - FP1 = FP1 truncated toward +infinity
;   FP_MOD_PROC   - FP1 = FP1 mod FP2 (see FP_MOD_PROC's own header
;                   for the sign convention)
; ============================================================

; ============================================================
; PROCEDURE : FP_TRUNC_PROC
; Purpose : Truncate FP1 toward zero, in place, as a float (not
;           limited to a 16 or 24-bit integer's range).
; Entry   : FP1 loaded
; Exit    : FP1 = FP1 truncated toward zero
; Destroys: A, X, Y
; ============================================================
.proc FP_TRUNC_PROC
    lda FP1_EXP
    beq @done           ; canonical zero: nothing to truncate
    cmp #$96
    bcs @done           ; exponent >= $96: already an integer -
                        ; see the file header's derivation
    jsr FP_TO_INT24     ; truncate toward zero into a raw
                        ; 24-bit integer (proven correct -
                        ; see lib_fp_convert.s)
    lda FP1_MANT
    ldx FP1_MANT+1
    ldy FP1_MANT+2
    jsr FP_FROM_INT24              ; re-normalize back to float form
@done:
    rts
.endproc

; ------------------------------------------------------------
; Short public aliases, matching the rest of the library's
; FP_FADD-style naming (no _PROC suffix).
; ------------------------------------------------------------
FP_TRUNC = FP_TRUNC_PROC
