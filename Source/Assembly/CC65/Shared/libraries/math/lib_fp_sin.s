.include "macros_fp.s"

.export FP_SIN
.import FP_FMUL, FP_FADD

.segment "CODE"
; ============================================================
; FILE    : lib_fp_sin.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; sin(x) for FP1, via a truncated Taylor series evaluated with
; Horner's method. This is the FIRST STEP toward a full SIN/COS/TAN
; implementation - see the SCOPE note below for exactly what this
; version does and doesn't handle yet, and NEXT STEPS for the plan
; to remove that limitation.
;
; WHY TAYLOR SERIES, AND WHY HORNER'S METHOD TO EVALUATE IT
; -------------------------------------------------------------
; sin(x) has the well-known infinite series:
;
;   sin(x) = x - x^3/3! + x^5/5! - x^7/7! + x^9/9! - ...
;
; Every term after the first shares a factor of x, so pulling that
; out and substituting t = x*x turns this into a plain polynomial
; in t:
;
;   sin(x) = x * (1 - t/3! + t^2/5! - t^3/7! + t^4/9!)
;          = x * (c0 + c1*t + c2*t^2 + c3*t^3 + c4*t^4)
;
; Evaluating that polynomial the "obvious" way (compute each t^n
; separately, multiply by its coefficient, add them all up) needs
; a running power-of-t AND a running sum - two accumulators, and
; four separate powers of t to compute along the way.
;
; Horner's method instead evaluates from the HIGHEST-degree
; coefficient down, using only ONE accumulator (FP1 itself, which
; is exactly what this library's FMUL/FADD already operate on with
; no extra bookkeeping):
;
;   p = c4
;   p = p*t + c3
;   p = p*t + c2
;   p = p*t + c1
;   p = p*t + c0        <- p now equals the whole polynomial
;   result = x * p
;
; Each line is exactly one FP_FMUL followed by one FP_FADD against
; the next coefficient - four (multiply, add) pairs total for a
; 5-term series, no separate "compute t^2, t^3, t^4" step needed.
; This is the same shape as FP_TO_ASCII24_PROC's power-of-ten
; digit loop and FP_LOG_PROC/FP_EXP_PROC's own rational
; approximations - Horner's method turns up constantly in this
; kind of fixed-degree polynomial evaluation because it minimises
; both operation count AND how many intermediate values need their
; own scratch byte.
;
; SCOPE - READ THIS BEFORE RELYING ON THIS VERSION
; -----------------------------------------------------
; This routine does NOT perform range reduction. It evaluates the
; raw 5-term series directly on whatever is in FP1. A Taylor series
; is only a GOOD approximation near its expansion point (x=0 here);
; the more terms you include, the further out it stays accurate,
; but it is still fundamentally a local approximation, not a
; globally valid formula - past a certain |x| it diverges instead
; of leveling off, because higher powers of x eventually dominate
; whatever the true bounded sin(x) is doing.
;
; Checked numerically (not assumed) against Python's math.sin
; before writing this file:
;
;   angle    |x| (rad)   abs. error vs true sin(x)
;   -------  ----------  ---------------------------
;    30 deg    0.5236     2.0e-11
;    45 deg    0.7854     1.8e-9
;    60 deg    1.0472     4.1e-8
;    90 deg    1.5708     3.5e-6   <- still acceptable
;
; This format's mantissa (~22 explicit bits) has a precision floor
; around 1e-7 RELATIVE error on its own, independent of any
; approximation - so this 5-term series stays within that floor
; comfortably out to 60 degrees, and is still reasonable at the
; full quarter-turn (90 degrees / pi/2 radians). PAST pi/2 the
; error grows fast and this routine will silently return a wrong
; answer with no error trap - there is nothing to detect the way
; there is for, say, log(x<=0) or exp() overflow: a Taylor series
; doesn't "fail obviously", it just gets quietly less accurate the
; further you push it, which is exactly why the scope boundary has
; to be documented rather than discovered by surprise.
;
; NOT YET VERIFIED ON VICE OR HARDWARE
; -----------------------------------------
; Per this project's usual workflow, static/derived correctness
; (the coefficient bytes were independently re-derived and cross-
; checked against this library's own known constants - see the
; conversation this was built in) is a first pass, not a
; substitute for a VICE monitor register dump and, eventually, a
; C64U run. Treat this as ready for T-series testing, not yet as
; proven.
;
; NEXT STEPS (not yet implemented, in order)
; -----------------------------------------------
;   1. Range reduction: fold an arbitrary x down into [-pi/2,pi/2]
;      using FP_FMOD_PROC (already in this library, lib_fp_fmod.s)
;      against 2*pi, then quadrant-fold using symmetry
;      (sin(x)=sin(pi-x), sign flips per quadrant) so this same
;      5-term core can serve any input, not just |x|<=pi/2.
;   2. FP_COS_PROC: either its own small polynomial, or reuse this
;      same reduced-range core via cos(x) = sin(x + pi/2).
;   3. FP_TAN_PROC: FP_FDIV(sin(x), cos(x)) once both exist, with
;      a domain check for cos(x) near zero (matching this
;      library's existing FP_ERROR convention rather than dividing
;      by an unchecked near-zero value).
;
; Entry   : FP1 = x, in radians, |x| <= pi/2 (see SCOPE above)
; Exit    : FP1 = sin(x)
; Destroys: A, X, Y; FP2; this proc's private x_backup/t_backup
; Traps   : none - out-of-scope inputs return a silently wrong
;           result rather than erroring (see SCOPE above)
; ============================================================
.proc FP_SIN_PROC
    FP_STORE1_MACRO x_backup    ; stash x - needed again at the very
                                ; end for the final "x * p" multiply,
                                ; and FP1 is about to get overwritten
                                ; repeatedly by the Horner loop below

    ; --- t = x*x --------------------------------------------
    FP_COPY1TO2_MACRO           ; FP2 = x (register-to-register copy,
                                ; no memory round-trip needed here)
    jsr FP_FMUL                 ; FP1 = x*x = t
    FP_STORE1_MACRO t_backup    ; stash t - every Horner step below
                                ; needs it again as the multiplier

    ; --- Horner's method: p = c4, then four (multiply-by-t,
    ;     add-next-coefficient) passes, working down from the
    ;     highest-degree coefficient to the constant term ---
    FP_LOAD1_MACRO c4_const     ; FP1 = c4  (p := c4)

    FP_LOAD2_MACRO t_backup
    jsr FP_FMUL                 ; FP1 = p*t
    FP_LOAD2_MACRO c3_const
    jsr FP_FADD                 ; FP1 = p*t + c3

    FP_LOAD2_MACRO t_backup
    jsr FP_FMUL                 ; FP1 = p*t
    FP_LOAD2_MACRO c2_const
    jsr FP_FADD                 ; FP1 = p*t + c2

    FP_LOAD2_MACRO t_backup
    jsr FP_FMUL                 ; FP1 = p*t
    FP_LOAD2_MACRO c1_const
    jsr FP_FADD                 ; FP1 = p*t + c1

    FP_LOAD2_MACRO t_backup
    jsr FP_FMUL                 ; FP1 = p*t
    FP_LOAD2_MACRO c0_const
    jsr FP_FADD                 ; FP1 = p*t + c0  <- full polynomial

    ; --- result = x * p --------------------------------------
    FP_LOAD2_MACRO x_backup
    jsr FP_FMUL                 ; FP1 = x * p = sin(x)
    rts

; --- private scratch (own copy, per this library's convention of
;     each .proc owning its own working storage rather than
;     sharing a global scratch pool - see lib_fp_log.s/lib_fp_exp.s
;     for the precedent) ---
x_backup:  .res 4,0
t_backup:  .res 4,0

; --- Horner coefficients for sin(x) = x*(c0 + c1*t + c2*t^2 +
;     c3*t^3 + c4*t^4), t = x*x. Byte values independently
;     re-derived (not hand-guessed) using this library's own
;     excess-128-exponent / 24-bit-two's-complement-mantissa
;     format, and cross-checked against this file's own already-
;     known constants (1.0, -1.0, 0.5, 10.0 all matched exactly)
;     before being trusted for new values - see the SCOPE note
;     above on why that verification step matters here. ---
c0_const:  .byte $80,$40,$00,$00   ; +1.0
c1_const:  .byte $7d,$aa,$aa,$ab   ; -1/6            = -0.1666667
c2_const:  .byte $79,$44,$44,$44   ; +1/120          = +0.0083333
c3_const:  .byte $73,$97,$f9,$80   ; -1/5040         = -0.0001984
c4_const:  .byte $6d,$5c,$77,$8f   ; +1/362880       = +0.0000028
.endproc

; ------------------------------------------------------------
; Short public alias, matching the rest of the library's
; FP_FADD-style naming (no _PROC suffix).
; ------------------------------------------------------------
FP_SIN = FP_SIN_PROC
