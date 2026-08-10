.include "macros_fp.s"

.export FP_FROM_ASCII_SCI
.import FP_FADD, FP_FMUL, FP_FDIV
.import FP_NEGATE, FP_NORM, FP_FLOAT

FP_FROM_ASCII_SCI = FP_FROM_ASCII_SCI_PROC

.segment "CODE"
; ============================================================
; FILE    : lib_fp_from_ascii_sci.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; Parse a null-terminated decimal string that MAY include a
; scientific-notation exponent suffix - [-+]D[.D...][E|e[-+]D[D]] -
; into FP1. The mantissa part (sign, integer digits, optional
; decimal point, fractional digits) is parsed with the EXACT same
; split-accumulator technique FP_FROM_ASCII24_PROC already uses;
; this file adds ONLY the exponent-suffix scan and the power-of-10
; scaling that applies it. FP_FROM_ASCII24_PROC itself is not
; touched - the standard coexistence pattern (see that file's own
; header, and lib_fp_sin_full.s's PURPOSE note, for the general
; reasoning this project always applies here).
;
; WHY THIS IS BUILT ON FP_FROM_ASCII24_PROC's MANTISSA LOGIC,
; NOT FP_FROM_ASCII_PROC's
; -----------------------------------------------------------------
; FP_FROM_ASCII_PROC accumulates integer AND fractional digits into
; ONE running Horner total, which - as that file's own header
; documents at length - silently loses precision once the COMBINED
; digit count gets large (its own confirmed failure case: parsing
; "1234567.25" produced 1234566.50). Scientific notation is exactly
; the format most likely to be handed multi-digit mantissas with a
; decimal point ("1.2345678E+10" has 8 combined mantissa digits), so
; this file starts from FP_FROM_ASCII24_PROC's ALREADY-FIXED split-
; accumulator approach (integer digits and fractional digits kept in
; two independent Horner totals, combined only once at the very end
; via a single FP_FADD) rather than re-introducing that exact bug in
; a new routine.
;
; THE EXPONENT SUFFIX: 'E' or 'e', OPTIONAL SIGN, DIGITS
; -----------------------------------------------------------------
; Once the mantissa scan stops (at the first character that isn't a
; digit or the decimal point - see FP_FROM_ASCII24_PROC's own scan
; loops, reused here completely unchanged), this file checks whether
; that stopping character is 'E' or 'e'. If not, the string had no
; exponent - the mantissa alone IS the final value (this is also
; how an ordinary, non-scientific decimal string like "42.5" is
; still parsed correctly by this same routine - see T04 in
; tr_ascii_sci.s). If it IS an exponent marker, an optional '+'/'-'
; and then up to two decimal digits are read and combined into a
; small integer via the same "total = total*10 + digit" technique
; used for the mantissa - but kept as a PLAIN 8-BIT INTEGER (not a
; float), since a decimal exponent for this format's own value
; range never exceeds about 39 in magnitude (see
; lib_fp_to_ascii_sci.s's WHY TWO EXPONENT DIGITS note - the exact
; same reasoning applies on the parsing side) and plain 6502
; arithmetic on a single byte is far cheaper than routing something
; this small through the FP engine.
;
; APPLYING THE EXPONENT: A LOOP OF PLAIN FMUL/FDIV BY 10, NOT A
; "RAISE TO A POWER" PRIMITIVE
; -----------------------------------------------------------------
; This library has no general exponentiation routine, so "multiply
; the parsed mantissa by 10^exponent" is done the same way
; FP_FROM_ASCII_PROC/FP_FROM_ASCII24_PROC already undo their own
; fractional-digit scaling: one FP_FMUL (positive exponent) or
; FP_FDIV (negative exponent) per unit of exponent magnitude,
; looped. For this format's realistic exponent range (well under
; 40) that's at most ~40 iterations - cheap, and it reuses
; FP_FMUL/FP_FDIV's own already-proven overflow/underflow handling
; (see lib_fp.s) rather than needing any of its own.
;
; ERROR HANDLING
; ----------------
; No FP_ERROR_INIT_MACRO guard of its own - same convention as
; FP_FROM_ASCII24_PROC and most of this library's higher-level
; routines. A pathological exponent (e.g. "1E38" on a mantissa
; already near this format's own magnitude ceiling) can overflow
; during the FP_FMUL scaling loop; that trap propagates to whatever
; guard the CALLER armed. A malformed exponent with MORE than two
; digits (e.g. "1E12345") silently overflows the 8-bit exp_value
; accumulator rather than being rejected - out of scope, matching
; this library's general "document the limitation rather than add
; unrequested defensive machinery" convention (see e.g.
; lib_fp_to_ascii24.s's own OVERFLOW BEHAVIOUR note for the same
; philosophy applied elsewhere). Realistic decimal exponents for
; this format never approach that limit.
;
; WORKED EXAMPLE
; ------------------
; Parsing "5E-1":
;   1. Mantissa pass: no sign, no decimal point seen, integer digit
;      '5' accumulated -> int_part = 5.0. No fraction digits.
;      FP1 = 5.0 (via @no_fraction - int_part used directly, no
;      redundant FADD against 0.0).
;   2. Exponent check: next character is 'E'. Sign is '-'.
;      Digit '1' accumulated -> exp_value = 1, exp_is_negative = 1.
;   3. Scaling: exp_value=1, negative, so ONE FP_FDIV by 10.0:
;      FP1 = 5.0 / 10.0 = 0.5.
;   Result: FP1 = 0.5. (See tr_ascii_sci.s's T06 for the confirming
;   round trip back out through FP_TO_ASCII_SCI_PROC.)
;
; VERIFICATION STATUS
; -----------------------
; Not yet run on VICE or physical hardware - the WORKED EXAMPLE
; above is a hand-derivation. Treat this as ready for T-series
; testing (see tr_ascii_sci.s), not yet proven, same status as its
; companion file lib_fp_to_ascii_sci.s.
;
; Entry   : A = string address low byte, Y = string address high byte
; Exit    : FP1 = parsed value. Carry clear if the MANTISSA contained
;           at least one digit; carry set (FP1 left at 0.0) if it
;           didn't - matching FP_FROM_ASCII24_PROC's own convention.
;           A malformed or absent exponent suffix never by itself
;           sets carry, as long as the mantissa had a digit.
; Destroys: A, X, Y; FP1, FP2
; ============================================================
.proc FP_FROM_ASCII_SCI_PROC
    sta FP_STRPTR
    sty FP_STRPTR+1
    lda #0
    sta FP1_EXP
    sta FP1_MANT
    sta FP1_MANT+1
    sta FP1_MANT+2                  ; FP1 = 0.0 (integer-part accumulator)
    sta is_negative
    sta point_seen
    sta frac_digits
    sta saw_digit
    sta scan_pos

    ldy #0
    lda (FP_STRPTR),y
    cmp #'-'
    bne @check_plus
    inc is_negative
    inc scan_pos
    jmp @int_loop
@check_plus:
    cmp #'+'
    bne @int_loop
    inc scan_pos

    ; ── PASS 1: integer digits (identical to FP_FROM_ASCII24_PROC's
    ;    own @int_loop - stops at '.', 'E'/'e', or any other
    ;    non-digit, since none of those match the digit range check
    ;    below) ──────────────────────────────────────────────────
@int_loop:
    ldy scan_pos
    lda (FP_STRPTR),y
    cmp #'.'
    beq @got_point
    cmp #'0'
    bcc @int_done
    cmp #'9'+1
    bcs @int_done
    inc saw_digit
    sec
    sbc #'0'
    jsr @accumulate_digit
    inc scan_pos
    jmp @int_loop
@got_point:
    inc point_seen
    inc scan_pos
@int_done:
    FP_STORE1_MACRO int_part        ; stash the integer total - see
                                    ; FP_FROM_ASCII24_PROC's own
                                    ; @int_done comment for why this
                                    ; split is what avoids the
                                    ; combined-digit-count bug

    lda point_seen
    bne @frac_reset
    jmp @no_fraction

    ; ── PASS 2: fraction digits, own independent accumulator ────
@frac_reset:
    lda #0
    sta FP1_EXP
    sta FP1_MANT
    sta FP1_MANT+1
    sta FP1_MANT+2                  ; FP1 = 0.0 (fraction-only accumulator)
@frac_loop:
    ldy scan_pos
    lda (FP_STRPTR),y
    cmp #'0'
    bcc @frac_done
    cmp #'9'+1
    bcs @frac_done
    inc saw_digit
    sec
    sbc #'0'
    jsr @accumulate_digit
    inc frac_digits
    inc scan_pos
    jmp @frac_loop
@frac_done:
    lda frac_digits
    beq @no_fraction

    ; undo the fraction's own scale - same technique
    ; FP_FROM_ASCII24_PROC's own @divide_loop uses
@divide_loop:
    pha
    FP_COPY1TO2_MACRO
    FP_LOAD1_MACRO ten_const
    jsr FP_FDIV
    pla
    sec
    sbc #1
    bne @divide_loop

    FP_LOAD2_MACRO int_part
    jsr FP_FADD                     ; FP1 = integer part + fraction
    jmp @apply_sign

@no_fraction:
    FP_LOAD1_MACRO int_part         ; FP1 = int_part exactly - no FADD
                                    ; needed (see FP_FROM_ASCII24_PROC's
                                    ; own note on why adding here would
                                    ; double it)

@apply_sign:
    lda is_negative
    beq @check_exponent
    jsr FP_NEGATE
    ; falls through - the exponent suffix, if any, applies to the
    ; SIGNED value exactly the same way as the unsigned one
    ; (multiplying/dividing by a power of 10 doesn't care about sign)

    ; ── exponent suffix: optional 'E'/'e', optional sign, digits ──
    ; [BUG FIX] $45/$65, not the character literals 'E'/'e' - ca65
    ; runs single-quoted character literals through the same
    ; .charmap letter-case translation it applies to .asciiz text
    ; (this project's whole codebase depends on that translation for
    ; readable lowercase-source message strings - see
    ; lib_fp_to_ascii_sci.s's own RAW HEX header note for the full
    ; mechanism, confirmed on real hardware). `cmp #'E'` would
    ; therefore NOT compare against real PETSCII $45 ('E' as it
    ; actually displays) - it would compare against the $61-$7A-range
    ; byte that source-uppercase 'E' translates to instead, which is
    ; a completely different, unrelated PETSCII code. Writing the raw
    ; hex values here sidesteps that translation entirely, so this
    ; routine recognizes GENUINE PETSCII $45/$65 - the bytes a real
    ; keyboard, or a correctly-encoded external string, would actually
    ; contain - rather than whatever ca65's letter-swap happens to
    ; produce for a particular source spelling.
@check_exponent:
    ldy scan_pos
    lda (FP_STRPTR),y
    cmp #$45                        ; real PETSCII 'E'
    beq @has_exponent
    cmp #$65                        ; real PETSCII 'e'
    beq @has_exponent
    jmp @no_scale                   ; no exponent marker: the mantissa
                                    ; IS the final value - this is also
                                    ; the path an ordinary non-
                                    ; scientific string like "42.5"
                                    ; takes (see tr_ascii_sci.s's T04)

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
    ; exp_value = exp_value*10 + digit, using plain 8-bit arithmetic
    ; (no float involved - see the file header's APPLYING THE
    ; EXPONENT note for why this stays an integer). *10 is built from
    ; shifts: (v<<1) + (v<<3) = v*2 + v*8 = v*10.
    lda exp_value
    asl                              ; A = exp_value*2
    sta exp_tmp2
    asl                              ; A = exp_value*4
    asl                              ; A = exp_value*8
    clc
    adc exp_tmp2                     ; A = exp_value*8 + exp_value*2
                                     ;   = exp_value*10
    clc                              ; [BUG-AVOIDANCE] a fresh clc here,
                                     ; not a reused carry from the adc
                                     ; above, so the digit is added
                                     ; cleanly with no stray +1
    adc exp_digit_tmp
    sta exp_value
    inc scan_pos
    jmp @exp_digit_loop
@exp_digits_done:

    ; ── apply the parsed exponent: exp_value FMUL/FDIV passes by
    ;    10.0, direction chosen by exp_is_negative ────────────────
    lda exp_value
    beq @no_scale                   ; exponent 0 (or no digits followed
                                    ; a lone 'E' - a malformed suffix
                                    ; degrades gracefully to "no
                                    ; scaling" rather than erroring)
    sta scale_count
    lda exp_is_negative
    bne @scale_divide_loop

@scale_multiply_loop:
    FP_LOAD2_MACRO ten_const
    jsr FP_FMUL                     ; FP1 = FP1 * 10.0
    dec scale_count
    bne @scale_multiply_loop
    jmp @no_scale

@scale_divide_loop:
    FP_COPY1TO2_MACRO                ; FP2 = running value
    FP_LOAD1_MACRO ten_const         ; FP1 = 10.0 (divisor)
    jsr FP_FDIV                      ; FP1 = FP2/FP1 = running/10
    dec scale_count
    bne @scale_divide_loop

@no_scale:
    lda saw_digit
    beq @no_digits
    clc
    rts
@no_digits:
    sec
    rts

; --- accumulate_digit: FP1 = FP1*10 + A  (A = digit value 0-9) ---
; Identical technique to FP_FROM_ASCII24_PROC's own @accumulate_digit,
; reused here for both mantissa passes.
@accumulate_digit:
    sta digit_tmp
    FP_LOAD2_MACRO ten_const         ; FP2 = 10.0
    jsr FP_FMUL                      ; FP1 = total * 10
    FP_STORE1_MACRO accum            ; stash total*10 - building the
                                     ; digit float needs FP1
    lda digit_tmp
    sta FP1_MANT+1                   ; digit as a 16-bit integer
    lda #0
    sta FP1_MANT
    jsr FP_FLOAT                     ; FP1 = float(digit)
    FP_COPY1TO2_MACRO                ; FP2 = float(digit)
    FP_LOAD1_MACRO accum             ; FP1 = total*10 (restored)
    jsr FP_FADD                      ; FP1 = total*10 + digit
    rts

accum:            .res 4,0
int_part:         .res 4,0
digit_tmp:        .byte 0
is_negative:      .byte 0
point_seen:       .byte 0
frac_digits:      .byte 0
saw_digit:        .byte 0
scan_pos:         .byte 0
exp_is_negative:  .byte 0
exp_value:        .byte 0            ; parsed exponent MAGNITUDE, plain
                                     ; unsigned byte (see file header)
exp_digit_tmp:    .byte 0
exp_tmp2:         .byte 0
scale_count:      .byte 0
ten_const:        .byte $83,$50,$00,$00   ; 10.0 - same bytes used
                                          ; throughout this library
.endproc
