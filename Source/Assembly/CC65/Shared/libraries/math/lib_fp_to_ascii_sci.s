.include "macros_fp.s"
.macpack longbranch

.export FP_TO_ASCII_SCI
.import FP_FSUB, FP_FMUL, FP_FDIV
.import FP_NEGATE
.import FP_FROM_INT8, FP_TO_INT8
.import FP_COMPARE      ; [BUG FIX] FP_COMPARE_TO_MACRO (macros_fp.s)
                        ; expands to "jsr FP_COMPARE" - the macro
                        ; itself doesn't import anything on the
                        ; caller's behalf, so this file needs its own
                        ; explicit import, same as every other file
                        ; that uses FP_COMPARE_TO_MACRO (see
                        ; lib_fp_ceil.s/lib_fp_floor.s/lib_fp_to_uint16.s
                        ; for the same pattern)

FP_TO_ASCII_SCI = FP_TO_ASCII_SCI_PROC

.segment "CODE"
; ============================================================
; FILE    : lib_fp_to_ascii_sci.s
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
; WORKED EXAMPLE (hand-derived, not yet hardware-confirmed - see
; VERIFICATION STATUS below)
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
; - The output buffer must be sized for worst case: 1 (sign) +
;   1 (leading digit) + 1 ('.') + frac_count + 1 ('E') + 1 (exponent
;   sign) + 2 (exponent digits) + 1 (null) = frac_count + 8 bytes.
;   TestData::out_buffer (fp_test_variables.s) is 16 bytes, which
;   comfortably covers frac_count up to 8.
;
; VERIFICATION STATUS
; -----------------------
; Not yet run on VICE or physical hardware - per this project's
; usual workflow (see lib_fp_sin.s's own header for the precedent),
; the WORKED EXAMPLE above is a hand-derivation, a first pass, not
; a substitute for an actual monitor register dump. Treat this as
; ready for T-series testing (see tr_ascii_sci.s), not yet proven.
;
; Entry   : A = output buffer address low byte
;           Y = output buffer address high byte
;           X = number of fractional digits to produce (0 for a
;               bare leading-digit-plus-exponent string, e.g. "5E+03")
; Exit    : null-terminated scientific-notation string written to
;           the buffer
; Destroys: A, X, Y; FP1, FP2
; ============================================================
.proc FP_TO_ASCII_SCI_PROC
    sta FP_STRPTR
    sty FP_STRPTR+1
    stx frac_count
    lda #0
    sta out_pos
    sta exponent            ; running decimal exponent (signed byte) -
                            ; starts at 0, adjusted by the normalize
                            ; loop below

    ; --- canonical zero: handled entirely separately, since log-style
    ;     normalization has no meaning for zero (the divide/multiply
    ;     loop below would either spin forever or divide by nothing
    ;     useful - there is no "exponent of zero") ---
    lda FP1_EXP
    jeq @print_zero

    ; --- sign ---
    lda FP1_MANT
    bpl @is_positive
    ldy out_pos
    lda #'-'
    sta (FP_STRPTR),y
    inc out_pos
    jsr FP_NEGATE            ; work with the magnitude from here on
@is_positive:

    ; --- normalize into [1.0, 10.0) - see the file header's THE
    ;     ALGORITHM note for why this is a self-correcting loop
    ;     rather than a single FP_LOG10-based estimate ---
@norm_high:
    FP_COMPARE_TO_MACRO ten_const
    bmi @norm_low             ; magnitude < 10.0: shrink-phase done
    ; magnitude >= 10.0 (equal counts too - [1,10) is a half-open
    ; interval, so exactly 10.0 still needs to become 1.0): divide
    ; by 10 and bump the exponent, then re-check
    FP_COPY1TO2_MACRO
    FP_LOAD1_MACRO ten_const
    jsr FP_FDIV               ; FP1 = FP2/FP1 = magnitude/10
    inc exponent
    jmp @norm_high
@norm_low:
    FP_COMPARE_TO_MACRO one_const
    bpl @norm_done             ; magnitude >= 1.0 (bpl catches both
                               ; "greater" and "equal" - FP_COMPARE
                               ; returns a non-negative A for either):
                               ; grow-phase done
    FP_LOAD2_MACRO ten_const
    jsr FP_FMUL                 ; FP1 = magnitude*10
    dec exponent
    jmp @norm_low
@norm_done:
    ; FP1 is now in [1.0, 10.0)

    ; --- leading digit ---
    FP_STORE1_MACRO mant_backup  ; stash the [1,10) mantissa - the
                                 ; FP_TO_INT8 call below destroys FP1
                                 ; (same reason FP_TO_ASCII_PROC backs
                                 ; up its own value first - see that
                                 ; file's own comment)
    jsr FP_TO_INT8                ; A = leading digit (always 1-9 here,
                                 ; never overflows FP_TO_INT8's -128..
                                 ; 127 range)
    sta digit_val
    clc
    adc #'0'
    ldy out_pos
    sta (FP_STRPTR),y
    inc out_pos

    lda frac_count
    jeq @sci_no_frac             ; caller asked for 0 fractional
                                 ; digits: skip straight to 'E...'

    ldy out_pos
    lda #'.'
    sta (FP_STRPTR),y
    inc out_pos

    ; fractional remainder = mantissa - leading_digit, using exactly
    ; the same "digit-then-subtract" technique FP_TO_ASCII_PROC's own
    ; frac_loop already uses (see that file for the full derivation) -
    ; deliberately not reinvented here
    lda digit_val
    jsr FP_FROM_INT8               ; FP1 = float(leading digit)
    FP_LOAD2_MACRO mant_backup     ; FP2 = original [1,10) mantissa
    jsr FP_FSUB                    ; FP1 = FP2-FP1 = fractional remainder

@sci_frac_loop:
    FP_LOAD2_MACRO ten_const
    jsr FP_FMUL                    ; FP1 = remainder*10 (always < 10.0 -
                                   ; remainder itself was always < 1.0)
    FP_STORE1_MACRO mant_backup    ; reuse mant_backup as this loop's
                                   ; own scratch (safe - the [1,10)
                                   ; mantissa it held is no longer
                                   ; needed once the leading digit and
                                   ; first remainder are extracted)
    jsr FP_TO_INT8                  ; A = next digit (0-9)
    clc
    adc #'0'
    ldy out_pos
    sta (FP_STRPTR),y
    inc out_pos
    sec
    sbc #'0'                       ; recover the raw digit value
    jsr FP_FROM_INT8                ; FP1 = float(digit)
    FP_LOAD2_MACRO mant_backup      ; FP2 = remainder*10
    jsr FP_FSUB                     ; FP1 = next fractional remainder
    dec frac_count
    bne @sci_frac_loop

@sci_no_frac:
    ; --- exponent suffix: 'E', explicit sign, two digits ---
    ; [BUG FIX] $45, not the character literal 'E' - see the RAW HEX
    ; note near the top of this file's header for the full mechanism.
    ; In short: ca65 runs character literals through the same
    ; .charmap translation as .asciiz string text, and this project's
    ; convention (confirmed against real hardware output) is that
    ; LOWERCASE source text becomes the PETSCII bytes that DISPLAY as
    ; uppercase - so a literal `lda #'E'` (uppercase in SOURCE) does
    ; NOT produce the byte that displays as 'E'; it produces the byte
    ; that displays as a graphic symbol in the default charset
    ; instead (confirmed on hardware - see tr_ascii_sci.s's own
    ; CHARMAP GOTCHA note). $45 is PETSCII's real, case-independent
    ; code for the letter E - it displays as 'E' regardless of
    ; charset mode or any compile-time translation, so writing it as
    ; a raw hex constant sidesteps the whole ambiguity rather than
    ; trying to remember which source case produces which byte.
    ldy out_pos
    lda #$45
    sta (FP_STRPTR),y
    inc out_pos

    lda exponent
    bmi @exp_negative
    ldy out_pos
    lda #'+'
    sta (FP_STRPTR),y
    inc out_pos
    ; [BUG FIX] A must be reloaded with the exponent's MAGNITUDE here
    ; before falling into @exp_digits below. The negative branch does
    ; this naturally (it needs to negate exponent into A anyway - see
    ; the eor/adc sequence just below), but this positive branch has
    ; no such step of its own, so without this line A still holds
    ; whatever the '+' store above left behind - literally the
    ; character '+' itself ($2B = 43 decimal). @exp_digits then
    ; happily split THAT into tens/units and printed "43" for every
    ; single positive exponent, regardless of what the real exponent
    ; was (confirmed on hardware: T00/T01/T04/T05/T07 - every E+NN
    ; case - all printed "...E+43" while T06, the one E-NN case,
    ; printed correctly, which is exactly the fingerprint of "A never
    ; reloaded on the positive path" rather than a bug in the
    ; tens/units splitting logic itself).
    lda exponent             ; already non-negative here (bmi above
                             ; didn't take the branch) - no negation
                             ; needed, unlike the @exp_negative path
    jmp @exp_digits
@exp_negative:
    ldy out_pos
    lda #'-'
    sta (FP_STRPTR),y
    inc out_pos
    lda exponent
    eor #$ff                       ; two's-complement negate of a
    clc                            ; signed byte (safe here - this
    adc #1                         ; format's exponent range never
                                   ; reaches the -128 edge case where
                                   ; this trick would overflow)
@exp_digits:
    ; A = exponent MAGNITUDE (0-39ish - see the file header's WHY TWO
    ; EXPONENT DIGITS note). Split into tens/units by repeated
    ; subtraction, the same technique OUTPUT_BYTETODEC_PROC and
    ; FP_TO_ASCII24_PROC's own print_integer24 already use.
    ldx #0
@tens_loop:
    cmp #10
    bcc @tens_done
    sec
    sbc #10
    inx
    jmp @tens_loop
@tens_done:
    pha                             ; save the units digit
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
    lda #$45                 ; [BUG FIX] $45, not 'E' - see the
                             ; @sci_no_frac note above for why
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
    ; falls through into @terminate below - no separate zero magnitude
    ; to compute, "0E+00"/"0.00E+00" etc. is the whole answer

@terminate:
    ldy out_pos
    lda #0
    sta (FP_STRPTR),y
    rts

.segment "RODATA"
ten_const:      .byte $83,$50,$00,$00   ; 10.0 - own copy, same bytes
                                        ; used throughout this library
one_const:      .byte $80,$40,$00,$00   ; 1.0
.segment "BSS"
mant_backup:    .res 4,0
digit_val:      .byte 0
exponent:       .byte 0                 ; signed running decimal
                                        ; exponent, range roughly -39..
                                        ; +38 - see WHY TWO EXPONENT
                                        ; DIGITS above
frac_count:     .byte 0
out_pos:        .byte 0
.endproc
