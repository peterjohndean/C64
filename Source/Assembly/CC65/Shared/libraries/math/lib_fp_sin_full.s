.include "macros_fp.s"

.export FP_SIN_FULL
.import FP_SIN, FP_FMOD, FP_FADD, FP_FSUB, FP_NEGATE, FP_COMPARE

.segment "CODE"
; ============================================================
; FILE    : lib_fp_sin_full.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; sin(x) for FP1, for ANY x - not just the [-pi/2, pi/2] window
; FP_SIN_PROC (lib_fp_sin.s) is documented as scoped to. Built
; ENTIRELY on top of that already-proven routine via range
; reduction - FP_SIN_PROC itself is not touched, not called
; differently, not modified in any way. Same coexistence pattern
; already used throughout this library (FP_TO_ASCII/FP_TO_ASCII24,
; FP_FROM_ASCII/FP_FROM_ASCII24): the narrower routine stays
; exactly as tested, and a new routine extends its reach by
; reducing the problem down to a case the narrow routine already
; handles correctly.
;
; WHY A SEPARATE ROUTINE INSTEAD OF ADDING REDUCTION INTO
; FP_SIN_PROC ITSELF
; -----------------------------------------------------------------
; lib_fp_sin.s's own T00-T03 tests already pass against the real
; hardware/VICE behaviour of the raw polynomial, including right at
; its documented pi/2 boundary. Changing that file now would mean
; re-proving all of that from scratch, for a change (adding
; reduction) that is logically a completely separate concern from
; "does this 5-term Horner polynomial correctly approximate sin
; near x=0". Keeping them as two routines means a bug in the
; reduction logic below can never be confused with a bug in the
; polynomial core, and vice versa - each can be tested and trusted
; independently, exactly the reasoning the coexistence pattern
; exists for elsewhere in this library.
;
; THE ALGORITHM: QUADRANT REDUCTION VIA SYMMETRY
; ----------------------------------------------------
; Step 1 - fold into one period. FP_FMOD_PROC (lib_fp_fmod.s)
; already exists and already does exactly "A mod B, sign matching
; A" - so `FP1 mod 2*pi` folds any x, positive or negative, down to
; something in the open interval (-2*pi, 2*pi). A negative result
; then gets 2*pi added once to land in the half-open interval
; [0, 2*pi) - a single conditional add, not a loop, since one
; FP_FMOD call can only ever leave the result short by at most one
; full period.
;
; Step 2 - which quadrant is r in? Compare r (now in [0,2*pi))
; against pi/2, pi, and 3*pi/2 in turn using this library's own
; FP_COMPARE_TO_MACRO. Each quadrant reduces to a DIFFERENT small
; angle theta in [0, pi/2] via a different identity, and some
; quadrants need the final result negated:
;
;   quadrant   r range        theta = ...   sin(r) = ...
;   ---------  -------------  ------------  -----------------
;   Q1         [0, pi/2)      r             +sin(theta)
;   Q2         [pi/2, pi)     pi - r        +sin(theta)
;   Q3         [pi, 3pi/2)    r - pi        -sin(theta)
;   Q4         [3pi/2, 2pi)   2*pi - r      -sin(theta)
;
; Each theta is, by construction, always inside [0, pi/2] - exactly
; FP_SIN_PROC's proven scope, boundary included (this is precisely
; why T03 in tr_sin.s tested that boundary specifically: THIS
; routine relies on it being solid, not just the interior of the
; range).
;
; WHY THESE FOUR IDENTITIES ARE CORRECT (verified by hand, not
; assumed - each checked against a worked example before trusting
; it in code)
; -----------------------------------------------------------------
;   Q2: sin(r) = sin(pi - r)            [standard supplement identity]
;       check: r=2.0 (~114.6 deg): sin(2.0)=+0.9093;
;              pi-r=1.1416, sin(1.1416)=+0.9093  match
;   Q3: sin(r) = -sin(r - pi)           [sin(pi+theta) = -sin(theta)]
;       check: r=3.5 (~200.5 deg): sin(3.5)=-0.3508;
;              r-pi=0.3584, sin(0.3584)=+0.3508, negated = -0.3508  match
;   Q4: sin(r) = -sin(2*pi - r)         [sin(2pi-theta) = -sin(theta)]
;       check: r=5.5 (~315.1 deg): sin(5.5)=-0.7055;
;              2pi-r=0.7832, sin(0.7832)=+0.7055, negated = -0.7055  match
;
; A NOTE ON THE QUADRANT BOUNDARIES
; --------------------------------------
; The comparisons below treat an EXACT boundary (r exactly equal to
; pi/2, pi, or 3pi/2) as belonging to the LOWER-numbered quadrant
; (e.g. r==pi/2 is handled as Q1, not Q2). This is an arbitrary but
; harmless choice: sin() is continuous, so both quadrants' formulas
; agree exactly AT the shared boundary (Q1 gives sin(pi/2)=sin(pi/2)
; directly; Q2 would give sin(pi-pi/2)=sin(pi/2) - same value,
; either way). Nothing to get wrong here either way; documented
; simply so the choice looks deliberate rather than accidental if
; you go looking for it later.
;
; ERROR HANDLING
; ----------------
; Like FP_TO_ASCII24_PROC and friends, this proc installs NO
; FP_ERROR_INIT_MACRO guard of its own - an out-of-range trap
; (FP_FMOD's internal FP_FDIV, or the FADD/FSUB steps below, could
; in principle trap for a pathologically huge |x|) propagates
; upward to whatever guard the CALLER armed, same contract as the
; rest of this library. Callers should arm one before calling this,
; same as any other risky FP call - see lib_fp_error.s.
;
; Entry   : FP1 = x, any value, in radians
; Exit    : FP1 = sin(x)
; Destroys: A, X, Y; FP2; this proc's private scratch. FP_SIN_PROC
;           itself is called, not modified - see PURPOSE above.
; ============================================================
.proc FP_SIN_FULL_PROC
    ; --- Step 1: fold x into [0, 2*pi) -----------------------
    FP_LOAD2_MACRO twopi_const
    jsr FP_FMOD                 ; FP1 = x mod 2*pi, sign matches x
                                ; (range: open interval (-2pi,2pi))
    lda FP1_MANT
    bpl @in_range                ; already >= 0: nothing more to do
    FP_LOAD2_MACRO twopi_const
    jsr FP_FADD                  ; negative: += 2*pi once, now in
                                ; [0, 2*pi) - one add is always
                                ; enough since FP_FMOD's own result
                                ; can be short by at most one period
@in_range:

    ; --- Step 2: which quadrant, and reduce accordingly ------
    FP_COMPARE_TO_MACRO halfpi_const
    bmi @quadrant1
    beq @quadrant1
    FP_COMPARE_TO_MACRO pi_const
    bmi @quadrant2
    beq @quadrant2
    FP_COMPARE_TO_MACRO threehalfpi_const
    bmi @quadrant3
    beq @quadrant3
    ; falls through: r >= 3*pi/2, and Step 1 guarantees r < 2*pi,
    ; so this is unambiguously quadrant 4

@quadrant4:
    ; theta = 2*pi - r ; sin(r) = -sin(theta)
    FP_LOAD2_MACRO twopi_const   ; FP1 still holds r (comparisons
    jsr FP_FSUB                  ; above don't disturb FP1 - see
                                 ; lib_fp_compare.s); FP1 = 2pi - r
    jsr FP_SIN                   ; FP1 = sin(theta), theta in
                                 ; [0, pi/2] - FP_SIN_PROC's own
                                 ; proven scope
    jsr FP_NEGATE                ; FP1 = -sin(theta) = sin(r)
    rts

@quadrant1:
    ; theta = r (already in [0, pi/2]) ; sin(r) = +sin(theta)
    jsr FP_SIN                   ; FP1 already holds theta=r
    rts

@quadrant2:
    ; theta = pi - r ; sin(r) = +sin(theta)
    FP_LOAD2_MACRO pi_const
    jsr FP_FSUB                  ; FP1 = pi - r
    jsr FP_SIN
    rts

@quadrant3:
    ; theta = r - pi ; sin(r) = -sin(theta)
    ; FP_FSUB always computes FP2-FP1, so to get r-pi (not pi-r)
    ; the operands have to be swapped relative to quadrant 2 above:
    ; move r into FP2 first, THEN load pi into FP1.
    FP_COPY1TO2_MACRO            ; FP2 = r
    FP_LOAD1_MACRO pi_const      ; FP1 = pi
    jsr FP_FSUB                  ; FP1 = FP2-FP1 = r - pi
    jsr FP_SIN
    jsr FP_NEGATE                ; FP1 = -sin(theta) = sin(r)
    rts

; --- constants (own copies, per this library's per-proc scratch
;     convention - see FP_LOG_PROC/FP_EXP_PROC for the precedent).
;     Byte values independently derived and cross-checked, same
;     verified method as lib_fp_sin.s's own Taylor coefficients -
;     halfpi_const in particular was checked to match the rad90
;     constant already proven correct by tr_sin.s's T03. ---
halfpi_const:      .byte $80,$64,$87,$ed   ; pi/2 = 1.5707963268
pi_const:          .byte $81,$64,$87,$ed   ; pi   = 3.1415926536
threehalfpi_const: .byte $82,$4b,$65,$f2   ; 3pi/2= 4.7123889804
twopi_const:       .byte $82,$64,$87,$ed   ; 2pi  = 6.2831853072
.endproc

; ------------------------------------------------------------
; Short public alias, matching the rest of the library's
; FP_FADD-style naming (no _PROC suffix).
; ------------------------------------------------------------
FP_SIN_FULL = FP_SIN_FULL_PROC
