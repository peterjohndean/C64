.include "macros_fp.s"

.export FP_TAN
.import FP_SIN_FULL, FP_COS, FP_FDIV

.segment "CODE"
; ============================================================
; FILE    : lib_fp_tan.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; tan(x) for FP1, for ANY x. Built the same way FP_COS_PROC was -
; by composing already-proven pieces (FP_SIN_FULL_PROC,
; FP_COS_PROC, FP_FDIV) rather than deriving anything new at the
; bit-manipulation level. tan(x) = sin(x)/cos(x) is the entire
; algorithm; there is no polynomial of its own here.
;
; WHY NO CUSTOM "IS COS(X) TOO CLOSE TO ZERO" DOMAIN CHECK
; -------------------------------------------------------------
; tan(x) is mathematically undefined at odd multiples of pi/2,
; where cos(x)=0. The obvious-looking defensive move is to check
; |cos(x)| against some small epsilon before dividing and treat
; "too close to zero" as a domain error, the same shape as
; FP_LOG_PROC's own domain check. This routine deliberately does
; NOT do that, for two reasons:
;
;   1. FP_FDIV ALREADY has exactly the right trap for the one case
;      that's actually well-defined as an error: divisor exactly
;      0.0 (canonical zero, FP1_EXP==0) traps with error code 1,
;      "division by zero" - and that message is EXACTLY correct
;      here, not a repurposed generic code. No new error code
;      needed, no change to lib_fp_error.s needed.
;
;   2. An arbitrary epsilon threshold would need its own
;      justification for wherever it's set, and - more importantly -
;      it would be MATHEMATICALLY WRONG for the general case. tan(x)
;      genuinely does take on huge (but perfectly finite and
;      well-defined) values as x approaches an asymptote without
;      quite reaching it - tan(89.999 degrees) really is
;      approximately 57296, not an error. Treating "cos(x) is small"
;      as a domain error would incorrectly reject a large range of
;      legitimate, well-defined inputs. Standard library tan()
;      implementations on other platforms behave the same way -
;      only the EXACT asymptote is special, not its neighbourhood.
;
; So this routine relies entirely on FP_FDIV's own already-tested
; behaviour: an exact-zero divisor traps as division-by-zero (code
; 1); a divisor small enough to push the quotient's exponent past
; this format's range traps as generic overflow (code 0, same as
; every other FADD/FSUB/FMUL/FDIV overflow in this library); any
; other divisor produces a plain, correct (if occasionally huge)
; quotient.
;
; SCOPE - THE PART THAT'S EASY TO MISS
; -----------------------------------------
; Because cos(x) is itself computed via range-reduced Taylor
; approximation (FP_COS_PROC -> FP_SIN_FULL_PROC), it essentially
; NEVER lands on exact canonical zero at a true asymptote - it lands
; on some tiny nonzero value instead (confirmed on real hardware:
; this project's own cos(90 degrees) test measured approximately
; 9.5e-7, not 0.0). That means calling FP_TAN_PROC AT an asymptote
; (x = 90 degrees, 270 degrees, etc.) will typically NOT trap at
; all - it will silently return some large-but-finite quotient
; (roughly sin(x)/9.5e-7-ish, so on the order of a million) rather
; than erroring, UNLESS that quotient happens to be big enough to
; overflow the format's own exponent range, or the rounding
; happens to land cos(x) on exact 0.0 (rare, but see lib_fp_cos.s's
; own T04 test - it happened once already, for 270 degrees, purely
; because the angle arithmetic happened to align exactly). This
; mirrors FP_SIN_PROC's own SCOPE note: precision degrades smoothly
; near the edges of what's well-defined, it doesn't fail loudly
; every time - test T04 below deliberately calls this AT 90 degrees
; specifically to see (and document) which of those outcomes
; actually happens on real hardware, rather than assuming one.
;
; ERROR HANDLING
; ----------------
; No FP_ERROR_INIT_MACRO guard of its own - same convention as
; FP_SIN_FULL_PROC/FP_COS_PROC/FP_TO_ASCII24_PROC. Both possible
; traps (division by zero, generic overflow - see above) propagate
; upward to whatever guard the CALLER armed.
;
; Entry   : FP1 = x, any value, in radians
; Exit    : FP1 = tan(x) = sin(x)/cos(x)
; Destroys: A, X, Y; FP2; this proc's private scratch; whatever
;           FP_SIN_FULL_PROC/FP_COS_PROC themselves destroy
; ============================================================
.proc FP_TAN_PROC
    FP_STORE1_MACRO x_backup    ; stash x - both FP_SIN_FULL and
                                ; FP_COS need their OWN look at the
                                ; original x, and each overwrites
                                ; FP1 along the way

    jsr FP_SIN_FULL              ; FP1 = sin(x)
    FP_STORE1_MACRO sin_backup   ; stash sin(x) - needed again below
                                 ; as FP_FDIV's dividend

    FP_LOAD1_MACRO x_backup      ; FP1 = x again (restore, unmodified
                                 ; by the FP_SIN_FULL call above)
    jsr FP_COS                   ; FP1 = cos(x) - this becomes
                                 ; FP_FDIV's DIVISOR, so it needs to
                                 ; already be sitting in FP1 when
                                 ; FP_FDIV is called (see that
                                 ; routine's own Entry convention:
                                 ; FP1=divisor, FP2=dividend)

    FP_LOAD2_MACRO sin_backup    ; FP2 = sin(x), the dividend
    jsr FP_FDIV                  ; FP1 = FP2/FP1 = sin(x)/cos(x)
                                 ; = tan(x) - see the file header on
                                 ; why no separate domain check
                                 ; happens here first
    rts

; --- private scratch (own copy, per this library's convention) ---
x_backup:   .res 4,0
sin_backup: .res 4,0
.endproc

; ------------------------------------------------------------
; Short public alias, matching the rest of the library's
; FP_FADD-style naming (no _PROC suffix).
; ------------------------------------------------------------
FP_TAN = FP_TAN_PROC
