.macpack longbranch

.include "labels_fp.s"
.include "macros_fp.s"
.include "lib_fp_error.h"

; Standard Export Declarations for 'ASM'
.export FP_FADD, FP_FSUB, FP_FMUL, FP_FDIV
.export FP_FLOAT, FP_FIX, FP_SWAP, FP_NORM
.export FP_RTAR, FP_NEGATE

; [20260912] Exported so tr_trig_poison.s (and any future test or
; caller) can directly poison the classify flag and verify that the
; FADD/FSUB/FMUL/FDIV entry-point resets correctly neutralise stale
; state. Directly writing this from outside the library bypasses
; every internal reset - only the poison test should do that.
.export FP_NORM_BOUNDARY_STATE

.ifdef BUILD_MODE_HYBRID
    ; Additional declarations needed for 'C'
    .export _FP_FADD, _FP_FSUB, _FP_FMUL, _FP_FDIV
    .export _FP_FLOAT, _FP_FIX, _FP_SWAP, _FP_NORM
    .export _FP_RTAR, _FP_NEGATE
    .export _FP_FP1, _FP_FP2

    ; Variables
    _FP_FP1     = FP1_EXP
    _FP_FP2     = FP2_EXP

    ; Routines
    _FP_FADD    = FP_FADD
    _FP_FSUB    = FP_FSUB
    _FP_FMUL    = FP_FMUL
    _FP_FDIV    = FP_FDIV
    _FP_FLOAT   = FP_FLOAT
    _FP_FIX     = FP_FIX
    _FP_SWAP    = FP_SWAP
    _FP_NORM    = FP_NORM
    _FP_RTAR    = FP_RTAR
    _FP_NEGATE  = FP_NEGATE
.endif

.import FP_ERROR

;
; MACRO: Common code throughout the library.
;
.macro FP_FP1_ZEROED_MACRO
    lda #0
    sta FP1_EXP
    sta FP1_MANT
    sta FP1_MANT+1
    sta FP1_MANT+2
.endmacro

.segment "CODE"
; ============================================================
; FILE    : lib_fp.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; A ca65/cc65-tools port of the classic Rankin/Wozniak 6502 floating point
; package, "Floating Point Routines for the 6502", Dr. Dobb's
; Journal, August 1976 (https://6502.org/source/floats/wozfp1.txt).
; This is a SYNTAX AND ADDRESSING port, not a redesign: every
; routine below is the same algorithm, same instruction sequence,
; same fall-through/branch structure as the original 1976 listing.
; Only the assembler dialect (ca65 vs. the original's
; "=" immediate syntax and BSS directives) and the zero page
; addresses have changed.
;
; PROVENANCE / ERRATA
; ---------------------
; Roy Rankin published an errata for this package in the
; November/December 1976 issue of Dr. Dobb's Journal
; (https://6502.org/source/floats/wozfp2.txt). It corrects exactly
; one bug: FP_LOG_PROC's argument-range-reduction step always
; zero-extended the extracted power-of-2 exponent to 16 bits
; before calling FP_FLOAT, which is only correct when that
; exponent is positive (argument >= 1.0). For an argument < 1.0
; the exponent is negative and needs SIGN-extension ($FF in the
; high byte, not $00), or FP_FLOAT computes a wildly wrong huge
; positive "n" instead of the intended small negative one. This
; port includes Rankin's fix (see the `cont` label below, marked
; [ERRATA FIX]) - LOG/LOG10 of arguments below 1.0 will be wrong
; without it. No other routine in this package needed correction.
; wozfp3.txt (the Apple II ROM variant of this same package,
; https://6502.org/source/floats/wozfp3.txt) independently confirms
; the double-entry and alignment-trampoline mechanisms described
; below and was cross-checked against this port while applying the
; fix - it also has a materially different, rounding-aware FIX
; that the integer conversion helpers borrow from for FP_TO_INT8/16/24.
;
; DEPENDENCIES
; ------------
; Requires labels_fp.s to be included BEFORE this file. That file
; defines the zero page footprint (FP1_EXP/FP1_MANT/FP_EXT,
; FP2_EXP/FP2_MANT, FP_SIGN, FP_ERROR_SP/FP_ERROR_CODE) and
; explains WHY it reuses BASIC's FAC1/FAC2 addresses - read it
; first, especially the note that this is address reuse only, not
; FAC-format compatibility with BASIC's own floating point ROM
; routines (FP_CLEANUP_FAC1FAC2 below exists precisely because of
; that sharing).
;
; Also requires lib_fp_error.s to be included BEFORE this file
; - the overflow/domain-error trap sites here call FP_ERROR by
; name, and macros_rom_basic.s/macros_rom_kernal.s for
; BASIC_STROUT_MACRO/KERNAL_CHROUT_MACRO, which FP_ERROR uses.
;
; NUMBER FORMAT
; --------------
; 4 bytes: 1 exponent byte (excess-128) + 3 mantissa bytes (2's
; complement, normalized to 1.0-2.0, binary point after bit 6 of
; the first mantissa byte). See labels_fp.s for the full layout
; diagram. This is a 24-bit mantissa (~7 significant decimal
; digits), one byte narrower than BASIC's own 32-bit FAC mantissa.
;
; A CAUTION ABOUT wozfp3.txt's WORKED EXAMPLES
; ------------------------------------------------
; wozfp3.txt's prose "Example:" sections for FSUB and FDIV appear
; to contain transcription errors - if you hand-check this port
; against those examples and the sign or a byte looks wrong, trust
; the derivation here over that prose. Specifically: its FSUB
; example's stated result (+12 from minuend +7 minus subtrahend -5)
; doesn't match what the actual instruction sequence computes
; (FCOMPL negates FP1 then falls into FADD's own code, giving
; FP2_entry - FP1_entry, i.e. -5-7=-12, not the documented +12);
; and its FDIV example's byte dump for -60 ($85 80 00 00) doesn't
; decode to -60 under this format (it decodes to -64), while its
; OWN separate FMUL example's byte dump for the same value -60
; ($85 88 00 00) decodes correctly. test_fp.s's expected values
; were derived directly from the disassembly and cross-checked
; against wozfp3's internally-consistent FADD/FMUL examples, not
; copied from its FSUB/FDIV prose.
;
; ROUTINE INVENTORY
; -------------------
;   FP_CORE_PROC (one indivisible .proc - see note below)
;     FP_FADD   - FP1 = FP1 + FP2
;     FP_FSUB   - FP1 = FP2 - FP1
;     FP_FMUL   - FP1 = FP1 * FP2
;     FP_FDIV   - FP1 = FP2 / FP1
;     FP_FLOAT  - FP1 = float(16-bit integer currently in FP1_MANT/+1)
;     FP_FIX    - FP1 = integer part of FP1 (result in FP1_MANT/+1)
;     FP_SWAP   - exchange FP1 and FP2 in place
;   FP_LOG_PROC   - FP1 = natural log(FP1), FP1 must be > 0
;   FP_LOG10_PROC - FP1 = log base 10(FP1), FP1 must be > 0
;   FP_EXP_PROC   - FP1 = e^FP1
;   FP_CLEANUP_FAC1FAC2 - zero the shared BASIC FAC1/FAC2 workspace;
;                          call before returning to BASIC
;
; WHY IS FP_CORE_PROC ONE GIANT .proc INSTEAD OF SEVEN .procs?
; ----------------------------------------------------------
; The project convention is one routine = one .proc for clean
; dead code elimination. That convention breaks down here: Woz's
; FADD/FSUB/FMUL/FDIV/FCOMPL/SWAP/NORM are not independent
; subroutines that happen to call each other with JSR/RTS - they
; are ONE interleaved block of code that shares tails via plain
; branches (BEQ/BNE/BCC/BCS/BPL/BMI) as well as calls, and in two
; places (see the "TRAMPOLINE" and "DOUBLE-ENTRY" notes below) a
; JSR is deliberately used to create a return address that lands
; back inside a DIFFERENT routine's fall-through path. Splitting
; these into separate .proc blocks would either break branch
; range (a .proc boundary is not a physical barrier in ca65,
; but reordering to make each piece independently droppable would
; force real gaps) or force duplicating the shared tail code,
; doubling the size of what is famously some of the tightest
; floating point code ever written for the 6502. So the whole
; "basic page" is kept as one block, exactly as it was one
; physical page ($1F00) in the original.
;
; It's declared with .block rather than .proc specifically
; because .proc's dead-code-elimination bookkeeping combined with
; this many interlinked branches (some near the +/-127 byte short-
; branch limit) and would obscure the deliberate fall-throughs.
; Keeping the core in one contiguous .proc mirrors the original
; page layout and avoids presenting tightly interdependent entry
; points as independent routines. FP_LOG_PROC, FP_LOG10_PROC and
; FP_EXP_PROC ARE independent of each other and of one another's
; private scratch space - each is only reached via JSR from
; outside and only reaches FP_CORE_PROC via JSR, so each stays a
; real .proc, at the cost of a few bytes of duplicated constant
; tables (documented at each duplication).
;
; TWO DELIBERATE CLEVER TRICKS WORTH UNDERSTANDING BEFORE YOU
; TOUCH THIS CODE
; ----------------------------------------------------------------
; 1. THE DOUBLE-ENTRY TRICK (md1/abswap/swap):
;    FP_FMUL and FP_FDIV both need the ABSOLUTE VALUE of BOTH
;    mantissas before they multiply/divide unsigned. Rather than
;    write that logic twice, `md1` calls `abswap` with a genuine
;    JSR, and `abswap` (after conditionally negating FP1's
;    mantissa) falls straight through into `swap` with NO RTS in
;    between. `swap`'s own RTS therefore returns to the address
;    JSR pushed - which is `abswap`'s OWN entry point - so the
;    same code runs a second time, this time examining what is
;    now sitting in FP1's slot (originally FP2's mantissa, moved
;    there by the first swap). The second pass's `swap` call
;    swaps the operands back into their original slots and its
;    RTS finally pops the frame `md1`'s caller (FP_FMUL/FP_FDIV)
;    is expecting. Net effect: one JSR md1 call processes BOTH
;    operands' signs and leaves both mantissas positive, for the
;    cost of a single extra JSR/RTS pair (12 cycles) instead of
;    writing the abs-and-swap logic out twice (see FP_SIGN in
;    labels_fp.s for where the running sign parity is kept).
;
;    IMPORTANT CORRECTION (found while investigating the FMUL/FDIV
;    exponent-boundary bug below): if EITHER operand's mantissa is
;    negative, this double-entry trick does NOT stay confined to
;    md1/abswap/swap - the negation itself (`jsr fcompl`) falls
;    through into `addend`/`norm`/`rtlog`, the SAME shared
;    normalize-or-shift tail FADD/FSUB use, and whichever `rts`
;    fires first in THAT code is what actually returns control back
;    into `abswap`'s "inc FP_SIGN" line. This is effectively a THIRD
;    trampoline reentry, not previously called out as its own bullet
;    here - anyone tracing register/flag state through md1 for a
;    negative operand needs to follow it all the way through
;    fcompl->addend->norm (or ->rtlog) and back, not just
;    md1->abswap->swap. Hand-tracing this exact path is what produced
;    an incorrect claim during that investigation (see the EXPONENT
;    OVERFLOW BOUNDARY note below) - treat any hand-derived claim
;    about register state surviving this path as unverified until an
;    instruction-level simulator confirms it.
;
; 2. THE ALIGNMENT TRAMPOLINE (fadd/swpalg/algnsw/rtar/rtlog):
;    Adding two floats with different exponents requires shifting
;    the smaller-exponent mantissa right, ONE BIT AT A TIME, until
;    the exponents match - and that shift can take up to 24
;    iterations. Rather than a dedicated loop counter, `fadd`
;    re-enters ITSELF: when exponents differ it branches to
;    `swpalg`, which does a genuine `jsr algnsw`; `algnsw` shifts
;    one bit (via `rtar`/`rtlog`/`rtlog1`) and its eventual `rts`
;    pops the address `jsr algnsw` pushed - which is `fadd`'s own
;    entry point - so `fadd` re-compares the (now closer) exponents
;    and loops back through `swpalg` again if they still differ.
;    Only when they finally match does execution fall through past
;    the exponent compare into the real addition. This costs a
;    JSR/RTS pair (12 cycles) per bit of alignment shift, in
;    exchange for not needing a separate iteration counter or a
;    second labelled loop - a real example of the "cycles vs. code
;    size vs. clarity" trade-off this project cares about. A
;    modernised version could replace the `jsr algnsw` / implicit
;    loop-back with a plain `jmp` back to the exponent compare,
;    saving the JSR/RTS overhead per shift at the cost of needing
;    an explicit loop label - noted here rather than done, to keep
;    this port behaviourally identical to the published original.
;
; FP_FMUL LSB LOSS ON FULL-MANTISSA MULTIPLIES - FIXED 20260913
; -------------------------------------------------------------
; [FIXED 20260913] The LSB loss this section documents has been
; fixed. Derivation, verification history, and the reason earlier
; fix attempts failed are retained below for context - read them if
; you want to understand what the fix is doing and why the simpler
; "reduce the iteration count" approach that seems obvious does not
; work.
;
; THE FIX (three small additions to lib_fp.s):
;   1. fmul captures FP_EXT[0] bit 7 into fp_mul_extra at mdend -
;      that bit is the LSB the final loop iteration pushed out of
;      the accumulator.
;   2. norm1, after its three shift instructions, folds that bit
;      back in: OR #$01 into the shifted mantissa's LSB if the
;      post-shift mantissa is positive; DEC with borrow propagation
;      through M2 -> M1 -> M0 if negative. Sign-awareness is
;      REQUIRED - an unconditional OR (which was the first
;      hypothesis) fails on negative products, because fcompl's
;      2's-complement negation inverts the direction the LSB needs
;      to be adjusted in. ds_diag6.py's 300-case mixed-sign sweep
;      showed 35/60 LSB-loss cases need the DEC path; an
;      unconditional OR leaves all 35 wrong.
;   3. Every arithmetic entry point (fadd, fsub, @fdiv_normal,
;      float_conv's @do_norm, FP_NORM_ENTRY, FP_NEGATE_ENTRY)
;      clears fp_mul_extra, so a stale flag from a prior FMUL whose
;      product was already normalized (and therefore never entered
;      norm1) cannot leak into a subsequent operation.
;
; VALIDATED BY:
;   ds_diag5.py  - identified the missing bit and confirmed the fix
;                  on positive products.
;   ds_diag6.py  - confirmed sign-awareness is required (300-case
;                  mixed-sign sweep: signed_fold 300/300,
;                  or_only 265/300, 0 regressions either way).
;   ds_diag7.py  - exact byte-sequence validation in isolated
;                  scratch RAM: 9/9 cases pass, including three
;                  borrow-propagation edge cases.
;
; KNOWN LIMITATION OF THE FIX: the fold-in assumes at most one
; left-shift is ever needed to normalize an FMUL product. This is
; true for any FMUL of two normalized mantissas (product magnitude
; lies in [1,4), which needs at most one shift), and confirmed by
; ds_diag6's sweep (every case with a fold-in had shifts == 1). If
; a future change to FMUL or norm ever introduces 2-shift cases,
; the current fix would misplace the folded bit (it always lands in
; M2 bit 0, which is only correct for the 1-shift case) - the fix
; would need extending to shift the bit into position based on
; shift count.
;
; ---- Original (now-historical) derivation of the bug ----
; FP_FMUL(x, y) truncates the LSB of the 24-bit mantissa when the
; full 48-bit product would need that bit to be correct. This
; manifests when both multiplicands have full mantissas, i.e. their
; mantissa bytes have bit 0 set. Sparse mantissas (10 = $500000,
; 1.0 = $400000, 3 = $600000) are unaffected.
;
; Concretely: FMUL(1.0, pi) returns $816487EC instead of $816487ED.
; FMUL(pi/4, pi/4) returns $7F4EF4F2 (correct). FMUL(2/3, 2/3)
; returns $8071C71A instead of the exact value.
;
; The bug propagates through:
;   - FP_FMOD(x, x) = ~half-ulp residue instead of 0
;   - sin(2*pi) = ~9.5e-7 instead of 0
;   - cos(3*pi/2) = same residue
;   - FP_TAN's asymptote behavior: cos(90 deg) rounded to exact 0
;     after the fsub fix, so tan(90 deg) traps; cos(270 deg)
;     currently does not.
;
; ATTEMPTS AT A FIX - DO NOT REPEAT
; ---------------------------------
; A two-line fix (loop count 23 instead of 24, plus a compensating
; `dec FP1_EXP` after md2) was developed and validated via py65
; simulation (ds_diag1/ds_diag2/ds_diag3). It appeared to work for
; isolated FMUL tests and for the specific trig cases that
; motivated it. However, chain-level testing (ds_diag4) showed it
; fails whenever the correct mantissa's MSB is close to the sign
; bit: doubling the raw accumulator flips a positive mantissa to
; a negative one. FMUL(pi/4, pi/4) is the simplest counterexample.
;
; The ds_diag3 test suite did not include such a case, so the fix
; looked more general than it was.
;
; The failure mechanism, stated precisely: dropping to 23 iterations
; means the final right-shift no longer happens, so the accumulator
; is 2x what it should be; the compensating `dec FP1_EXP` restores
; the numeric value, but only if the doubled mantissa is still a
; valid normalized 2's-complement value. When the correct mantissa's
; MSB is already close to bit 23 (the sign bit), doubling overflows
; into a negative-magnitude representation. ds_diag4's chained
; Horner replay caught this directly: FMUL(pi/4, pi/4) should produce
; $7F,$4E,$F4,$F2 (positive), but the patched code returned
; $7E,$9D,$E9,$E5 (negative). Not a rounding issue - a fundamental
; incompatibility between the 23-iteration shortcut and the
; 2's-complement sign representation.
;
; Any future attempt to fix the FMUL LSB loss must:
;   (a) preserve the mantissa's SIGN through the iteration-count
;       change (e.g. shift the accumulator right after the loop
;       rather than decrement the exponent), AND
;   (b) not disturb the classify state that md2/md3 set up for
;       norm/norm1's CEILING/FLOOR rescue paths (the ds_diag2
;       unconditional patch broke those; the ds_diag3 conditional
;       version fixed that part but failed requirement (a)).
; Both requirements simultaneously are non-trivial. The correct
; place to fix this is probably inside the multiply loop itself,
; not by changing its iteration count - e.g. by keeping a separate
; 25th bit for the LSB and folding it back via rounding rather than
; truncation.
;
; The reverted code fragment is preserved, commented out, right
; after the `clc` in fmul's main path - re-enabling it WITHOUT
; satisfying both (a) and (b) above will reintroduce the sign-flip
; regression.
;
; EXPONENT $FF BOUNDARY - FIXED (formerly documented here as a
; permanent limitation - see HISTORY below)
; -----------------------------------------------------------------------
; `fsub` now correctly handles an operand at this format's absolute
; exponent ceiling ($FF) as FP1, in any combination with FP2.
; Confirmed via a full VICE/hardware regression run (tr_exp_boundary_
; ff.s T00-T10, all passing, plus a complete pass of every other test
; group in this library) exercising every FADD/FSUB/FMUL/FDIV/
; FP_COMPARE/FP_TO_ASCII_SCI/FP_TO_IEEE754/FP_TO_BASIC combination
; against a real hardware-confirmed $FF-exponent value:
;
;   FP_FADD(FP1=$FF-value, FP2=anything)      - succeeds
;   FP_FADD(FP1=anything,  FP2=$FF-value)     - succeeds
;   FP_FSUB(FP1=$FF-value, FP2=10.0)          - succeeds (was: TRAPS)
;   FP_FSUB(FP1=10.0,      FP2=$FF-value)     - succeeds
;   FP_COMPARE(FP1=$FF-value, FP2=anything)   - succeeds (was: TRAPS)
;   FP_FDIV, FP_FMUL                          - unaffected either way
;     (FMUL/FDIV overflow/underflow per their own ordinary exponent
;     add/subtract arithmetic instead - a different, already-
;     understood mechanism, not this one)
;
; ROOT CAUSE (now fixed - documented for anyone touching `fsub`
; again): `fsub` used to reach `algnsw` (the alignment trampoline
; described above) via `jsr fcompl` -> `norm`'s early-return path
; (taken whenever the just-negated FP1 mantissa is ALREADY
; normalized, the common case) -> a bare `rts` that popped the
; return address `jsr fcompl` left on the stack, landing directly at
; `swpalg: jsr algnsw` - WITHOUT the fresh `lda FP2_EXP; cmp FP1_EXP`
; that `fadd`'s own top-of-loop entry always performs first. Carry
; going into `algnsw`'s `bcc swap` on that first pass was whatever
; `norm`'s own `asl` (testing the negated mantissa's sign, for
; normalization) happened to leave behind - NOT a genuine "which
; operand has the smaller exponent" test. For FP1 already at the
; format's absolute exponent ceiling ($FF), there was zero headroom
; left: whenever that stale carry happened to route into `rtar`
; (shift FP1 rather than swap operands first), `rtlog`'s `inc
; FP1_EXP` wrapped $FF -> $00 and tripped the generic overflow trap
; before a single alignment bit was applied. For any other exponent
; value this same wrong routing was harmless to the FINAL result (a
; few wasted iterations before the next `fadd`-top re-entry, which
; DOES do the real comparison, self-corrected) - but not entirely
; free even then: a wrongly-routed first shift could cost one
; silently-discarded mantissa bit from the wrong operand before
; self-correcting, a small precision loss rather than a trap. This
; is almost certainly why the bug went unnoticed until an operand sat
; at the literal exponent ceiling with nothing left to give, and is
; also the likely explanation for at least one other observed
; precision change after the fix - see lib_fp_tan.s's own updated
; SCOPE note on cos(90deg) now measuring exactly 0.0 instead of
; ~9.5e-7.
;
; THE FIX: `fsub` now does `jmp fadd` immediately after `jsr fcompl`,
; instead of falling straight through into `swpalg`. Since `jsr
; fcompl`'s own trampoline-style return (via `norm`'s or `rtlog`'s
; shared tail) lands wherever the instruction immediately following
; `jsr fcompl` points, this routes FP1's post-negation state through
; `fadd`'s OWN entry point first - which always performs a genuine
; `lda FP2_EXP; cmp FP1_EXP` before ever calling `algnsw`, so
; `algnsw` never again sees a stale, meaningless carry on `fsub`'s
; first pass. As a side effect this also removes a separate, milder
; issue: the old code unconditionally invoked `algnsw` once even when
; the negated FP1's exponent already equalled FP2's (no alignment
; needed at all) - the fix goes straight to `add` in that case,
; matching `fadd`'s own normal-path behaviour exactly.
;
; SCOPE OF THE FIX: `FP_NEGATE` (the standalone `fcompl` alias used
; directly by lib_fp_ieee754.s, lib_fp_basic.s, lib_fp_ceil.s/
; lib_fp_floor.s) is UNCHANGED and unaffected - those callers have
; their own call site with their own following instruction, entirely
; separate from `fsub`'s internal `jsr fcompl`. FP_FMUL/FP_FDIV's own
; `fcompl` usage (reached via fall-through from `normx`, never via
; `jsr` from `fsub`) is likewise a completely separate code path.
;
; DOWNSTREAM NOTE: FP_TO_ASCII_SCI_PROC's `@norm_high` loop
; (lib_fp_to_ascii_sci.s) still contains a caller-side workaround
; that special-cases FP1_EXP=$FF to skip its own FP_COMPARE_TO_MACRO
; call - that workaround predates this fix and is now REDUNDANT (the
; underlying FP_COMPARE/FP_FSUB it routed around is itself fixed) but
; still harmless to leave in place; removing it is an optional
; cleanup, not required for correctness.
;
; HISTORY: this section formerly documented the above as a permanent,
; unfixable limitation ("NOT FIXED HERE... the chosen fix lives at
; the CALLER level instead"), on the reasoning that FP_CORE_PROC's
; interleaved `.block` control flow couldn't be safely edited without
; re-verifying the entire FADD/FSUB/FMUL/FDIV/FIX/SWAP surface. That
; full re-verification has now been done (tr_exp_boundary_ff.s
; T00-T10 plus a complete run of every other test group in this
; library, all passing) - the fix was small and surgical enough (one
; `jmp` in `fsub`) to make that re-verification tractable after all.
;
; EXPONENT OVERFLOW BOUNDARY (FMUL/FDIV) - FIXED, INCLUDING A SECOND
; BUG FOUND UNDERNEATH THE FIRST ONE, PLUS TWO ADJACENT GAPS FOUND
; DURING VERIFICATION - ALL FOUR NOW HARDWARE-CONFIRMED
; -----------------------------------------------------------------------
; `ovchk` used to pre-check a provisional exponent before normalization
; had run, trapping some genuinely valid boundary results as if they
; were overflow. A follow-up investigation found this trap was not
; simply overcautious: it was the ONLY thing preventing a second,
; independent bug in `norm` itself (the "floor-guard" bug, described
; below) from producing silently WRONG results instead of a clean
; trap. Both had to be fixed together - relaxing `ovchk` alone would
; have converted a 100%-trap failure mode into a ~98%-silent-
; corruption failure mode, a regression dressed as a fix. That
; combined fix is what's described here, along with two further,
; genuinely separate bugs (a second FDIV-only exponent collision, and
; an FADD/FSUB classify-state leak) found while verifying it.
;
; THE FLOOR-GUARD BUG
; -----------------------------------------------------------------------
;   norm:
;       ... (all-zero-mantissa check, unrelated) ...
;       lda FP1_MANT
;       asl
;       eor FP1_MANT
;       bmi rts1            ; top two bits differ: already normalized
;       lda FP1_EXP
;       bne norm1           ; FP1_EXP != 0: shift+decrement, loop
;   rts1:
;       rts                 ; <-- ALSO reached when FP1_EXP == 0,
;                           ;     REGARDLESS of whether the mantissa
;                           ;     was actually normalized
;
; `bne norm1` was written as an underflow guard, but it does not
; distinguish "stopped because the mantissa is already fine" from
; "stopped because FP1_EXP is out of room, even though the mantissa
; is NOT fine." Both fell through to the same `rts1` exit, returning
; an UN-NORMALIZED mantissa paired with FP1_EXP=$00 - wrong, not
; merely imprecise, with no signal anything went wrong.
;
; THE FIX: A ONE-SHOT CLASSIFICATION FLAG, SET BEFORE THE MULTIPLY/
; DIVIDE LOOP RUNS, CONSULTED ONLY AT THE AMBIGUOUS POINT
; -----------------------------------------------------------------------
; `fp_norm_boundary_state` (NORMAL/CEILING/FLOOR) is computed from the
; TRUE, unwrapped exponent relationship (via EOR #$80 + ADC/SBC on the
; raw excess-128 bytes, reading the 6510's own V/N flags) before the
; provisional exponent collapses to a single ambiguous byte. `norm`'s
; FP1_EXP==0 branch consults it exactly once - CEILING permits the
; decrement (wrapping $00->$FF is genuinely correct here), FLOOR forces
; a clean underflow to 0.0 instead, and NORMAL (the default, and the
; state used by every caller that never sets it otherwise) preserves
; the library's original behaviour untouched. The flag is cleared on
; every exit from `norm` and on every early-return path (`zero_fp1`,
; `float_conv`'s own zero case, `md2`'s underflow shortcut), so a
; caller that never sets it never sees anything but NORMAL.
;
; FMUL's own classify block sits between `jsr md1` and the original
; `adc FP1_EXP`, computing `S = (te1+te2) mod 256` via the EOR/ADC
; trick above. Both of FMUL's boundary points (true_sum=127, the
; valid ceiling, and true_sum=-129, one step past the valid floor)
; alias to the SAME raw byte ($80, always with bit 7 set) once its
; own "+1" pre-compensation is folded in - which is why FMUL only
; ever needs ONE classify branch, using the ADC's own V flag to tell
; the two apart (V=0 -> CEILING, V=1 -> FLOOR).
;
; CORRECTED MEASUREMENT: THE ORIGINAL "98%/2%" SPLIT WAS ITSELF
; MEASURED WITH A FLAWED HARNESS
; -----------------------------------------------------------------------
; The sweep that originally characterized this bug's severity reported
; ~98% of CEILING-boundary cases needing (and correctly receiving) the
; norm1 rescue, and ~2% already normalized with no rescue needed. That
; measurement used a py65 harness that stopped the instant execution
; reached `.rts1`'s ADDRESS, treating arrival there as automatically
; terminal. It is not: `.rts1`'s own code, a few instructions further
; on, can itself decide to `jmp FP_ERROR` for the "already normalized,
; genuinely overflowed, no rescue occurred" sub-case - and the old
; harness's premature stop silently snapshotted FP1's PRE-DECISION
; state and reported every one of those genuine traps as a clean
; success. Once the harness was corrected to only treat reaching
; FP_ERROR_PROC (a real trap) or a genuine RTS back to the caller as
; terminal, the TRUE, corrected split measured 71.6% rescued / 28.4%
; genuine overflow - both counted properly for the first time. T26/T27
; in tr_exp_boundary_all.s are hardware-confirmed examples of each side
; of this corrected split, closing a gap the original test suite never
; exercised (every existing test used a hand-picked "needs decrement"
; mantissa, never the "already normalized, genuinely traps" one).
;
; FDIV NEEDED ITS OWN CLASSIFY BLOCK ENTIRELY - IT HAD NONE AT ALL
; -----------------------------------------------------------------------
; Unlike FMUL, FDIV originally had NO classification code whatsoever:
; `jsr md1` flowed directly into the unmodified `sbc FP1_EXP`. Its
; boundary behaviour was governed entirely by whatever
; `fp_norm_boundary_state` happened to hold from the last unrelated
; FMUL/FDIV call anywhere in the program - a real, confirmed bug (see
; the FADD/FSUB section below for the same class of problem occurring
; a second time, independently).
;
; FDIV's exponent arithmetic has no "+1" pre-compensation (confirmed
; empirically - PRE_COMPENSATION_DIV=0, verified via a live VICE trace
; of 12.0/10.0 and 10.0/12.0 at .div1's entry). This means FDIV's TWO
; boundary collisions land on TWO DIFFERENT raw bytes, not one, and
; needed two structurally different fixes:
;
;   COLLISION 1 ($7F -> $FF after md3's eor): true_diff=127 (the
;   valid ceiling) and true_diff=-129 (one step past the valid floor,
;   UNCONDITIONALLY invalid regardless of mantissa - unlike FMUL's own
;   floor, dividing two [1,2) mantissas can only ever need a LEFT
;   shift to normalize, so a genuinely-too-small quotient never gets
;   "rescued" by renormalization the way FMUL's mantissa PRODUCT can).
;   $FF is never norm1's blocked decrement value, so the valid side
;   (V=0) needs no help at all - ordinary norm/norm1 already handles
;   it. The invalid side (V=1) is forced to zero immediately, inside
;   the classify block itself, with no jsr used to enter that block
;   and therefore no extra stack frame to discard before its own rts.
;
;   COLLISION 2 ($80 -> $00 after md3's eor): true_diff=-128 (the
;   valid floor) and true_diff=+128 (one step past the valid ceiling).
;   UNLIKE collision 1, BOTH sides here genuinely depend on the
;   mantissa: a valid-floor value needing a decrement really does
;   underflow (true final = -129, invalid - force zero); an invalid-
;   ceiling+1 value needing a decrement really is rescued (true final
;   = 128-1 = 127, valid - the classify-and-defer treatment applies
;   here, structurally identical to FMUL's own CEILING/FLOOR handling,
;   but with the V-flag mapping INVERTED relative to both FMUL's
;   convention and FDIV's own collision-1 convention: V=0 (true_diff=
;   -128) needs FLOOR semantics, V=1 (true_diff=+128) needs CEILING
;   semantics. This was confirmed via exact 6502 SBC V-flag emulation
;   (verify_v_flag.py) before being trusted, specifically because
;   naively copying collision 1's V=0=>CEILING,V=1=>FLOOR convention
;   would have been exactly backwards here - caught before it ever
;   reached assembly.
;
;   A THIRD, SEPARATE DEFECT WAS FOUND WHILE FIXING COLLISION 1:
;   `md2`'s own pre-existing "carry clear and result positive means
;   genuine underflow" shortcut assumed that combination ALWAYS means
;   ordinary underflow - true for FMUL (whose "+1" puts both its
;   boundary values at raw $80, always negative, making this shortcut
;   structurally unreachable for FMUL's own boundary cases) but FALSE
;   for FDIV, whose collision-1 boundary values BOTH collapse to raw
;   $7F (positive). Whether carry ends up set or clear going into this
;   shortcut depends on incidental byte-level borrow behaviour in the
;   real `sbc FP1_EXP`, NOT on which true boundary is intended -
;   confirmed via direct trace that a genuine FLOOR case could reach
;   this shortcut with carry clear and silently return canonical zero
;   WITHOUT ever consulting the classify flag, wrong whenever the
;   quotient mantissa was already normalized and the correct answer
;   was a valid nonzero result at the true floor. Fixed by deferring
;   to the classify flag here too, exactly as `ovchk` already does.
;
; CONFIRMED SEVERITY (measured post-fix, at scale, both FDIV
; collisions): collision 1's underflow straddle showed 100% correct
; canonical-zero results (previously silently wrong for the ~48-70%
; of cases needing rescue - see diag19.py's original trace); collision
; 2's floor side showed a genuine, correct mantissa-dependent split
; (52% valid nonzero / 48% correctly forced zero); collision 2's
; ceiling+1 side showed a genuine, correct 47.1% rescued / 52.9%
; correctly-trapped split, replacing what was previously a 100%
; unconditional (and wrong, for the rescuable half) trap.
;
; FADD/FSUB HAD A SEPARATE, INDEPENDENT GAP: THE CLASSIFY FLAG THEY
; NEVER SET COULD STILL BE CONSULTED AGAINST THEM
; -----------------------------------------------------------------------
; `fp_norm_boundary_state` is shared, global state - set only by
; FMUL/FDIV's own classify blocks, but consulted by `norm`'s FP1_EXP
; ==0 branch regardless of which of the four arithmetic operations got
; it there. FADD and FSUB reach that same shared branch (`fadd`
; directly; `fsub` via its own `jsr fcompl` negation detour, which
; reaches `norm` through `fcompl`'s fall-through BEFORE `fsub` ever
; executes its later `jmp fadd`) without ever touching the flag
; themselves. Confirmed via direct memory poisoning (diag17.py/
; diag18.py): an entirely ordinary FADD or FSUB landing on FP1_EXP==0
; could trap, silently corrupt, or behave correctly depending ENTIRELY
; on what an unrelated, earlier FMUL/FDIV call elsewhere in the same
; program happened to leave in that one shared byte - not on anything
; about the FADD/FSUB operands themselves.
;
; FADD/FSUB never legitimately need CEILING/FLOOR rescue - adding two
; already-normalized mantissas of matching exponent needs at most a
; small, bounded shift, never the multiply/divide-specific "+1"
; bookkeeping that creates the ambiguity in the first place. So the fix
; is simply to reset the flag to NORMAL, unconditionally, at BOTH
; `fadd`'s entry AND `fsub`'s entry (not just one) - `fsub`'s own reset
; is required separately because `fcompl`'s pass through `norm` during
; negation happens before `fsub`'s later `jmp fadd` would otherwise
; have reset it, confirmed by diag18.py: resetting only at `fadd`'s
; entry left `fsub`'s own poisoned-flag cases still wrong (FLOOR
; poisoning returned FP2 unchanged instead of the real difference;
; CEILING poisoning produced a wildly wrong magnitude and sign).
;
; VERIFICATION STATUS - ALL FOUR FIXES ABOVE
; -----------------------------------------------------------------------
; Confirmed via a validated py65 instruction-level simulator (loaded
; from the actual assembled .prg and label file, not a hand-
; transcription), at scale (200+ random-mantissa sweeps per boundary
; point, both fixed "round" mantissas and random ones), AND on
; physical C64U/VICE hardware via tr_exp_boundary_all.s's T00-T31 (all
; passing) - the consolidated successor to the earlier tr_exp_boundary
; .s/tr_exp_boundary_ff.s/tr_exp_muldiv_boundary.s, which are retired.
; Per this project's own standing principle, note that even the
; SIMULATOR HARNESS ITSELF produced one confirmed-wrong measurement
; along the way (the 98%/2% figure, and a related sweep result that
; looked like 100% failure until traced down to a harness bug rather
; than a code bug) - hardware confirmation, not simulator output
; alone, remains the actual authority, and every number in this note
; has now cleared that bar.
;
; STILL OPEN, NOT YET FIXED
; -----------------------------------------------------------------------
; `fp_norm_boundary_state` can still be left in a stale, non-NORMAL
; state by: (1) any direct external caller of FP_NORM/FP_NEGATE that
; bypasses FADD/FSUB/FMUL/FDIV's own entry-point resets entirely -
; concretely, lib_fp_ieee754.s and lib_fp_basic.s's own FP_NEGATE
; calls, lib_fp_ceil.s/lib_fp_floor.s's chain through FP_NEGATE/
; FP_TRUNC, and lib_fp_from_uint16.s/lib_fp_from_int24.s/
; lib_fp_from_uint24.s's direct FP_NORM calls; (2) any `jmp FP_ERROR`
; trap site that fires while the flag is non-NORMAL, since none of
; them currently clear it before jumping. Neither has a confirmed
; failing test case yet - both are credible, not yet demonstrated,
; and are the next items to investigate.
;
; ERROR / OVERFLOW HANDLING
; ---------------------------
; The original package has three trap points that were each just a
; bare BRK, on the assumption the caller had installed a BRK
; handler (this predates any notion of a portable error-return
; convention). This port replaces all three with calls into
; FP_ERROR (lib_fp_error.s), which prints what went wrong
; and unwinds to a recovery point the caller establishes up front
; with FP_ERROR_INIT_MACRO (macros_fp.s) - see lib_fp_error.s's
; header for the full setjmp/longjmp-style contract, the error code
; list, and why a single shared recovery point (rather than trying
; to unwind exactly one call level) is the right model here. The
; three trap sites are:
;   FP_CORE_PROC's fdiv/rtlog/ovchk - overflow in FADD/FSUB/FMUL/
;     FDIV/FIX, or division by zero (detected distinctly - see
;     lib_fp_error.s)
;   FP_LOG_PROC's error_trap - LOG/LOG10 argument <= 0 (no real log)
;   FP_EXP_PROC's ovflw_trap - EXP argument too large, e^x overflows
; There is no trap for underflow - results that underflow are
; silently set to 0.0, exactly as documented in the original.
; REQUIRES lib_fp_error.s TO BE ASSEMBLED BEFORE THIS FILE -
; see the dependency note below.
; ============================================================

; ============================================================
; FP_CORE_PROC
; Purpose : FP_FADD, FP_FSUB, FP_FMUL, FP_FDIV, FP_FLOAT, FP_FIX,
;           FP_SWAP - see the file header for why these seven
;           entry points live in one .proc instead of seven.
; ============================================================
.proc FP_CORE_PROC

; ------------------------------------------------------------
; add - FP1_MANT += FP2_MANT (3-byte mantissa add, LSB first)
; Entry : FP1_MANT, FP2_MANT hold the two mantissas to add
; Exit  : FP1_MANT = FP1_MANT + FP2_MANT, carry/overflow set
;         normally by the final ADC
; Destroys: A, X
; ------------------------------------------------------------
add:
    clc
    ldx #$02                ; index for 3-byte add, LSB first
add1:
    lda FP1_MANT,x
    adc FP2_MANT,x
    sta FP1_MANT,x
    dex                     ; advance to next more significant byte
    bpl add1
    rts

; ------------------------------------------------------------
; md1 / abswap / abswp1 - take the absolute value of BOTH
; mantissas and swap FP1<->FP2. See the file header's "DOUBLE-
; ENTRY TRICK" note - md1 has no RTS of its own; it relies on
; abswap being run twice via the JSR/fall-through/RTS pattern
; below, once for each operand. IMPORTANT: if a negation is
; needed, this path additionally detours through fcompl/addend/
; norm/rtlog before returning - see the file header's IMPORTANT
; CORRECTION note under THE DOUBLE-ENTRY TRICK.
; Entry : FP1/FP2 loaded with the two operands
; Exit  : both mantissas made non-negative, FP_SIGN's low bit
;         toggled once per negation (tracks overall sign parity
;         for FP_FMUL/FP_FDIV), FP1/FP2 restored to their
;         original slots, carry set
; Destroys: A, X, Y (Y is clobbered by the swap loop)
; ------------------------------------------------------------
md1:
    asl FP_SIGN             ; clear LSB of running sign flag
    jsr abswap              ; first pass: process FP1's mantissa
                            ; (falls through to swap, whose rts
                            ; re-enters abswap - see file header)
abswap:
    bit FP1_MANT            ; is FP1's mantissa negative?
    bpl abswp1              ; no: just fall through to swap
    jsr fcompl              ; yes: 2's-complement it
    inc FP_SIGN             ; and flip the running sign parity
abswp1:
    sec                     ; carry set for return to mul/div
    ; falls through into swap

; ------------------------------------------------------------
; swap - exchange FP1 (exponent + 3-byte mantissa) with FP2,
;        4 bytes total. Also used standalone (FP_SWAP) and as
;        the second half of the abswap double-entry trick above.
; Entry : FP1, FP2 loaded
; Exit  : FP1 and FP2 contents exchanged
; Destroys: A, X, Y
; ------------------------------------------------------------
swap:
    ldx #$04                ; index for 4-byte swap
swap1:
    sty FP_EXT-1,x          ; stash previous Y into scratch
    lda FP1_EXP-1,x
    ldy FP2_EXP-1,x
    sty FP1_EXP-1,x
    sta FP2_EXP-1,x
    dex                     ; advance index to next byte
    bne swap1               ; loop until done
    rts

; ------------------------------------------------------------
; float_conv (FP_FLOAT) - convert the 16-bit integer currently
; sitting in FP1_MANT/FP1_MANT+1 (high byte first) into a
; normalized float, left in FP1.
; Entry : FP1_MANT = integer high byte, FP1_MANT+1 = low byte
; Exit  : FP1 = normalized float equal to that integer
; Destroys: A
; ------------------------------------------------------------
float_conv:
    lda #$8e                ; provisional exponent = 2^14
    sta FP1_EXP
    lda #0
    sta FP1_MANT+2          ; clear the (unused-by-integer) LSB
    lda FP1_MANT
    ora FP1_MANT+1
    bne @do_norm

    FP_NORM_STATE_NORMAL_MACRO
    FP_MUL_EXTRA_CLEAR_MACRO

    sta FP1_EXP             ; A = 0
    rts
@do_norm:
    FP_MUL_EXTRA_CLEAR_MACRO    ; [FIX 20260913] clear stale flag
    jmp norm

norm1:
    FP_NORM_STATE_NORMAL_MACRO
    dec FP1_EXP
    asl FP1_MANT+2
    rol FP1_MANT+1
    rol FP1_MANT

; --- PATCH BEGIN ---
    ; [FIX 20260913] Fold in FMUL's captured LSB. OR #$01 into the
    ; shifted mantissa's LSB for a positive result (bit 7 = 0); DEC
    ; with borrow propagation for a negative one (bit 7 = 1). Test
    ; sign AFTER the shift, since the shift moves the sign bit and
    ; the LSB position together. Validated as an exact byte sequence
    ; against a grid of pre-norm1 states in ds_diag7.py (all 9 cases
    ; pass, including three borrow-propagation edge cases).
    lda fp_mul_extra
    beq @no_extra_fold
    bit FP1_MANT            ; sign test on the SHIFTED mantissa
    bmi @extra_fold_neg
    lda FP1_MANT+2
    ora #$01                ; positive: OR 1 into LSB
    sta FP1_MANT+2
    jmp @extra_fold_done
@extra_fold_neg:
    lda FP1_MANT+2
    bne @extra_fold_dec_low
    lda #$FF                ; M2 was $00 - borrow into M1
    sta FP1_MANT+2
    lda FP1_MANT+1
    bne @extra_fold_dec_mid
    lda #$FF                ; M1 was $00 - borrow into M0
    sta FP1_MANT+1
    dec FP1_MANT
    jmp @extra_fold_done
@extra_fold_dec_mid:
    dec FP1_MANT+1
    jmp @extra_fold_done
@extra_fold_dec_low:
    dec FP1_MANT+2
@extra_fold_done:
    FP_MUL_EXTRA_CLEAR_MACRO    ; consume the flag
@no_extra_fold:
; --- PATCH END ---

    ; falls through into norm, as before

norm:
    lda FP1_MANT
    ora FP1_MANT+1
    ora FP1_MANT+2
    beq zero_exponent
    lda FP1_MANT
    asl
    eor FP1_MANT
    bmi rts1
    lda FP1_EXP
    bne norm1

    ; FP1_EXP==0 AND mantissa needs a decrement - the ambiguous case
    lda fp_norm_boundary_state
    cmp #FP_NORM_STATE_CEILING
    beq norm1                   ; ceiling: wrap 0->$FF is CORRECT
    cmp #FP_NORM_STATE_FLOOR
    beq @force_underflow        ; floor: true result is below the
                                ; floor - underflow to 0.0, not a trap
    jmp rts1                    ; NORMAL: unchanged pre-fix behaviour -
                                ; every other caller's ordinary
                                ; underflow-through-zero is untouched

@force_underflow:
    FP_NORM_STATE_NORMAL_MACRO
    FP_FP1_ZEROED_MACRO
    rts

zero_exponent:
    FP_NORM_STATE_NORMAL_MACRO
    lda #0
    sta FP1_EXP
    rts

rts1:
    lda FP1_EXP
    bne @plain_rts
    lda fp_norm_boundary_state
    cmp #FP_NORM_STATE_CEILING
    bne @plain_rts                      ; covers NORMAL and FLOOR's valid 2%
    FP_NORM_STATE_NORMAL_MACRO
    lda #FP_ERROR_CODE_GENERIC_OVERFLOW ; the genuine ~2% overflow: no
    jmp FP_ERROR                        ; decrement occurred to rescue it
@plain_rts:
    FP_NORM_STATE_NORMAL_MACRO
    rts


; ------------------------------------------------------------
; fsub (FP_FSUB) - FP1 = FP2 - FP1
; Entry : FP1, FP2 loaded with minuend/subtrahend per above
; Exit  : FP1 = FP2 - FP1, normalized
; Destroys: A, X, Y; FP2's final contents depend on path taken -
;           on the general (both-operands-nonzero) alignment path,
;           FP2 is left holding the addend of greater magnitude (a
;           side effect of sharing fadd's tail); if either original
;           operand was zero, fadd's own zero fast-path applies
;           instead and FP2 ends up holding zero, not a "greater
;           magnitude" value - see fadd's own zero-optimisation
;           comments just below its label.
; ------------------------------------------------------------
fsub:
    FP_NORM_STATE_NORMAL_MACRO
    FP_MUL_EXTRA_CLEAR_MACRO

    ; Optimise Zero‑operand fast paths
    ; If FP1 is zero, result = FP2 (no need to negate)
    lda FP1_MANT
    ora FP1_MANT+1
    ora FP1_MANT+2
    bne @do_negate
    jmp fadd        ; fadd will see FP1 zero and copy FP2

@do_negate:
    jsr fcompl      ; negate FP1's mantissa (2's complement) clears carry unless the result is zero
    jmp fadd        ; [Codex] suggested fix.

swpalg:
    jsr algnsw              ; align mantissas or swap - see below;
                            ; also the re-entry target of fadd's
                            ; alignment trampoline (file header)

; ------------------------------------------------------------
; fadd (FP_FADD) - FP1 = FP1 + FP2
; Entry : FP1, FP2 loaded with the two addends
; Exit  : FP1 = FP1 + FP2, normalized
; Destroys: A, X, Y
; Caution: per the original documentation, overflow can occur if
;          the sum is outside roughly +/-2^128; on overflow this
;          calls FP_ERROR (see the ERROR / OVERFLOW HANDLING
;          note in the file header).
; ------------------------------------------------------------
fadd:
    FP_NORM_STATE_NORMAL_MACRO
    FP_MUL_EXTRA_CLEAR_MACRO

    ; Optimise Zero‑operand fast paths
    lda FP1_MANT
    ora FP1_MANT+1
    ora FP1_MANT+2
    bne @check_fp2
    ; If FP1 is zero, copy FP2 into FP1 (using the existing swap routine) and return.
    jsr swap                ; exchange FP1 and FP2 (now FP1 = FP2)
    rts
@check_fp2:
    lda FP2_MANT
    ora FP2_MANT+1
    ora FP2_MANT+2
    bne @normal
    ; If FP2 is zero, return FP1 unchanged.
    rts

@normal:
    lda FP2_EXP
    cmp FP1_EXP             ; compare the two exponents
    bne swpalg              ; unequal: align mantissas (loops back
                            ; here via the trampoline until equal -
                            ; see file header)
    jsr add                 ; exponents equal: add aligned mantissas

addend:
    jvc norm                ; no overflow: normalize the result
    bvs rtlog               ; overflow: shift right one bit first
algnsw:
    jcc swap                ; carry clear (from fcompl): just swap
                            ; the operands rather than shift
rtar:
    lda FP1_MANT            ; sign of FP1's mantissa into carry...
    asl                     ; ...for a right ARITHMETIC shift
rtlog:
    inc FP1_EXP             ; bump exponent to compensate for the one-bit right shift about to happen
    bne rtlog_ok            ; exponent didn't wrap: no overflow

    ; [FIX] reset before this trap - fadd/fsub's own entry-point reset
    ; already ran earlier in this SAME call, so the flag is almost
    ; certainly already NORMAL here in practice, but this closes the
    ; gap unconditionally rather than relying on that being true for
    ; every future call path that might reach rtlog
    FP_NORM_STATE_NORMAL_MACRO
    lda #FP_ERROR_CODE_GENERIC_OVERFLOW ; [ERROR HANDLING] exponent wrapped
    jmp FP_ERROR                        ; past $FF: overflow (code 0) - see lib_fp_error.s. Inlined here
                                        ; rather than branching to a shared distant label: this exact branch
                                        ; sat at the very edge of the 8-bit branch range even before this file
                                        ; had an error handler (see the FP_CORE_PROC .block note above) -
                                        ; inlining removes the distance concern rather than growing it
rtlog_ok:
rtlog1:
    ldx #$fa                ; index for a 6-byte right shift, spanning FP1_MANT (3B) + FP_EXT (3B)
                            ; - see labels_fp.s for why FP_EXT must physically follow FP1_MANT
ror1:
    lda #$80
    bcs ror2
    asl
ror2:
    lsr FP_EXT+3,x          ; simulate ROR via LSR+ORA (this byte
    ora FP_EXT+3,x          ; hasn't been shifted by this pass
    sta FP_EXT+3,x          ; yet, so LSR/ORA/STA == ROR here)
    inx                     ; next byte of the shift
    bne ror1                ; loop until all 6 bytes done
    rts

; ------------------------------------------------------------
; Description:  Zero FP1
; Exit:         FP1 is set to zero
; Destroys:     A
; ------------------------------------------------------------
zero_fp1:
    FP_NORM_STATE_NORMAL_MACRO
    FP_FP1_ZEROED_MACRO
    rts

; ------------------------------------------------------------
; fmul (FP_FMUL) - FP1 = FP1 * FP2 (24-bit x 24-bit -> 24-bit,
; truncated, via 24 iterations of shift-and-conditionally-add)
; Entry : FP1, FP2 loaded with the two factors
; Exit  : FP1 = FP1 * FP2, normalized
; Destroys: A, X, Y
; Known limitation: see the file header's "FP_FMUL LSB LOSS ON
; FULL-MANTISSA MULTIPLIES - KNOWN LIMITATION" section. The final
; iteration's right-shift discards the accumulator's LSB whenever
; the multiplicands have full mantissas (bit 0 set in the mantissa
; bytes). A two-line attempt to correct this by reducing the loop
; count was validated in isolation but reverted after chain-level
; testing showed it flips the sign of the mantissa on inputs whose
; MSB is close to bit 23 - see the "ATTEMPTS AT A FIX - DO NOT
; REPEAT" subsection of that same header section, and the
; commented-out code fragment below the "clc" in this routine's
; own body. Do not re-enable that fragment without reading both.
; ------------------------------------------------------------
fmul:
    FP_MUL_EXTRA_CLEAR_MACRO
    
    ; Optimise Zero‑operand fast paths for multiplication
    lda FP1_MANT
    ora FP1_MANT+1
    ora FP1_MANT+2
    beq zero_fp1            ; zero result if either factor is zero
    lda FP2_MANT
    ora FP2_MANT+1
    ora FP2_MANT+2
    beq zero_fp1            ; zero result if either factor is zero

    jsr md1                 ; abs value of both mantissas (see
                            ; the DOUBLE-ENTRY TRICK note above)
    php                      ; preserve md1's carry (sec) - the
    pha                      ; ORIGINAL `adc FP1_EXP` below still
                             ; needs A and carry exactly as md1 left
                             ; them; everything between here and the
                             ; matching pla/plp is pure scratch
                             
    FP_NORM_STATE_NORMAL_MACRO
    lda FP1_EXP
    eor #$80                 ; te1, two's complement
    sta boundary_tmp
    lda FP2_EXP
    eor #$80                 ; te2, two's complement
    clc
    adc boundary_tmp          ; A = (te1+te2) mod 256, V = TRUE signed
                              ; overflow of te1+te2 itself - this is
                              ; the only thing that can distinguish
                              ; true_sum=+127 from true_sum=-129 once
                              ; both alias to the same wrapped value
    cmp #127
    bne @classify_done        ; not one of the two straddle points
    bvs @is_floor
    lda #FP_NORM_STATE_CEILING
    sta fp_norm_boundary_state
    jmp @classify_done
@is_floor:
    lda #FP_NORM_STATE_FLOOR
    sta fp_norm_boundary_state
@classify_done:
    pla
    plp

    adc FP1_EXP             ; add exponents for the product exponent
    jsr md2                 ; range-check the exponent, zero FP1's
                            ; mantissa, load Y with the iteration count
    clc

;    ; [REVERTED - 20260912] FMUL LSB loss attempt. DO NOT RE-ENABLE
;    ; WITHOUT SATISFYING BOTH CONDITIONS IN THE HEADER'S "ATTEMPTS
;    ; AT A FIX" SUBSECTION. The unconditional form of this patch
;    ; (ds_diag2) broke the CEILING/FLOOR classify paths (t26/t27).
;    ; The conditional form below (ds_diag3) fixed those but broke
;    ; sign preservation on chained multiplies (ds_diag4):
;    ; FMUL(pi/4, pi/4) should produce $7F,$4E,$F4,$F2 but this
;    ; fragment returns $7E,$9D,$E9,$E5 - sign flipped, not just a
;    ; precision loss. The 23-iteration shortcut is fundamentally
;    ; incompatible with the 2's-complement sign representation
;    ; whenever the true mantissa's MSB is near bit 23. Kept here
;    ; only as a historical reference. See lib_fp.s header section
;    ; "FP_FMUL LSB LOSS ON FULL-MANTISSA MULTIPLIES" for the full
;    ; analysis; ds_diag2.py / ds_diag3.py / ds_diag4.py for the
;    ; experimental derivation.
;    adc FP1_EXP
;    jsr md2
;    lda fp_norm_boundary_state
;    cmp #FP_NORM_STATE_NORMAL
;    bne @md2_patch_done
;    ldy #$16
;    dec FP1_EXP
;@md2_patch_done:
;    clc

mul1:
    jsr rtlog1              ; shift FP1_MANT/FP_EXT right one bit
                            ; (product accumulator and multiplier
                            ; share this one 6-byte shift register)
    bcc mul2                ; multiplier bit was 0: no partial product
    jsr add                 ; multiplier bit was 1: add multiplicand
mul2:
    dey                     ; next multiply iteration
    bpl mul1                ; loop for all 24 bits

; --- PATCH BEGIN ---
    ; [FIX 20260913] Capture the LSB pushed out of the mantissa by
    ; the final loop iteration's rtlog1, now sitting at FP_EXT[0]
    ; bit 7. Saved here, folded back in by norm1 if it needs to
    ; left-shift to normalize. This code sits BETWEEN mul2's loop
    ; exit and mdend, so fdiv's own "jeq mdend" (which lands AT
    ; mdend, past this block) does not execute it - the flag stays
    ; FMUL-only, as intended.
    lda FP_EXT
    and #$80
    sta fp_mul_extra
; --- PATCH END ---

mdend:
    lsr FP_SIGN             ; test running sign (even/odd negations)
normx:
    jcc norm                ; even: normalize product as-is
                            ; odd: fall through and complement
fcompl:
    FP_MUL_EXTRA_CLEAR_MACRO
    sec                     ; set carry for subtract
    ldx #$03                ; index for 3-byte 2's complement
compl1:
    lda #$00
    sbc FP1_EXP,x           ; subtract a byte of FP1's mantissa
    sta FP1_EXP,x           ; ...from zero, restoring it negated
    dex                     ; next more significant byte
    bne compl1              ; loop until done
    jeq addend              ; normalize (or shift right on overflow)

; ------------------------------------------------------------
; fdiv (FP_FDIV) - FP1 = FP2 / FP1 (restoring binary division,
; 23 quotient bits via repeated subtract-and-shift)
; Entry : FP1 = divisor, FP2 = dividend
; Exit  : FP1 = FP2 / FP1, normalized
; Destroys: A, X, Y
; Known limitation: see fmul's own note above - same exponent
; boundary issue applies here (te2-te1 exactly at the format's
; +127/-128 edge).
; ------------------------------------------------------------
fdiv:
    ; Optimise Zero‑operand fast paths for division
    lda FP1_MANT
    ora FP1_MANT+1
    ora FP1_MANT+2
    bne @fdiv_ok

    ; [FIX] reset before this trap, defense in depth - this fires before
    ; ANY classify code runs for this call, so the flag here is already
    ; whatever a PRIOR, unrelated call left it at
    FP_NORM_STATE_NORMAL_MACRO
    lda #FP_ERROR_CODE_DIVISION_BY_ZERO ; error code 1: division by zero
    jmp FP_ERROR

@fdiv_ok:
    ; Optimise Zero‑operand fast paths for division
    lda FP2_MANT
    ora FP2_MANT+1
    ora FP2_MANT+2
    bne @fdiv_normal
    jmp zero_fp1            ; dividend zero -> quotient zero

@fdiv_normal:
    jsr md1                 ; abs value of both mantissas

    php                 ; preserve md1's carry - the ORIGINAL
    pha                 ; `sbc FP1_EXP` below still needs A and carry exactly as md1 left them;
                        ; everything between here and the matching pla/plp is pure scratch

    FP_NORM_STATE_NORMAL_MACRO
    FP_MUL_EXTRA_CLEAR_MACRO

    lda FP1_EXP
    eor #$80            ; te1, two's complement (divisor)
    sta boundary_tmp
    lda FP2_EXP
    eor #$80            ; te2, two's complement (dividend)
    sec
    sbc boundary_tmp    ; A = (te2-te1) mod 256, V = TRUE signed overflow of te2-te1 itself - same
                        ; role as fmul's ADC/V check, just for subtraction: distinguishes true_diff
                        ; =+127 from true_diff=-129 once both alias to the same wrapped value

    ; --- collision 1: $FF ($7F before eor) - true_diff=127(valid
    ;     ceiling) vs true_diff=-129(invalid, one past floor).
    ;     ALREADY VERIFIED WORKING - see diag19-22.py. ---
    cmp #127
    bne @check_80_collision   ; not this collision - check the other
    bvc @div_classify_done    ; V=0: true_diff genuinely IS 127 (the
                              ; valid ceiling) - $FF is never norm1's
                              ; blocked value, ordinary normalization
                              ; already handles this correctly
    ; V=1: true_diff is genuinely -129 - UNCONDITIONALLY invalid.
    ; Force zero immediately, no jsr was used to enter this block so
    ; no extra stack frame needs discarding (see diag21.py's own
    ; confirmed-correct version of this exact sequence).
    pla
    plp
    FP_FP1_ZEROED_MACRO
    rts

    ; --- collision 2: $00 ($80 before eor) - true_diff=-128(valid
    ;     floor) vs true_diff=+128(invalid, one past ceiling).
    ;     NEWLY ADDED - see diag23/24.py and verify_v_flag.py for
    ;     the confirmed derivation, including the V-flag mapping
    ;     being the OPPOSITE of collision 1's and of FMUL's own
    ;     convention - do not "simplify" this to match the other
    ;     branch's V-test direction, it is verified different for a
    ;     real, understood reason (SBC vs ADC, and no +1 pre-
    ;     compensation for FDIV - see the file header). ---
@check_80_collision:
    cmp #$80
    bne @div_classify_done    ; not either collision point - ordinary
                              ; case, flag stays NORMAL
    bvs @div_is_ceiling       ; V=1: true_diff=+128 (invalid ceiling+1)
                              ; - a decrement WOULD rescue this to the
                              ; valid true ceiling (127) - ALLOW it
    lda #FP_NORM_STATE_FLOOR  ; V=0: true_diff=-128 (valid floor) -
    sta fp_norm_boundary_state ; a decrement means the true result is
    jmp @div_classify_done     ; below the real floor - FORCE ZERO
@div_is_ceiling:
    lda #FP_NORM_STATE_CEILING
    sta fp_norm_boundary_state

@div_classify_done:
    pla
    plp

    sbc FP1_EXP             ; subtract exponents for quotient exponent
                            ; (unchanged - A and carry are exactly
                            ; what md1 left them, per the php/pha
                            ; guard above)
    jsr md2                 ; range-check exponent, zero FP1, Y = 23

div1:
    sec                     ; set carry for subtract
    ldx #$02                ; index for 3-byte instruction
div2:
    lda FP2_MANT,x
    sbc FP_EXT,x            ; subtract a byte of FP_EXT (the
                            ; shifted divisor) from the remainder
    pha                     ; save partial difference on stack
    dex                     ; next more significant byte
    bpl div2                ; loop until done
    ldx #$fd                ; index for 3-byte conditional move
div3:
    pla                     ; pull a byte of the difference back
    bcc div4                ; remainder < divisor: don't keep it
    sta FP2_MANT+3,x        ; remainder >= divisor: commit the
                            ; subtraction result
div4:
    inx                     ; next less significant byte
    bne div3                ; loop until done
    rol FP1_MANT+2
    rol FP1_MANT+1          ; roll the quotient left, new
    rol FP1_MANT            ; quotient bit comes in via carry
    asl FP2_MANT+2
    rol FP2_MANT+1          ; shift the remainder (dividend)
    rol FP2_MANT            ; left, ready for the next iteration
    bcc div_ok              ; no overflow: continue normally

    ; [FIX] reset before this trap
    FP_NORM_STATE_NORMAL_MACRO
    lda #FP_ERROR_CODE_GENERIC_OVERFLOW ; [ERROR HANDLING] overflow: the
    jmp FP_ERROR                        ; divisor was not normalized
                                        ; (>= 1.0 assumed) - code 0
div_ok:
    dey                     ; next divide iteration
    bne div1                ; loop for all 23 bits
    jeq mdend               ; normalize quotient, fix sign

; ------------------------------------------------------------
; md2 / md3 / ovchk - shared exponent bookkeeping for
; FP_FMUL and FP_FDIV: range-checks the freshly computed product/
; quotient exponent, zeroes FP1's mantissa ready for the
; multiply/divide loop, and loads Y with the iteration count.
;
; [REVERTED] This is the ORIGINAL logic - see the file header's
; EXPONENT OVERFLOW BOUNDARY note for the known narrow bug this
; still has (trapping some genuinely-valid results exactly at the
; format's +127/-128 combined-exponent edge), the fix that was
; attempted for it, and why that fix was reverted rather than kept.
;
; Entry : A = new exponent (sum for mul, difference for div),
;          carry reflects whether that add/sub overflowed, X = 0
;          (left over from fcompl/swap's loop, reused here to
;          zero 3 bytes without a fresh LDA #0)
; Exit  : FP1_MANT zeroed, FP1_EXP = corrected exponent,
;          Y = $17 (23, shared 24-mul/23-div iteration count),
;          OR an early return to the caller if the result rounds
;          to exactly zero (underflow - see MD3's "clear X1 and
;          return" path)
; ------------------------------------------------------------
md2:
    stx FP1_MANT+2
    stx FP1_MANT+1          ; clear FP1's mantissa (3 bytes) ready
    stx FP1_MANT            ; for the multiply/divide loop (X = 0)
    bcs ovchk               ; exponent add/sub set carry: check overflow
    bmi md3                 ; exponent negative: no underflow, proceed

    ; [FIX] This shortcut assumed "carry clear AND result positive"
    ; ALWAYS means genuine underflow - true for FMUL (whose +1
    ; pre-compensation puts both its CEILING/FLOOR boundary values
    ; at raw $80, always negative, making this path structurally
    ; unreachable for FMUL's boundary cases) but FALSE for FDIV,
    ; which has no such compensation: FDIV's CEILING/FLOOR boundary
    ; values BOTH collapse to raw $7F (positive), and whether carry
    ; ends up set or clear depends on incidental byte-level borrow
    ; behavior in "sbc FP1_EXP", not on which true boundary is
    ; actually intended. Confirmed via diag19.py/diag20.py: a
    ; genuine FDIV FLOOR case (fp_norm_boundary_state=FLOOR) reached
    ; here with carry clear and silently returned canonical zero
    ; WITHOUT ever consulting the classify flag or reaching norm's
    ; own ambiguous-decrement logic - wrong whenever the quotient
    ; mantissa is already normalized and the correct answer is a
    ; valid nonzero result at the true floor, not zero. Deferring
    ; here, exactly like ovchk already does, lets norm's own
    ; FP1_EXP==0 check make the real decision instead of this
    ; shortcut preempting it.
    sta boundary_tmp2         ; preserve A (md3 needs it for its own
                              ; eor #$80) across the flag check below
    lda fp_norm_boundary_state
    beq @genuine_underflow    ; NORMAL: this really is an ordinary
                              ; underflow, proceed exactly as before
    lda boundary_tmp2
    jmp md3                   ; CEILING or FLOOR: defer to norm/norm1,
                              ; same as ovchk already does
@genuine_underflow:
    lda boundary_tmp2

    pla                     ; underflow: pop one return address level
    pla                     ; (unwinds past FP_FMUL/FP_FDIV's own
                            ; call frame - see file note on the
                            ; original's use of this shortcut)
    FP_NORM_STATE_NORMAL_MACRO
    lda #0
    sta FP1_EXP
    rts                     ; return with canonical zero

md3:
    eor #$80                ; complement sign bit of the exponent
    sta FP1_EXP             ; (excess-128 <-> 2's complement)
    ldy #$17                ; 24: iteration count for 24-bit mul or 23-bit div
    rts

ovchk:
    sta boundary_tmp2         ; STA doesn't touch flags - the N flag
                              ; from the bmi test above is still valid
    bpl md3                   ; unchanged: non-negative -> valid
    lda fp_norm_boundary_state
    beq @definite_overflow    ; NORMAL: genuinely unambiguous, trap
                              ; exactly as before
    lda boundary_tmp2         ; CEILING or FLOOR: restore what md3
    jmp md3                   ; needs, and defer the decision to norm
@definite_overflow:
    lda #FP_ERROR_CODE_GENERIC_OVERFLOW
    jmp FP_ERROR


; ------------------------------------------------------------
; fix_shift / fix_conv (FP_FIX) - truncate FP1 to an integer,
; left in FP1_MANT/FP1_MANT+1 (high byte first). Loops by
; repeatedly shifting right one bit (via rtar) until the
; exponent reaches $8E (2^14), matching FP_FLOAT's provisional
; exponent so the two are exact inverses of one another.
; Entry : FP1 loaded with the value to truncate
; Exit  : FP1_MANT = high byte of integer, FP1_MANT+1 = low byte
; Destroys: A
; ------------------------------------------------------------
fix_shift:
    jsr rtar                    ; shift FP1's mantissa right one bit
                                ; and increment the exponent

; [Gemini] suggested fix
; If you pass a float with an exponent greater than $8E
; (meaning the value is larger than 2^14, the maximum for a 16-bit integer),
; fix_conv will shift right and increment the exponent.
; Because the exponent is already above $8E, it will never equal $8E.
; It loops continuously until the exponent wraps past $FF to $00,
; which eventually triggers the overflow trap inside rtlog.
fix_conv:
    lda FP1_EXP
    cmp #$8f                ; Is exponent >= 2^15?
    bcc @check_done         ; If less, proceed normally

    ; [FIX] reset before this trap, purely defensive - see note above
    FP_NORM_STATE_NORMAL_MACRO
    lda #FP_ERROR_CODE_GENERIC_OVERFLOW ; Code 0: generic overflow
    jmp FP_ERROR                        ; Trap immediately
@check_done:
    cmp #$8e                ; Is it 2^14 yet?
    bne fix_shift           ; no: shift again
    rts

; ============================================================
; PATCH 1 of 2: external FP_NORM/FP_NEGATE caller gap (DeepSeek 1.3)
; ============================================================
; Insert these two new labels anywhere inside FP_CORE_PROC (e.g.
; right before the "Map the internal cheap locals..." comment near
; the bottom), and change the two export lines as shown.
;
; WHY A WRAPPER INSTEAD OF EDITING THE 5 EXTERNAL CALL SITES
; -----------------------------------------------------------------
; norm/fcompl are used two ways: as INTERNAL fall-through targets
; (already protected - every internal path reaching them passes
; through an entry point - fadd/fsub/fmul/fdiv/float_conv - that
; resets fp_norm_boundary_state first), and as the EXPORTED
; FP_NORM/FP_NEGATE aliases, called DIRECTLY by lib_fp_ieee754.s,
; lib_fp_basic.s, lib_fp_ceil.s/lib_fp_floor.s, and
; lib_fp_from_uint16.s/from_int24.s/from_uint24.s - none of which
; reset the flag themselves, exposing them to the EXACT same stale-
; flag hazard FADD/FSUB had before that fix (see the EXPONENT
; OVERFLOW BOUNDARY note's FADD/FSUB section above). Redirecting
; only the EXPORT through a thin reset-then-jump wrapper closes this
; for every external caller at once, in one place, rather than
; requiring five separate edits (and five separate chances to miss
; one) in files that don't otherwise need touching. Internal
; fall-through/jsr usage of the bare `norm`/`fcompl` labels is
; UNCHANGED and unaffected - those callers already have their own
; upstream reset.
FP_NORM_ENTRY:
    FP_NORM_STATE_NORMAL_MACRO
    FP_MUL_EXTRA_CLEAR_MACRO
    jmp norm

FP_NEGATE_ENTRY:
    FP_NORM_STATE_NORMAL_MACRO
    FP_MUL_EXTRA_CLEAR_MACRO
    jmp fcompl

; ------------------------------------------------------------
; Map the internal cheap locals to the globally exported symbols.
; The :: prefix forces ca65 to place these in the global namespace.
; ------------------------------------------------------------
::FP_FADD       = fadd
::FP_FSUB       = fsub
::FP_FMUL       = fmul
::FP_FDIV       = fdiv
::FP_FLOAT      = float_conv
::FP_FIX        = fix_conv
::FP_SWAP       = swap

; FP_RTAR: shift FP1's 6-byte mantissa+extension right one bit, incrementing FP1_EXP
::FP_RTAR       = rtar

; FP_NORM: normalize FP1 in place, entry documented by wozfp3.txt as a standalone routine -
; used by lib_fp_doc_convert.txt to float 8-bit and 24-bit integers without going
; through FP_FLOAT's 16-bit-only entry
::FP_NORM       = FP_NORM_ENTRY

; FP_NEGATE: FP1 = -FP1 (2's complement the mantissa, then normalize)
; - also documented as a standalone entry in wozfp3.txt
::FP_NEGATE     = FP_NEGATE_ENTRY

.segment "BSS"
; --- [FIX: exponent boundary] one-shot classification flag, set by
;     fmul/fdiv's classification code immediately before entering
;     md2, consulted only by norm's FP1_EXP==0 ambiguous case, and
;     cleared on EVERY exit from norm (not just when consulted) -
;     that unconditional clear is what makes it safe for FADD/FSUB/
;     FLOAT/standalone FP_NEGATE to share the same norm code without
;     each of them needing their own explicit reset. See lib_fp.s's
;     EXPONENT OVERFLOW BOUNDARY note for the full derivation.
fp_norm_boundary_state: .byte 0
boundary_tmp:           .byte 0
boundary_tmp2:          .byte 0

; [FIX 20260913] One-shot "LSB folded out of FMUL" flag. Set by fmul
; at mdend from FP_EXT[0] bit 7 (the LSB pushed out by the final loop
; shift). Consumed by norm1 on its first entry: OR #$01 into the
; shifted mantissa's LSB if positive, DEC with borrow propagation if
; negative. Cleared by norm1 on consumption, and defensively at every
; arithmetic entry point so a stale flag from a prior FMUL cannot leak
; into a subsequent operation's norm1 path. Derived and validated by
; ds_diag5.py / ds_diag6.py / ds_diag7.py - see the lib_fp.s header
; note added below for the full derivation.
fp_mul_extra:           .byte 0

::FP_NORM_BOUNDARY_STATE    = fp_norm_boundary_state
.endproc
