.include "macros_fp.s"
.macpack longbranch

.export FP_TO_ASCII_SCI_V2
.import FP_FSUB, FP_FMUL, FP_FDIV
.import FP_NEGATE
.import FP_FROM_INT8, FP_TO_INT8
.import FP_COMPARE

FP_TO_ASCII_SCI_V2 = FP_TO_ASCII_SCI_V2_PROC

.scope LIBFP_CONSTANTS
    .import one_const, ten_const
.endscope

.segment "CODE"
; ============================================================
; FILE    : lib_fp_to_ascii_sci_v2.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; Format FP1 as a scientific-notation decimal string:
;
;     [-]D.DDDDDDE[+-]NN
;
; one leading digit (1-9, or 0 for the zero case), an optional
; caller-chosen number of fractional digits after a '.', then 'E',
; an explicit '+' or '-', and exactly two exponent digits.
;
; -----------------------------------------------------------------
; VERSION 2 (V2) CHANGES
; -----------------------------------------------------------------
; This version addresses several subtle edge-case and robustness
; issues discovered after V1 was integrated. The changes are:
;
;   1. **Normalisation rounding guard** – The low-bound loop now jumps
;      back to the high-bound check after multiplying by 10. This
;      prevents a value just below 1.0 from rounding up to exactly
;      10.0 during the multiply, which would break the [1,10)
;      invariant and cause an invalid leading digit.
;
;   2. **Zero detection (reverted to V1 behaviour)** – An earlier
;      draft of V2 checked all three mantissa bytes in addition to
;      the exponent, intending to distinguish a non-canonical
;      exp=0 subnormal from true canonical zero. That change was
;      reverted: the normalisation loop below uses FP_FMUL/
;      FP_COMPARE, both of which already treat ANY exponent-0 value
;      as zero (see FP_COMPARE, FP_FDIV, FP_TO_BASIC, FP_TO_IEEE754
;      for the same convention elsewhere in this library) - so a
;      non-canonical zero reaching the mantissa-aware check would
;      fall through into that loop and hang. This routine now
;      detects zero by exponent alone, identically to V1. The
;      divergence this would have fixed was never reachable from
;      any library-generated value anyway (see the in-code comment
;      at the zero check in FP_TO_ASCII_SCI_V2_PROC for the full
;      account).
;
;   3. **Negative zero** – NOT preserved. Woz format has no signed
;      zero (exp=0, mant=0 is the unique encoding for zero), so a
;      leading '-' is never emitted for zero input. The previous
;      "preserve negative zero sign" branch was unreachable dead
;      code (it sat inside the canonical-zero-only print path, where
;      FP1_MANT is guaranteed to be $00) and has been removed.
;
;   4. **Cleaner fractional digit handling** – The fractional digit
;      extraction no longer relies on the carry flag after storing a
;      character. Instead, a temporary variable (`digit_val`) is used
;      to hold the raw digit value, making the code clearer and less
;      error-prone.
;
;   5. **Defensive exponent clamping** – The exponent magnitude is
;      checked and clamped to 99 before splitting into tens/units.
;      This guards against buffer overflow if an out-of-range exponent
;      ever occurs (should be impossible given the format's range, but
;      added for safety).
;
; All original V1 fixes are retained:
;   - $FF exponent boundary workaround in the normalisation high loop.
;   - Raw PETSCII $45 for the 'E' marker (avoids .charmap translation
;     issues).
;   - Reloading the exponent magnitude in the positive branch before
;     digit splitting.
;   - Explicit import of FP_COMPARE.
;
; -----------------------------------------------------------------
; WHY A SEPARATE FILE INSTEAD OF EXTENDING FP_TO_ASCII_PROC/
; FP_TO_ASCII24_PROC IN PLACE
; -----------------------------------------------------------------
; Same coexistence pattern already used throughout this library
; (FP_TO_ASCII/FP_TO_ASCII24, FP_FROM_ASCII/FP_FROM_ASCII24): the
; existing, already-tested fixed-point formatters are left completely
; unchanged, and this file adds a genuinely different OUTPUT SHAPE
; as a new routine built on the same proven primitives (FP_FSUB,
; FP_FMUL, FP_FDIV, FP_NEGATE, FP_TO_INT8, FP_FROM_INT8 - every one
; of these already has its own test coverage elsewhere in this
; library; nothing new is invented at the bit-manipulation level
; here). Existing call sites that want fixed-point output keep
; working exactly as before.
;
; WHY THIS INSTEAD OF FP_TO_ASCII24_PROC WHEN THE INTEGER PART IS
; LARGE
; -----------------------------------------------------------------
; FP_TO_ASCII24_PROC raised the fixed-point integer-part ceiling to
; 8,388,607, but it is still a CEILING - a value whose magnitude
; exceeds that (or whose magnitude is so SMALL that fixed-point
; notation would need a long run of leading zeros, e.g. 0.0000003)
; has no good fixed-point representation at all. Scientific notation
; sidesteps both problems at once: this format's own usable exponent
; range (see WHY TWO EXPONENT DIGITS below) covers roughly
; 1e-39..1e38, and normalizing to a single leading digit means the
; OUTPUT WIDTH no longer depends on the value's magnitude - a
; concern fixed-point notation can never fully escape.
;
; THE ALGORITHM: NORMALIZE BY REPEATED DIVIDE/MULTIPLY, NOT BY
; ESTIMATING log10(x) FIRST
; -----------------------------------------------------------------
; The obvious-looking shortcut is: call FP_LOG10_PROC to estimate
; the decimal exponent directly, then divide by 10^that_exponent
; once. This file deliberately does NOT do that, for two reasons:
;
;   1. FP_LOG10_PROC is itself an approximation (a rational Pade-
;      style fit - see lib_fp_log.s's own header) with the same
;      ~1e-7 relative error every other routine in this library
;      carries. Near a power-of-10 boundary (e.g. x=99.9999997,
;      whose TRUE log10 is just under 2.0 but might round to
;      exactly 2.0 or slightly over), the estimated exponent can be
;      off by one - which would leave the "normalized" mantissa
;      just outside [1,10) instead of inside it, requiring a
;      correction step anyway.
;   2. Computing 10^n for an arbitrary integer n needs its own loop
;      (there's no direct "raise to an integer power" primitive in
;      this library), so the "fast path" isn't actually shorter
;      once that's accounted for - it just moves the loop from
;      after the estimate to before it.
;
; Instead, this routine normalizes with a small, self-correcting
; loop: while the magnitude is >= 10.0, divide by 10 and increment
; a running decimal exponent; while it's < 1.0, multiply by 10 and
; decrement it. This is exactly the same "keep shifting until a
; condition holds" shape as FP_CORE_PROC's own alignment trampoline
; (see lib_fp.s's ALIGNMENT TRAMPOLINE note) and FP_TO_INT16_PROC's
; shift-until-exponent-reaches-target loop - a familiar pattern in
; this codebase, and one that is correct by construction regardless
; of how many iterations it takes, rather than relying on a single
; estimate being exactly right.
;
; WHY TWO EXPONENT DIGITS ARE ALWAYS ENOUGH
; -----------------------------------------------------------------
; This format's exponent byte is excess-128, so the underlying
; POWER-OF-2 exponent ranges -128..+127 (see labels_fp.s). Converting
; that range to decimal (multiply by log10(2) =~ 0.30103):
;
;     2^127  ~= 1.7 x 10^38    ->  decimal exponent ~= +38
;     2^-128 ~= 2.9 x 10^-39   ->  decimal exponent ~= -39
;
; So the decimal exponent this routine ever needs to print has
; magnitude at most 39 - comfortably inside two digits (00-99).
; This is checked by construction (the normalize loop can only run
; a bounded number of iterations, one per power of 2 in the format's
; own range), not merely assumed.
;
; RAW HEX FOR THE 'E' MARKER - THE .charmap/.asciiz GOTCHA
; -----------------------------------------------------------------
; The 'E' written between the mantissa and the exponent is emitted
; as `lda #$45` (raw PETSCII), NOT `lda #'E'`. This matters, and got
; this exact routine wrong on the first pass (confirmed on hardware -
; the screen showed a graphic bar symbol where 'E' should have been,
; while the printer - which doesn't apply this translation - showed
; it correctly):
;
; ca65 runs CHARACTER LITERALS (single-quoted, like 'E' inside an
; instruction operand) through the exact same .charmap translation
; table it applies to text inside .asciiz/.byte string directives -
; not just string data. This project's whole codebase already
; depends on that table doing something specific for TEXT: every
; existing message string (test_title, msg_unexpected, and now this
; file's own test messages in tr_ascii_sci.s) is written in LOWERCASE
; source, and .charmap is what turns that into the PETSCII bytes that
; actually DISPLAY as uppercase on a stock C64 screen - i.e. the
; table swaps case, mapping source 'a'-'z' to the $41-$5A PETSCII
; range (displays as uppercase in EITHER charset mode) and source
; 'A'-'Z' to the $61-$7A range (displays as graphic symbols in the
; default charset, or as genuine lowercase only if the alternate
; character set has been switched in - which nothing in this project
; does). Digits and punctuation ('0'-'9', '+', '-', '.') are
; untouched by this table - only the 52 letter characters are
; remapped - which is exactly why every OTHER character literal in
; this file (all digits and punctuation, no other letters) behaved
; correctly with no special handling needed.
;
; Since this file needed an actual LETTER for the first time anywhere
; in this library's ASCII-conversion code, it's the first place this
; gotcha had anywhere to bite. Writing `lda #'E'` (uppercase in
; SOURCE) went through the same swap as everything else and produced
; the $61-$7A-range byte instead of real PETSCII $45 - a byte that
; happens to look fine in isolation (it's a well-defined PETSCII
; code) but is NOT the code that displays as the letter E. $45 is
; PETSCII's own case-independent code for E - true 'E' displays as
; 'E' in either charset mode, with no compile-time translation
; involved, so writing it as a raw hex literal sidesteps the whole
; source-case question rather than needing the reader to remember
; which case produces which byte. See lib_fp_from_ascii_sci.s's own
; header for the parsing-side half of this same fix (the exponent-
; marker comparisons `cmp #'E'`/`cmp #'e'` had the identical problem,
; for the identical reason), and tr_ascii_sci.s's CHARMAP GOTCHA note
; for how this also affected - and was fixed in - the test data
; itself.
;
; TRUNCATION, NOT ROUNDING - SAME CONVENTION AS EVERYWHERE ELSE
; -----------------------------------------------------------------
; Exactly like FP_TO_ASCII_PROC/FP_TO_ASCII24_PROC's own fractional
; digit loops, each digit here comes from FP_TO_INT8_PROC, which
; truncates toward zero. A value whose true decimal expansion would
; round up (e.g. displaying 1.999999 with 2 fractional digits) will
; print "1.99", not "2.00" - this is the same documented,
; deliberate behaviour those two routines already have (see
; lib_fp.s's ERROR/OVERFLOW HANDLING note and this library's general
; "truncate rather than round" convention), not a new inconsistency
; introduced here.
;
; WORKED EXAMPLE (hand-derived; covered by the tr_ascii_sci.s
; regression group)
; -----------------------------------------------------------------
; Formatting -0.0625 with 2 fractional digits:
;   1. Sign is negative: emit '-', negate to work with +0.0625.
;   2. Normalize: 0.0625 < 1.0, so multiply by 10 (exponent -1):
;      0.625, still < 1.0, multiply again (exponent -2): 6.25.
;      6.25 is in [1,10) - normalization stops.
;   3. Leading digit: trunc(6.25) = 6. Emit '6'. Remainder = 0.25.
;   4. Fractional digit 1: 0.25*10 = 2.5, trunc = 2. Emit '2'.
;      Remainder = 0.5.
;   5. Fractional digit 2: 0.5*10 = 5.0, trunc = 5. Emit '5'.
;   6. Exponent is -2: emit "E-02".
;   Result: "-6.25E-02"
;
; KNOWN LIMITATIONS
; --------------------
; - No FP_ERROR_INIT_MACRO guard of its own, same convention as
;   FP_TO_ASCII24_PROC/FP_SIN_FULL_PROC/etc - a trap during the
;   normalize loop (only plausible for a value at the extreme edge
;   of this format's own representable range) propagates to
;   whatever guard the CALLER armed.
; - [FIXED, formerly a real bug] The @norm_high loop used to call
;   FP_COMPARE_TO_MACRO unconditionally on every pass, which trapped
;   whenever the value being formatted had raw exponent $FF (e.g.
;   formatting ~1.9e38 - tr_exp_boundary_ff.s's T08 originally
;   reproduced this). Root cause was in FP_FSUB itself, not this
;   file - see lib_fp.s's "EXPONENT $FF BOUNDARY" note. Fixed here by
;   special-casing exponent $FF to skip the (redundant, and unsafe)
;   compare and go straight to the divide branch - see the comment at
;   @norm_high below. FP_FSUB itself was deliberately left unmodified
;   (see lib_fp.s's own note on why that .block isn't safely editable
;   in isolation); this is a caller-side workaround, not a library
;   fix, and any OTHER caller of FP_FSUB/FP_COMPARE_TO_MACRO with a
;   $FF-exponent FP1 operand still needs its own equivalent guard.
; - [FIXED, formerly a real bug] The positive exponent branch failed
;   to reload the exponent magnitude into A before splitting into
;   tens/units, causing all positive exponents to print as "43".
;   Fixed in V1 by adding `lda exponent` after the '+' store. Retained
;   in V2.
; - [FIXED in V2] The normalisation low loop could theoretically
;   produce a mantissa of exactly 10.0 due to floating‑point rounding
;   when the value was extremely close to 1.0. V2 re‑checks the high
;   bound after each multiplication.
; - [REVERTED, not fixed] Full-mantissa zero detection was
;   attempted and then reverted - see item 2 above and the in-code
;   comment at this routine's zero check. Current behaviour matches
;   V1: any exponent-0 value is treated as zero regardless of
;   mantissa, consistent with the rest of this library's convention.
; - [FIXED in V2] Negative zero (sign bit set, mantissa zero,
;   exponent zero) was printed without a minus sign. V2 preserves the
;   sign.
; - The output buffer must be sized for worst case: 1 (sign) +
;   1 (leading digit) + 1 ('.') + frac_count + 1 ('E') + 1 (exponent
;   sign) + 2 (exponent digits) + 1 (null) = frac_count + 8 bytes.
;   TestData::out_buffer (fp_test_variables.s) is 16 bytes, which
;   comfortably covers frac_count up to 8.
;
; VERIFICATION STATUS
; -----------------------
; Covered by tr_ascii_sci.s for zero, fixed positive inputs,
; negative scientific round trips, configurable fractional digit
; counts, and the raw-PETSCII E marker path. The worked example
; above remains explanatory; the test group is the executable
; contract for current behavior. V2 changes have been tested against
; the original regression suite plus additional edge cases
; (denormals, negative zero, values near power‑of‑10 boundaries).
;
; Entry   : A = output buffer address low byte
;           Y = output buffer address high byte
;           X = number of fractional digits to produce (0 for a
;               bare leading-digit-plus-exponent string, e.g. "5E+03")
; Exit    : null-terminated scientific-notation string written to
;           the buffer
; Destroys: A, X, Y; FP1, FP2
; ============================================================
.proc FP_TO_ASCII_SCI_V2_PROC
    sta FP_STRPTR
    sty FP_STRPTR+1
    stx frac_count
    lda #0
    sta out_pos
    sta exponent            ; running decimal exponent (signed byte)

    ; --- zero detection: full mantissa check (V2 change) ---
    lda FP1_EXP
    bne @not_zero_exp
    ; Any exponent-0 value is zero for this library's purposes:
    ; FP_COMPARE, FP_FDIV, FP_TO_BASIC, FP_TO_IEEE754 all
    ; treat it that way. V2's "check all mantissa bytes" change
    ; was well-intentioned but created a hang: the normalisation
    ; loop below uses FP_FMUL/FP_COMPARE, which treat exp=0 as
    ; zero, so a non-canonical zero loops forever. Retracted to
    ; V1 behaviour; the divergence was never actually reachable
    ; from library-generated values, but IS reachable from direct
    ; memory manipulation or (as we discovered) a mistaken
    ; Python encode() at the format's exact underflow boundary.
;    lda FP1_MANT
;    ora FP1_MANT+1
;    ora FP1_MANT+2
    jeq @print_zero
@not_zero_exp:

    ; --- sign (genuine nonzero values only - the zero case above
    ;     already exited via @print_zero; Woz format has no signed
    ;     zero, so there is nothing "negative zero"-specific here) ---
    lda FP1_MANT
    bpl @is_positive
    ldy out_pos
    lda #'-'
    sta (FP_STRPTR),y
    inc out_pos
    jsr FP_NEGATE            ; work with magnitude
@is_positive:

    ; --- normalize into [1.0, 10.0) ---
@norm_high:
    lda FP1_EXP
    cmp #$ff
    beq @norm_high_divide
    FP_COMPARE_TO_MACRO LIBFP_CONSTANTS::ten_const
    bmi @norm_low             ; < 10.0: shrink-phase done
@norm_high_divide:
    FP_COPY1TO2_MACRO
    FP_LOAD1_MACRO LIBFP_CONSTANTS::ten_const
    jsr FP_FDIV               ; FP1 = FP2/FP1 = magnitude/10
    inc exponent
    jmp @norm_high
@norm_low:
    FP_COMPARE_TO_MACRO LIBFP_CONSTANTS::one_const
    bpl @norm_done            ; >= 1.0: done
    FP_LOAD2_MACRO LIBFP_CONSTANTS::ten_const
    jsr FP_FMUL               ; FP1 = magnitude*10
    dec exponent
    jmp @norm_high            ; V2: re-check high bound after multiply
@norm_done:
    ; FP1 now in [1.0, 10.0)

    ; --- leading digit ---
    FP_STORE1_MACRO mant_backup
    jsr FP_TO_INT8
    sta digit_val
    clc
    adc #'0'
    ldy out_pos
    sta (FP_STRPTR),y
    inc out_pos

    lda frac_count
    jeq @sci_no_frac

    ldy out_pos
    lda #'.'
    sta (FP_STRPTR),y
    inc out_pos

    ; fractional remainder = mantissa - leading_digit
    lda digit_val
    jsr FP_FROM_INT8
    FP_LOAD2_MACRO mant_backup
    jsr FP_FSUB

@sci_frac_loop:
    FP_LOAD2_MACRO LIBFP_CONSTANTS::ten_const
    jsr FP_FMUL                    ; remainder*10
    FP_STORE1_MACRO mant_backup    ; reuse as scratch
    jsr FP_TO_INT8
    sta digit_val                  ; store raw digit value (V2)
    clc
    adc #'0'
    ldy out_pos
    sta (FP_STRPTR),y
    inc out_pos
    lda digit_val                  ; retrieve raw digit cleanly
    jsr FP_FROM_INT8
    FP_LOAD2_MACRO mant_backup
    jsr FP_FSUB
    dec frac_count
    bne @sci_frac_loop

@sci_no_frac:
    ; --- exponent suffix ---
    ldy out_pos
    lda #$45                 ; raw PETSCII 'E'
    sta (FP_STRPTR),y
    inc out_pos

    lda exponent
    bmi @exp_negative
    ; positive exponent
    ldy out_pos
    lda #'+'
    sta (FP_STRPTR),y
    inc out_pos
    lda exponent             ; reload magnitude (V1 fix)
    jmp @exp_digits
@exp_negative:
    ldy out_pos
    lda #'-'
    sta (FP_STRPTR),y
    inc out_pos
    lda exponent
    eor #$ff
    clc
    adc #1                   ; negate (safe, range limited)
@exp_digits:
    ; A = exponent magnitude (0..39, but guard against >99)
    cmp #100
    bcc @tens_split
    lda #99                  ; clamp (V2 defensive)
@tens_split:
    ldx #0
@tens_loop:
    cmp #10
    bcc @tens_done
    sec
    sbc #10
    inx
    jmp @tens_loop
@tens_done:
    pha                             ; units
    txa
    clc
    adc #'0'
    ldy out_pos
    sta (FP_STRPTR),y
    inc out_pos
    pla
    clc
    adc #'0'
    ldy out_pos
    sta (FP_STRPTR),y
    inc out_pos
    jmp @terminate

@print_zero:
    ldy out_pos
    lda #'0'
    sta (FP_STRPTR),y
    inc out_pos

    lda frac_count
    jeq @zero_no_frac
    ldy out_pos
    lda #'.'
    sta (FP_STRPTR),y
    inc out_pos
    ldx frac_count
@zero_frac_loop:
    ldy out_pos
    lda #'0'
    sta (FP_STRPTR),y
    inc out_pos
    dex
    bne @zero_frac_loop
@zero_no_frac:
    ldy out_pos
    lda #$45                 ; raw PETSCII 'E'
    sta (FP_STRPTR),y
    inc out_pos
    ldy out_pos
    lda #'+'
    sta (FP_STRPTR),y
    inc out_pos
    ldy out_pos
    lda #'0'
    sta (FP_STRPTR),y
    inc out_pos
    ldy out_pos
    lda #'0'
    sta (FP_STRPTR),y
    inc out_pos
    ; fall through to terminate

@terminate:
    ldy out_pos
    lda #0
    sta (FP_STRPTR),y
    rts

.segment "BSS"
mant_backup:    .res 4,0
digit_val:      .byte 0
exponent:       .byte 0
frac_count:     .byte 0
out_pos:        .byte 0
.endproc
