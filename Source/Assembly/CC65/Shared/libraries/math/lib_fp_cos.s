.include "macros_fp.s"

.export FP_COS
.import FP_SIN_FULL, FP_FADD

.segment "CODE"
; ============================================================
; FILE    : lib_fp_cos.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; cos(x) for FP1, for ANY x. Uses the standard phase-shift identity
; cos(x) = sin(x + pi/2) rather than a second Taylor series - see
; WHY THIS IDENTITY INSTEAD OF A SEPARATE POLYNOMIAL below for the
; reasoning.
;
; WHY THIS IDENTITY INSTEAD OF A SEPARATE POLYNOMIAL
; -----------------------------------------------------
; cos(x) has its own Taylor series (1 - x^2/2! + x^4/4! - ...) that
; could have been built the same way FP_SIN_PROC was - a fresh
; 5-term Horner polynomial, its own independently-derived
; coefficients, its own T-series proving it on VICE and hardware
; from scratch. That would have worked, but it would ALSO have
; meant re-deriving and re-proving everything sin() already went
; through, for a function that's mathematically just sin() shifted
; by a quarter turn. lib_fp_trunc.s's header makes this exact
; argument for FP_TRUNC/FP_FLOOR/FP_CEIL: "composing proven
; building blocks is slower but far less likely to hide a new bug"
; - the same reasoning applies here. FP_SIN_FULL_PROC is already
; validated on real hardware (C64U), not just VICE - reusing it
; entirely for cos() means that validation carries over directly,
; and the only genuinely NEW code in this file is a single FADD.
;
; WHY NO NARROWER "CORE" COMPANION (unlike FP_SIN_PROC/FP_SIN_FULL)
; -------------------------------------------------------------------
; FP_SIN_PROC deliberately has two coexisting versions: a narrow
; Taylor-only core (lib_fp_sin.s, scoped to [-pi/2,pi/2]) and a
; full-range wrapper around it (lib_fp_sin_full.s). That split made
; sense for sin() because plenty of real inputs (small angles) never
; need range reduction at all, so a version that skips it entirely
; is genuinely useful on its own, faster, and simpler.
;
; That split does NOT carry over usefully to cos(). Adding pi/2 to
; x immediately pushes even a SMALL x out of FP_SIN_PROC's narrow
; scope - e.g. x=0.3 (comfortably within [-pi/2,pi/2] on its own)
; becomes x+pi/2=1.87, which already exceeds pi/2. There is no
; input to FP_COS_PROC, however small, for which skipping range
; reduction would be valid - the phase shift alone guarantees
; reduction is needed almost immediately. So unlike sin(), there is
; no meaningful "narrow cos core" to build - FP_COS_PROC calls
; FP_SIN_FULL_PROC (the reduction-capable version) unconditionally,
; and that is the ONLY sensible design here, not an arbitrary choice
; to skip building the narrower variant.
;
; ERROR HANDLING
; ----------------
; Same convention as FP_SIN_FULL_PROC and FP_TO_ASCII24_PROC: no
; FP_ERROR_INIT_MACRO guard of its own. The FADD below, and
; everything inside FP_SIN_FULL_PROC (FP_FMOD's internal FP_FDIV,
; the quadrant FADD/FSUB steps), can in principle trap for a
; pathologically huge |x| - that propagates upward to whatever
; guard the CALLER armed, same contract as the rest of this
; library.
;
; Entry   : FP1 = x, any value, in radians
; Exit    : FP1 = cos(x)
; Destroys: A, X, Y; FP2; whatever FP_SIN_FULL_PROC itself destroys
; ============================================================
.proc FP_COS_PROC
    FP_LOAD2_MACRO halfpi_const
    jsr FP_FADD                  ; FP1 = x + pi/2
    jsr FP_SIN_FULL              ; FP1 = sin(x + pi/2) = cos(x)
    rts

; --- own copy of pi/2, per this library's per-proc constant
;     convention - value independently re-derived and cross-checked
;     the same way as every other constant in this project; matches
;     lib_fp_sin_full.s's halfpi_const exactly, which was itself
;     already checked against the hardware-proven rad90 in
;     tr_sin.s's T03. ---
halfpi_const: .byte $80,$64,$87,$ed   ; pi/2 = 1.5707963268
.endproc

; ------------------------------------------------------------
; Short public alias, matching the rest of the library's
; FP_FADD-style naming (no _PROC suffix).
; ------------------------------------------------------------
FP_COS = FP_COS_PROC
