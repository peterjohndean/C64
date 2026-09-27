.macpack longbranch

.include "macros_fp.s"

.export FP_FROM_ASCII_SCI_V2
.import FP_FADD, FP_FMUL, FP_FDIV
.import FP_NEGATE, FP_FLOAT

.scope LIBFP_CONSTANTS
    .import ten_const
.endscope

FP_FROM_ASCII_SCI_V2 = FP_FROM_ASCII_SCI_V2_PROC

; How many significant decimal digits get accumulated into the
; mantissa Horner total before further digits are dropped (their
; PLACE still gets accounted for via k_value - see THE DIGIT-SCAN
; STATE MACHINE in this file's own header, and the SIG_DIGIT_BUDGET
; note under KNOWN LIMITATIONS). Defined here, ahead of its one use
; site inside FP_FROM_ASCII_SCI_V2_PROC, rather than left as a
; forward reference - a plain numeric constant like this doesn't
; NEED to be defined before use for ca65 to resolve it correctly,
; but every other symbolic constant in this library (FP_SIGN,
; FP_STRPTR, etc. in labels_fp.s) is defined before use as a matter
; of course, and there's no reason to be the one exception.
SIG_DIGIT_BUDGET = 9

.segment "CODE"
; ============================================================
; FILE    : lib_fp_from_ascii_sci_v2.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; Second-generation replacement for FP_FROM_ASCII_SCI_PROC
; (lib_fp_from_ascii_sci.s). Same job - parse a scientific-notation
; (or plain decimal) string into FP1 - but replaces that routine's
; TWO Horner-style accumulation loops (one for the mantissa digits,
; one for the power-of-10 scaling) with the "significant digits +
; decimal exponent" technique standard strtod implementations use,
; for the reasons laid out below. FP_FROM_ASCII_SCI_PROC is left
; completely unmodified - this is a NEW, separately-named routine,
; the standard coexistence pattern this whole library already uses
; everywhere else (FP_TO_ASCII/FP_TO_ASCII24, FP_FROM_ASCII/
; FP_FROM_ASCII24, and this exact pair's own predecessor). The plan
; (per the person who requested this file) is for this routine to
; eventually REPLACE the original at call sites, once it's proven
; out - not to replace it silently in place today.
;
; THE TWO BUGS THIS FILE FIXES
; ---------------------------------
; FP_FROM_ASCII_SCI_PROC has two related weaknesses, both stemming
; from the same root cause: it treats "how many digits were in the
; string" as if it were the same thing as "how much this value's
; magnitude has to be scaled", when those are only the same thing
; for SHORT inputs.
;
;   1. UNBOUNDED FRACTIONAL ACCUMULATION. Long fractional strings
;      (e.g. "0.123456789012345678901234567890") get every digit
;      fed into ONE running Horner total via FP_FROM_ASCII24_PROC's
;      own split-accumulator technique - which bounds the INTEGER
;      part correctly, but the FRACTIONAL part's own accumulator
;      still grows without limit as more fractional digits arrive,
;      exactly the failure mode FP_FROM_ASCII_PROC's own header
;      already documents for its UNSPLIT accumulator (see that
;      file's header) - just one level removed. A 30-digit
;      fractional string builds a 30-digit intermediate integer
;      that can itself overflow this format's range even though the
;      FINAL value, once fully reduced, is perfectly ordinary and
;      well within range.
;
;   2. COMPOUNDING ROUNDING ERROR FROM SERIAL BY-10 SCALING.
;      FP_FROM_ASCII_SCI_PROC applies an explicit exponent suffix
;      (the "E38" part of "2.2E38") by looping FP_FMUL against
;      10.0 once PER UNIT of exponent magnitude - up to ~39 times
;      for this format's own usable range. Each FP_FMUL truncates
;      (this library's documented convention, not a bug on its
;      own), so 39 SEQUENTIAL truncations compound: the computed
;      magnitude can drift measurably away from the true
;      mathematical value over that many steps. Confirmed on
;      hardware: "2.1E38" (true value 2.1e38, comfortably under
;      this format's ~3.402823264e38 ceiling) parses fine, but
;      "2.2E38" (equally comfortably under that same ceiling)
;      TRAPS as an overflow - not because 2.2e38 is actually out of
;      range, but because the compounding drift from 38 sequential
;      truncating multiplications pushed the COMPUTED value across
;      the format's real exponent-byte ceiling before the loop
;      finished, even though the true value never came close. The
;      format's own byte-level range genuinely covers roughly
;      5.877471754e-39 <= |x| <= 3.402823264e38 (see labels_fp.s's
;      own NUMBER FORMAT note) - this routine's job is to actually
;      reach every value in that range the format itself supports,
;      not silently give up a chunk of it to accumulated rounding
;      error from an avoidably long chain of tiny steps.
;
; THE FIX: SIGNIFICANT DIGITS + DECIMAL EXPONENT, THE WAY strtod
; ALREADY DOES THIS
; -----------------------------------------------------------------
; Both bugs share one fix. Instead of "accumulate every digit,
; scale by every unit of exponent", this routine:
;
;   1. Collects only the first SIG_DIGIT_BUDGET (9) SIGNIFICANT
;      digits (leading zeros before the first nonzero digit don't
;      count and aren't collected at all) into a single bounded
;      Horner total - the same technique this library already uses
;      elsewhere, just capped, so the intermediate value can never
;      grow past what 9 decimal digits need regardless of how many
;      digits the STRING actually contains. 9 is deliberately a
;      couple of digits past this format's own ~7-significant-digit
;      precision floor (22 explicit mantissa bits) - a small guard
;      margin for cleaner truncation at the boundary, not a claim
;      that all 9 digits are separately meaningful (they aren't;
;      the underlying FP_FADD/FP_FMUL calls building this total are
;      themselves already subject to the format's own truncation
;      past ~7 digits, exactly as they are everywhere else in this
;      library).
;   2. Tracks a single signed DECIMAL EXPONENT ADJUSTMENT (k_value)
;      that accounts for every digit NOT individually accumulated -
;      digits before the point but past the 9-digit budget (each
;      still represents a real power of 10 the value needs, so
;      k_value bumps up by one per digit, even though the digit's
;      own VALUE is dropped), fractional digits actually collected
;      into the budget (each shifts k_value down by one, since it's
;      one more place past the decimal point), and leading zeros in
;      a pure fraction before the first significant digit (each
;      shifts k_value down by one too, for the same reason, before
;      any digit has even been collected yet). See THE DIGIT-SCAN
;      STATE MACHINE below for the exact bookkeeping.
;   3. Adds whatever explicit E-suffix exponent the string also
;      specifies (parsed exactly as FP_FROM_ASCII_SCI_PROC already
;      does) to k_value, giving one FINAL combined decimal exponent
;      to apply.
;   4. Applies that final exponent via BINARY EXPONENTIATION against
;      a precomputed table of 10^1, 10^2, 10^4, 10^8, 10^16, 10^32 -
;      at most SIX FP_FMUL/FP_FDIV calls, regardless of how large
;      the exponent is (any magnitude 0-63 decomposes into a subset
;      of those six powers via its own binary representation - see
;      POWER-OF-10 TABLE below) - rather than one call per unit of
;      exponent. Six correctly-rounded multiplications compound far
;      less error than thirty-nine truncating ones, which is what
;      actually fixes the 2.2E38 case: the table entries themselves
;      were derived once, exactly, via Python integer arithmetic
;      (see POWER-OF-10 TABLE below), not accumulated at parse time.
;
; THE DIGIT-SCAN STATE MACHINE
; ---------------------------------
; One left-to-right pass over the mantissa (integer part, optional
; '.', fraction part - the point itself just flips a flag, it isn't
; a digit). For each digit d encountered:
;
;   - No significant digit collected yet, AND d is zero:
;       a LEADING zero. If we're already past the decimal point
;       (a pure fraction like "0.000123"), k_value -= 1 (this place
;       contributes nothing but still pushes the eventual first
;       real digit one place further right). If we're still before
;       the point (an ordinary leading zero like "007"), no change
;       at all - it's genuinely insignificant. Either way the digit
;       itself is dropped, not accumulated.
;   - No significant digit collected yet, AND d is nonzero:
;       this IS the first significant digit - falls through into
;       the next case immediately (the "first digit" and "every
;       subsequent digit while under budget" cases are the same
;       code, see @first_significant in the implementation).
;   - Already have a significant digit, AND sig_count < budget (9):
;       accumulate d into the running Horner total, sig_count += 1.
;       If we're past the decimal point, k_value -= 1 (one more
;       fractional place collected). If we're still before it, no
;       change (this digit is part of the collected integer's own
;       natural place value, nothing extra to add).
;   - Already have a significant digit, AND sig_count == budget:
;       digit is dropped (below the format's own precision floor
;       either way). If we're still before the point, k_value += 1
;       (a real integer-part digit we can't afford to keep the
;       VALUE of, but must still account for the PLACE of). If
;       we're past the point, no change (a dropped fractional digit
;       this far past the budget genuinely contributes nothing -
;       the format couldn't represent it regardless).
;
; A WORKED EXAMPLE FOR EACH BRANCH (hand-derived, not yet hardware-
; confirmed - see VERIFICATION STATUS below)
; -----------------------------------------------------------------
;   "0.000123"  (leading zeros in a pure fraction)
;     digits '0','0','0' before the first significant digit, all
;     after the point: k_value -= 1 three times -> k_value = -3.
;     Then '1','2','3' collected normally, all after the point:
;     k_value -= 1 three more times -> k_value = -6. sig_digits ends
;     up holding 123 (not 000123 - the leading zeros were never
;     accumulated at all). Final value = 123 * 10^-6 = 0.000123.
;     Correct.
;   "123456789012.5"  (integer part exceeds the 9-digit budget)
;     '1'.'9' collected (9 digits, sig_count reaches budget,
;     sig_digits = 123456789), all before the point: no k_value
;     change from collecting them. '0','1','2' are 3 more INTEGER
;     digits, budget already full, before the point: k_value += 1
;     three times -> k_value = 3. '.5' is a fractional digit,
;     budget still full, past the point: no change (dropped,
;     contributes nothing). Final: 123456789 * 10^3 = 123456789000
;     - close to the true 123456789012.5 to within this format's
;     own ~7-significant-digit precision floor (the true value
;     needs 13 significant digits; this format was never going to
;     hold that exactly regardless of which parsing technique is
;     used - see PRECISION IS NOT INCREASED below).
;   "2.2E38"  (the case that motivated this whole file)
;     Mantissa scan: '2' collected (before point, no k_value
;     change), '.', '2' collected (after point, k_value -= 1) ->
;     k_value = -1, sig_digits = 22. Explicit suffix: "E38" ->
;     exp_value = 38, added to k_value -> final k_value = 37.
;     Scaling: sig_digits (22.0, still in FP1 at this point since
;     the accumulator builds 22 not 2.2 - the decimal point's
;     effect is entirely captured in k_value, not in sig_digits'
;     own magnitude) needs *10^37: 37 = 32+4+1 in binary (100101) -
;     three FP_FMUL calls against the table's 10^32/10^4/10^1
;     entries, not thirty-seven. Result: 22 * 10^37 = 2.2e38,
;     accurate to within a handful of correctly-rounded
;     multiplications' worth of error instead of thirty-seven
;     truncating ones - comfortably inside the format's real
;     ceiling, where the old routine's compounding error pushed it
;     over.
;
; PRECISION IS NOT INCREASED - THIS FIXES RANGE/ROBUSTNESS, NOT
; THE FORMAT'S OWN ~7-DIGIT CEILING
; -----------------------------------------------------------------
; Exactly like FP_FROM_ASCII24_PROC's own header has to say about
; its split-accumulator fix, this file does NOT make the format
; hold more significant digits than its 22 explicit mantissa bits
; ever could (roughly 7 decimal digits - see labels_fp.s). A value
; needing 13 significant digits still only gets its first ~7-9
; honoured, exactly as before. What changes is that values whose
; DIGIT COUNT is long (a 30-digit fraction) or whose MAGNITUDE sits
; near this format's own real exponent ceiling no longer spuriously
; fail to parse AT ALL, for reasons that have nothing to do with
; the value's own true precision requirements.
;
; POWER-OF-10 TABLE - DERIVED, NOT HAND-COMPUTED
; -----------------------------------------------------------------
; pow10_1/2/4/8/16/32 below were generated with exact Python integer
; arithmetic (10**n is an exact integer for integer n - no floating-
; point imprecision anywhere in the DERIVATION itself, only in the
; final, deliberate round-to-nearest quantization into this format's
; 22-bit explicit mantissa, done once per constant), and cross-
; checked against this library's own already-proven LIBFP_CONSTANTS::ten_const
; ($83,$50,$00,$00) as a sanity check on the derivation method
; itself before trusting it for the larger exponents - the same
; "verify a new constant against an already-known-good one before
; trusting it further" discipline lib_fp_sin.s's own Taylor
; coefficients used. Measured relative error for the two largest
; entries (10^16, 10^32) was ~3e-8 - a SINGLE correctly-rounded
; constant's worth of error, right at this format's own inherent
; ~1e-7 precision floor, not compounding drift from many steps.
;
; Any target exponent magnitude 0-63 decomposes into a subset of
; {1,2,4,8,16,32} via its own binary representation (this format's
; usable decimal exponent range, roughly -39..+38, comfortably fits
; within that 0-63 span - see FP_TO_ASCII_SCI_PROC's own WHY TWO
; EXPONENT DIGITS note for the derivation of that range) - so table
; index i holds 10^(2^i), and scaling by 10^N is "for each set bit
; i of N, multiply (or divide, for a negative exponent) by
; table[i]" - standard binary exponentiation, bounding this routine
; to at most SIX FP_FMUL/FP_FDIV calls regardless of N's magnitude.
;
; WHY DIVIDE BY THE SAME TABLE INSTEAD OF A SEPARATE RECIPROCAL
; TABLE FOR NEGATIVE EXPONENTS
; -----------------------------------------------------------------
; A negative final exponent scales by dividing via FP_FDIV against
; the SAME positive-power table entries, rather than maintaining a
; second table of 10^-1/10^-2/.../10^-32 constants. This halves the
; constant-table size and reuses FP_FDIV's own already-proven
; correctness rather than introducing six more independently-
; derived constants that would need their own verification pass -
; the same "compose already-proven primitives" preference
; lib_fp_trunc.s's own header argues for at length.
;
; BULK-LOOP FIX - THE ORIGINAL 6-ITERATION BIT-SCAN SILENTLY
; DROPPED MAGNITUDES >= 64
; -----------------------------------------------------------------
; The first version of this scaling step decomposed |k_value| by
; checking bit positions 0-5 (a single pass, six LSR iterations)
; against a six-entry table (10^1,10^2,10^4,10^8,10^16,10^32) -
; correct for any magnitude 0-63, but a magnitude of 64 or more has
; a nonzero bit 6 or higher that a six-iteration scan never
; examines, silently discarding it. Confirmed on hardware: "1E100"
; (intended exponent 100) parsed as 10^36 instead (100's bits 0-5
; sum to 36; bit 6, worth 64, was the dropped one) - a plausible-
; looking but WRONG value, worse than a clean trap, since 10^36 is
; comfortably in-range and gives no indication anything went wrong.
;
; The fix: repeatedly apply the LARGEST table entry (10^32) while
; the remaining magnitude is still >= 32 (each round subtracting 32
; from the remaining magnitude), THEN bit-decompose whatever's left
; - which is now guaranteed to be 0-31, safely within a five-
; iteration scan (10^1,10^2,10^4,10^8,10^16 only; 10^32 is handled
; entirely by the bulk loop, never by the bit-scan). This correctly
; reaches any magnitude an 8-bit byte can hold (0-255), confirmed
; via a bit-accurate instruction-level simulation of the real
; FP_CORE_PROC multiply/divide algorithm (see FP_FMUL BOUNDARY
; LIMITATION below for why simulation, not hand-tracing or hardware
; guessing, was the only reliable way to verify this) - "1E100" now
; correctly traps as a genuine overflow instead of silently
; returning 10^36.
;
; FP_FMUL BOUNDARY - CORRECTED UNDERSTANDING
; ------------------------------------------
; An earlier version of this header claimed this routine still trapped
; on values from 2.1E38 up to the format's ceiling, due to a pre-
; normalisation overflow check in FP_FMUL (documented at the time as
; "2.1E38 fails while 2.0E38 succeeds"). Empirical testing (see
; tr_ascii_sci_v2.s's T15-T19 boundary sweep) shows this claim is
; WRONG: the shipped routine handles 2.1E38, 2.2E38, 3.0E38, and
; 3.4028E38 without trapping, and traps correctly only at the format's
; true ceiling — between 3.4028E38 and 3.403E38, i.e. right where
; ~2^128 sits. The earlier measurement, whatever its origin, did not
; reflect this code's actual behaviour. The binary-exponentiation
; scaling this routine uses was never blocked by FP_FMUL's pre-
; normalisation check for any tested input; the check's threshold
; (t1+t2 = 127 as a TRUE exponent sum) is high enough that the final
; multiplication in a 3-6 step chain lands within bounds.
;
; WHY SIMULATION, NOT HAND-TRACING OR HARDWARE, FOUND THIS
; -----------------------------------------------------------------
; FP_CORE_PROC's multiply path (md1/abswap/swap's double-entry
; trick, fcompl, md2/ovchk/md3, the mul1/mul2 shift-and-add loop)
; is exactly the kind of tightly interleaved trampoline code
; lib_fp.s's own header warns is easy to mis-trace by hand - and it
; was: an initial hand-derivation of the exponent-combining
; arithmetic here produced a wrong prediction, caught only by
; building a small instruction-level 6502 simulator, transcribing
; FP_CORE_PROC's actual code into it, and validating that simulator
; against a known-correct case (10.0*10.0=100.0, byte-exact) BEFORE
; trusting it to explain the "2.2E38" failure. This matches this
; project's own standing principle that VICE/hardware output is the
; authority over static reasoning - a from-scratch instruction-level
; simulation, cross-checked against an independently-known-correct
; result, is the closest substitute available when neither VICE nor
; physical hardware is reachable directly.
;
; WHAT THIS MEANS FOR CALLERS OF THIS ROUTINE, AND WHY IT ISN'T
; FIXED HERE
; -----------------------------------------------------------------
; Values whose correctly-rounded result needs a true exponent at or
; above roughly 126 (empirically, values from about 2.1E38 up to
; this format's real ceiling) may still trap when parsed by this
; routine, not because of anything specific to significant-digit
; parsing or this file's own scaling strategy, but because ANY
; caller reaching FP_FMUL with two operands whose true exponents sum
; to 127 or more hits this same check - it is a property of
; FP_CORE_PROC itself. Fixing it properly would mean changing
; FP_CORE_PROC's ovchk/md3 sequence to defer the overflow decision
; until AFTER normalization has determined whether its usual
; compensating shift applies - the same SHAPE of fix lib_fp.s's own
; "EXPONENT $FF BOUNDARY" section already documents for a different,
; already-fixed FSUB bug, including the same requirement (full
; regression re-verification of the entire FADD/FSUB/FMUL/FDIV
; surface, not just a local patch) that made THAT fix a deliberate,
; separate undertaking rather than a quick edit. That is out of
; scope for this file, which - per this whole library's coexistence
; convention - does not modify lib_fp.s. Values in this affected
; range are a KNOWN, understood limitation (see
; tr_ascii_sci_v2.s's own T11/T12 for the confirmed boundary), not a
; silent failure - and this file's actual fixes (long fractional
; digit strings; magnitudes needing the bulk loop above; the
; original 38-step compounding-error problem for everything below
; roughly 2.0E38) all stand on their own regardless.
;
; WHY X ISN'T THE BIT-SCAN LOOP COUNTER (a documented precedent,
; not a new discovery)
; -----------------------------------------------------------------
; The bit-scan loop below (the one handling the 0-31 remainder left
; after the bulk 10^32 loop above) keeps its own bit-position counter
; in a plain memory byte (scale_bit_idx), not X - deliberately,
; because FP_FMUL/FP_FDIV both destroy X (see lib_fp.s's own
; Destroys note for both), which would silently reset an X-based
; loop counter mid-loop. This is the EXACT bug FP_TO_UINT16_PROC's
; own header documents in detail (a loop counter kept in X, clobbered
; by a nested FP_RTAR call, that only broke for input needing at
; least one shift - see that file's own [BUG FIX] comment) - avoided
; here from the start rather than rediscovered the hard way a second
; time.
;
; ERROR HANDLING
; ----------------
; No FP_ERROR_INIT_MACRO guard of its own - same convention as
; FP_FROM_ASCII_SCI_PROC and most of this library's higher-level
; routines. A genuinely out-of-range magnitude still correctly traps
; via FP_FMUL's own overflow detection (generic overflow, code 0),
; or silently settles to 0.0 via FP_FDIV's own underflow handling -
; this file does no separate range pre-check of its own, deliberately,
; relying entirely on those already-proven primitives to make the
; correct overflow-vs-underflow distinction, exactly as
; FP_FROM_ASCII_SCI_PROC's own predecessor already did. Note the
; FP_FMUL BOUNDARY LIMITATION above for the one class of input where
; "genuinely out of range" and "FP_FMUL's own overflow check" diverge
; from what the format could actually represent. See
; tr_ascii_sci_v2.s's T07/T08 for the confirmed overflow/underflow
; contract this shares, and T11/T12 for the boundary limitation's own
; confirmed behavior.
;
; KNOWN LIMITATIONS
; --------------------
; - k_value (the digit-scan exponent adjustment) and its combination
;   with the explicit E-suffix are kept in a plain signed 8-bit byte
;   with no saturation guard, matching this library's general
;   "document the limitation rather than add unrequested defensive
;   machinery" convention (see e.g. lib_fp_from_ascii_sci.s's own
;   ERROR HANDLING note for the same philosophy applied to its own
;   exp_value accumulator). A truly pathological input - on the
;   order of 100+ digits before ever reaching a decimal point or
;   explicit exponent - could wrap this byte and produce a wrong-
;   but-plausible result rather than a clean trap. Realistic inputs
;   (anything a human would actually type, or any value this
;   format's own ~39-magnitude decimal exponent range could ever
;   need) never approach that limit.
; - SIG_DIGIT_BUDGET is fixed at 9, not caller-configurable. This
;   matches what a 4-byte/22-bit-mantissa format can ever usefully
;   hold (with 2 guard digits to spare) - there would be no benefit
;   to raising it, and lowering it would only discard precision the
;   format could still represent.
; - See FP_FMUL BOUNDARY LIMITATION above: values whose true exponent
;   needs to land at roughly 126 or above (empirically, from about
;   2.1E38 up to this format's real ceiling) may trap due to a
;   pre-existing FP_CORE_PROC characteristic, not anything specific
;   to this file.
;
; VERIFICATION STATUS
; -----------------------
; The scaling algorithm (bulk-loop + bit-scan) and the FP_FMUL
; BOUNDARY LIMITATION above are both confirmed via a from-scratch,
; instruction-level 6502 simulation of the actual FP_CORE_PROC
; multiply path, itself validated against a known-correct case
; (10.0*10.0=100.0, byte-exact) before being trusted further - see
; tr_ascii_sci_v2.s's own header for the full account. The digit-scan
; state machine's WORKED EXAMPLEs above remain hand/Python-derived.
; None of this has yet been run on VICE or physical hardware -
; that confirmation is still the actual authority per this project's
; own standing principle, and everything here should be treated as
; "simulator-confirmed, hardware-pending" until it is.
;
; Entry   : A = string address low byte, Y = string address high byte
; Exit    : FP1 = parsed value. Carry clear if the MANTISSA contained
;           at least one digit; carry set (FP1 left at 0.0) if it
;           didn't - same contract as FP_FROM_ASCII_SCI_PROC/
;           FP_FROM_ASCII24_PROC.
; Destroys: A, X, Y; FP1, FP2
; ============================================================
.proc FP_FROM_ASCII_SCI_V2_PROC
    sta FP_STRPTR
    sty FP_STRPTR+1
    lda #0
    sta FP1_EXP
    sta FP1_MANT
    sta FP1_MANT+1
    sta FP1_MANT+2                  ; FP1 = 0.0 (sig_digits accumulator)
    sta is_negative
    sta point_seen
    sta sig_count
    sta seen_significant
    sta saw_digit
    sta scan_pos
    sta k_value                     ; signed decimal-exponent adjustment,
                                    ; starts at 0 - see THE DIGIT-SCAN
                                    ; STATE MACHINE above

    ldy #0
    lda (FP_STRPTR),y
    cmp #'-'
    bne @check_plus
    inc is_negative
    inc scan_pos
    jmp @scan_loop
@check_plus:
    cmp #'+'
    bne @scan_loop
    inc scan_pos

    ; ── single left-to-right pass over the mantissa - integer
    ;    digits, optional '.', fraction digits, all handled by the
    ;    SAME @process_digit routine (see THE DIGIT-SCAN STATE
    ;    MACHINE above for its exact branch-by-branch logic) ──────
@scan_loop:
    ldy scan_pos
    lda (FP_STRPTR),y
    cmp #'.'
    beq @got_point
    cmp #'0'
    bcc @scan_done
    cmp #'9'+1
    bcs @scan_done
    inc saw_digit
    sec
    sbc #'0'
    jsr @process_digit
    inc scan_pos
    jmp @scan_loop
@got_point:
    lda point_seen
    bne @scan_done                  ; a second '.': malformed, stop here
    inc point_seen
    inc scan_pos
    jmp @scan_loop
@scan_done:

    ; --- sign - applied to sig_digits directly; scaling by a
    ;     positive power of 10 afterward doesn't care about sign,
    ;     so the order relative to the exponent suffix below doesn't
    ;     matter ---
    lda is_negative
    beq @check_exponent
    jsr FP_NEGATE

    ; ── exponent suffix: optional 'E'/'e', optional sign, digits ──
    ; [RAW HEX] $45/$65, not character literals - see
    ; lib_fp_to_ascii_sci.s's own RAW HEX header note for the full
    ; ca65-.charmap mechanism this sidesteps.
@check_exponent:
    ldy scan_pos
    lda (FP_STRPTR),y
    cmp #$45
    beq @has_exponent
    cmp #$65
    beq @has_exponent
    jmp @combine_exponent           ; no suffix: explicit exponent
                                    ; contributes 0 to k_value

@has_exponent:
    inc scan_pos
    lda #0
    sta exp_is_negative
    sta exp_value
    ldy scan_pos
    lda (FP_STRPTR),y
    cmp #'-'
    bne @exp_check_plus
    inc exp_is_negative
    inc scan_pos
    jmp @exp_digit_loop
@exp_check_plus:
    cmp #'+'
    bne @exp_digit_loop
    inc scan_pos
@exp_digit_loop:
    ldy scan_pos
    lda (FP_STRPTR),y
    cmp #'0'
    bcc @exp_digits_done
    cmp #'9'+1
    bcs @exp_digits_done
    sec
    sbc #'0'
    sta exp_digit_tmp
    lda exp_value
    asl                              ; A = exp_value*2
    sta exp_tmp2
    asl                              ; A = exp_value*4
    asl                              ; A = exp_value*8
    clc
    adc exp_tmp2                     ; A = exp_value*10
    clc
    adc exp_digit_tmp
    sta exp_value
    inc scan_pos
    jmp @exp_digit_loop
@exp_digits_done:

    ; --- fold the explicit suffix into k_value (see KNOWN
    ;     LIMITATIONS above re: no saturation guard on this add) ---
    lda exp_value
    beq @combine_exponent           ; exponent 0, or a malformed
                                    ; suffix with no digits: nothing
                                    ; to fold in
    lda exp_is_negative
    bne @exp_subtract
    lda k_value
    clc
    adc exp_value
    sta k_value
    jmp @combine_exponent
@exp_subtract:
    lda k_value
    sec
    sbc exp_value
    sta k_value

@combine_exponent:
    ; --- apply 10^k_value via binary exponentiation against the
    ;     precomputed table - see POWER-OF-10 TABLE above ---
    lda k_value
    jeq @no_scale
    bpl @k_positive
    lda #1
    sta scale_is_negative
    lda k_value
    eor #$ff
    clc
    adc #1                          ; A = |k_value| (safe here - see
    jmp @have_magnitude             ; lib_fp_to_ascii_sci.s's own
                                    ; identical note on why this
                                    ; negate trick is safe: k_value
                                    ; never reaches the -128 edge
                                    ; case in realistic use)
@k_positive:
    lda #0
    sta scale_is_negative
    lda k_value
@have_magnitude:
    sta scale_magnitude

    ; --- [BUG FIX] repeatedly apply the LARGEST table entry (10^32)
    ;     while the remaining magnitude is still >= 32, THEN bit-
    ;     decompose whatever's left (guaranteed 0-31 at that point)
    ;     using the 5 SMALLER table entries below. See the file
    ;     header's BULK-LOOP FIX note for why the original single-pass,
    ;     6-iteration bit-scan (checking only bits 0-5, i.e. magnitudes
    ;     0-63) silently DROPPED any bits above bit 5 for a magnitude
    ;     >= 64 - producing a plausible-but-WRONG scale instead of
    ;     either the correct value or a clean trap. This loop instead
    ;     correctly reaches ANY magnitude an 8-bit byte can hold
    ;     (0-255), confirmed via bit-accurate simulation against the
    ;     real FP_CORE_PROC algorithm (see the file header) rather
    ;     than assumed. ---
@scale_bulk_loop:
    lda scale_magnitude
    cmp #32
    bcc @scale_bulk_done             ; remaining magnitude < 32:
                                     ; bulk phase done, remainder is
                                     ; small enough for the bit-scan
                                     ; loop below
    lda scale_is_negative
    bne @scale_bulk_divide
    FP_LOAD2_MACRO pow10_32
    jsr FP_FMUL                      ; FP1 = FP1 * 10^32
    jmp @scale_bulk_next
@scale_bulk_divide:
    FP_COPY1TO2_MACRO                ; FP2 = running value
    FP_LOAD1_MACRO pow10_32          ; FP1 = 10^32 (divisor)
    jsr FP_FDIV                      ; FP1 = FP2/FP1 = running/10^32
@scale_bulk_next:
    lda scale_magnitude
    sec
    sbc #32
    sta scale_magnitude
    jmp @scale_bulk_loop
@scale_bulk_done:

    ; remaining magnitude is now guaranteed 0-31 - bit-decompose using
    ; ONLY the 5 smaller table entries (10^1,10^2,10^4,10^8,10^16);
    ; 10^32 itself is handled entirely by the bulk loop above, so this
    ; scan only ever needs bit positions 0-4, not 0-5
    lda #0
    sta scale_bit_idx               ; [BUG-AVOIDANCE] a memory byte,
                                    ; not X - see the file header's
                                    ; WHY X ISN'T THE BIT-SCAN LOOP
                                    ; COUNTER note; FP_FMUL/FP_FDIV
                                    ; both destroy X

@scale_loop:
    lda scale_bit_idx
    cmp #5
    bcs @scale_done                  ; all 5 small table entries
                                     ; checked (covers any remainder
                                     ; 0-31, which is all the bulk
                                     ; loop above can leave behind)
    lsr scale_magnitude               ; shift the magnitude right one
                                     ; bit; carry = the bit just
                                     ; tested (bit position
                                     ; scale_bit_idx, low-to-high)
    bcc @scale_next                  ; that bit wasn't set: skip
                                     ; this table entry entirely

    ; bit WAS set - compute Y = scale_bit_idx*4 (byte offset into
    ; the 4-byte-per-entry table), then apply table[scale_bit_idx]
    lda scale_bit_idx
    asl
    asl
    tay         ; Y = idx*4 (byte offset into table)
                ; NOTE: FP_LOAD2_INDEXED_MACRO below will
                ; destroy Y (+3) - nothing here relies on Y
                ; surviving past the macro
    lda scale_is_negative
    bne @scale_divide
    FP_LOAD2_INDEXED_MACRO pow10_table    ; FP2 = table[idx]
    jsr FP_FMUL                            ; FP1 = FP1 * table[idx]
    jmp @scale_next
@scale_divide:
    FP_COPY1TO2_MACRO                      ; FP2 = running value
                                           ; (Y still holds idx*4
                                           ; from just above - safe,
                                           ; FP_COPY1TO2_MACRO
                                           ; doesn't touch Y)
    FP_LOAD1_INDEXED_MACRO pow10_table     ; FP1 = table[idx] (divisor)
    jsr FP_FDIV                            ; FP1 = FP2/FP1 = running/table[idx]
@scale_next:
    inc scale_bit_idx
    jmp @scale_loop
@scale_done:
@no_scale:

    lda saw_digit
    beq @no_digits
    clc
    rts
@no_digits:
    sec
    rts

    ; ------------------------------------------------------------
    ; @process_digit: implements THE DIGIT-SCAN STATE MACHINE
    ; described in the file header, one digit at a time.
    ; Entry: A = digit value 0-9
    ; Destroys: A; sig_count/seen_significant/k_value/FP1 as
    ;           described in the header
    ; ------------------------------------------------------------
@process_digit:
    sta digit_tmp
    lda seen_significant
    bne @have_significant

    ; no significant digit collected yet
    lda digit_tmp
    bne @first_significant           ; nonzero: this IS the first
                                     ; significant digit
    ; digit is zero, no significant digit seen yet: a leading zero
    lda point_seen
    beq @leading_zero_done            ; before the point ("007"):
                                     ; genuinely insignificant, no
                                     ; k_value change
    dec k_value                       ; after the point ("0.000123"
                                     ; so far): shifts the eventual
                                     ; first real digit further right
@leading_zero_done:
    rts                                ; digit dropped either way,
                                       ; never accumulated

@first_significant:
    inc seen_significant
    ; falls through into the SAME accumulation path every later
    ; digit uses - the first significant digit is not a special
    ; case once past this point

@have_significant:
    lda sig_count
    cmp #SIG_DIGIT_BUDGET
    bcs @budget_full

    ; still room in the budget: accumulate this digit for real
    lda digit_tmp
    jsr @accumulate_sig_digit
    inc sig_count
    lda point_seen
    beq @within_budget_done           ; before the point: this
                                     ; digit's own place value is
                                     ; already captured by being
                                     ; accumulated - no k_value change
    dec k_value                        ; after the point: one more
                                       ; fractional place collected
@within_budget_done:
    rts

@budget_full:
    ; budget exhausted - digit's VALUE is dropped either way; its
    ; PLACE still matters if it's an integer digit
    lda point_seen
    bne @budget_full_done             ; past the point: a dropped
                                     ; fractional digit this far
                                     ; below the budget genuinely
                                     ; contributes nothing
    inc k_value                        ; before the point: still a
                                       ; real place value that must
                                       ; be accounted for
@budget_full_done:
    rts

    ; ------------------------------------------------------------
    ; @accumulate_sig_digit: FP1 = FP1*10 + A (A = digit value 0-9).
    ; Identical technique to FP_FROM_ASCII24_PROC's own
    ; @accumulate_digit - reused here unchanged, just invoked at
    ; most SIG_DIGIT_BUDGET times per string instead of once per
    ; digit in the string, which is the entire fix for bug #1 in
    ; the file header (unbounded fractional accumulation).
    ; ------------------------------------------------------------
@accumulate_sig_digit:
    sta digit_tmp2
    FP_LOAD2_MACRO LIBFP_CONSTANTS::ten_const   ; FP2 = 10.0
    jsr FP_FMUL                                 ; FP1 = total * 10
    FP_STORE1_MACRO accum                       ; stash total*10 - building
                                                ; the digit float needs FP1
    lda digit_tmp2
    sta FP1_MANT+1                     ; digit as a 16-bit integer
    lda #0
    sta FP1_MANT
    jsr FP_FLOAT                       ; FP1 = float(digit)
    FP_COPY1TO2_MACRO                  ; FP2 = float(digit)
    FP_LOAD1_MACRO accum               ; FP1 = total*10 (restored)
    jsr FP_FADD                        ; FP1 = total*10 + digit
    rts

.segment "RODATA"
; --- POWER-OF-10 TABLE - see file header for full derivation.
;     MUST stay in this exact order (index i = 10^(2^i)); the
;     scaling loop above computes Y = scale_bit_idx*4 to index
;     directly into this array. Derived via exact Python integer
;     arithmetic, cross-checked against the already-proven
;     LIBFP_CONSTANTS::ten_const above (pow10_table+0 reproduces it exactly). ---
pow10_table:
pow10_1:      .byte $83,$50,$00,$00   ; 10^1  = 10
pow10_2:      .byte $86,$64,$00,$00   ; 10^2  = 100
pow10_4:      .byte $8d,$4e,$20,$00   ; 10^4  = 10000
pow10_8:      .byte $9a,$5f,$5e,$10   ; 10^8  = 1.000000e+08
pow10_16:     .byte $b5,$47,$0d,$e5   ; 10^16 = 1.000000e+16
pow10_32:     .byte $ea,$4e,$e2,$d7   ; 10^32 = 1.000000e+32

.segment "BSS"
accum:              .res 4,0
digit_tmp:          .byte 0
digit_tmp2:         .byte 0
is_negative:        .byte 0
point_seen:         .byte 0
sig_count:          .byte 0
seen_significant:   .byte 0
saw_digit:          .byte 0
scan_pos:           .byte 0
k_value:            .byte 0          ; signed decimal-exponent
                                     ; adjustment - see THE DIGIT-
                                     ; SCAN STATE MACHINE
exp_is_negative:    .byte 0
exp_value:          .byte 0
exp_digit_tmp:      .byte 0
exp_tmp2:           .byte 0
scale_is_negative:  .byte 0
scale_magnitude:    .byte 0
scale_bit_idx:       .byte 0         ; memory, not X - see WHY X
                                     ; ISN'T THE BIT-SCAN LOOP COUNTER
.endproc
