
.include "tr.inc"

.export tr_ascii_sci

.import FP_FROM_ASCII
.import FP_FROM_ASCII_SCI, FP_TO_ASCII_SCI
.import TEST_STRCMP, TEST_PASSED, TEST_FAILED

; ============================================================
; FILE    : tr_ascii_sci.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; Regression coverage for lib_fp_to_ascii_sci.s and
; lib_fp_from_ascii_sci.s - the new scientific-notation
; string<->float pair. Follows the same TEST_STRCMP_MACRO_V2
; string-comparison pattern tr_ascii24.s already uses (rather than
; TEST_FP1CMP's byte-for-byte float comparison), because hand-
; deriving the exact 4-byte Woz encoding of a scientific-notation
; round trip is far more error-prone than deriving the expected
; DECIMAL STRING - the same reasoning tr_ascii24.s's own T56-T66
; already apply, just carried over here for a new pair of routines.
;
; VERIFICATION STATUS - READ BEFORE TRUSTING THESE
; -----------------------------------------------------------------
; Every expected string below is HAND-DERIVED (see each routine's
; own WORKED EXAMPLE for the worked-by-hand arithmetic), not yet
; confirmed against actual VICE or C64U output - matching the
; VERIFICATION STATUS both new library files already carry in their
; own headers. Per this project's usual workflow, run this group,
; compare the PASS/FAIL output against what's expected here, and
; correct either the test or the routine if reality differs -
; exactly the same caution tr_ascii16.s's own T67-T70 header already
; asks for.
;
; CHARMAP GOTCHA - HOW THE 'E'/'e' MARKER STRINGS ARE ACTUALLY BUILT
; -----------------------------------------------------------------
; Confirmed on hardware, worth understanding before editing any
; string below. Two DIFFERENT string-building directives behave
; differently here, and getting this backwards is easy:
;
;   .asciiz  - runs its text through ca65's active .charmap letter
;              translation, same as every message string in this
;              codebase (msg_to, msg_from, msg_roundtrip below, and
;              every existing test message elsewhere) - this is
;              exactly what makes lowercase SOURCE text display as
;              readable uppercase PETSCII on screen.
;   .literal - performs NO translation at all. Whatever byte you
;              write in source is the exact byte stored, full stop
;              (see main.s's msg_prompt_output for the existing
;              precedent - an all-uppercase-source .literal string,
;              chosen for exactly this reason).
;
; This file's FIRST attempt at fixing the exponent-marker byte tried
; to keep using .asciiz and simply write the 'E' in the "opposite"
; source case, on the theory that .charmap performs a simple
; uppercase<->lowercase swap. That theory turned out WRONG - or at
; least not reliably right in every context - confirmed when T07
; (which needs a genuine, DISTINCT byte for lowercase 'e', $65, as
; opposed to uppercase 'E', $45) FAILED even after applying that
; swap: whatever byte .asciiz's charmap actually produced for
; source-uppercase 'E' was neither $45 nor $65, so the parser's
; real-PETSCII comparison (cmp #$45 / cmp #$65 - see
; lib_fp_from_ascii_sci.s) matched neither, and the parsed exponent
; silently stayed 0. Trying to predict .charmap's exact translation
; table by trial and error is fragile - the robust fix is to
; sidestep the guessing entirely.
;
; EVERY string below that needs an exact, specific PETSCII byte for
; its 'E'/'e' marker is therefore built with .literal instead of
; .asciiz, terminated with an explicit trailing $0 (.literal has no
; automatic null-termination the way .asciiz does), and written in
; whatever case ALREADY matches the real byte wanted - 'E' (uppercase
; source) for real PETSCII $45, 'e' (lowercase source) for real
; PETSCII $65 - the obvious, unsurprising mapping, exactly BECAUSE no
; translation happens. msg_to/msg_from/msg_roundtrip stay .asciiz,
; unchanged - they're pure display text where the .charmap
; translation is doing exactly the job it's meant for.
;
; TEST INVENTORY
; -----------------
;   T00  FP_TO_ASCII_SCI,   0 frac digits, integer input (150)
;   T01  FP_TO_ASCII_SCI,   1 frac digit,  same input (150)
;   T02  FP_FROM_ASCII_SCI round trip, negative + negative exponent
;   T03  FP_TO_ASCII_SCI,   canonical zero, 2 frac digits
;   T04  FP_FROM_ASCII_SCI, ordinary decimal with NO exponent suffix
;   T05  FP_FROM_ASCII_SCI, positive exponent, no digit-sign on 'E'
;   T06  FP_FROM_ASCII_SCI, negative exponent, no digit-sign on 'E'
;   T07  FP_FROM_ASCII_SCI, genuine lowercase 'e' exponent marker
;   T08  FP_FROM_ASCII_SCI, EDGE CASE: magnitude overflow ("1E100") -
;        must trap (error code 0), confirms this routine's own "no
;        guard of its own" contract actually propagates correctly
;   T09  FP_FROM_ASCII_SCI, EDGE CASE: magnitude underflow ("1E-100")
;        - must NOT trap, must silently settle to 0.0 instead - the
;        documented opposite of T08, confirmed rather than assumed
;   T10  FP_FROM_ASCII_SCI, EDGE CASE: "no number" - an empty string
;        with no mantissa digits at all - must report carry set and
;        leave FP1 at 0.0, matching FP_FROM_ASCII24_PROC's own
;        documented contract for the same situation
; ============================================================
.proc tr_ascii_sci
    ; --- T00: FP_TO_ASCII_SCI_PROC, 150.0, 0 fractional digits ---
    ; 150 normalizes to 1.5 x 10^2; with 0 fractional digits
    ; requested, only the leading digit (truncated, per this
    ; library's "truncate not round" convention) is printed - the
    ; .5 is simply never asked for, matching FP_TO_ASCII_PROC's own
    ; frac_count=0 behaviour (no '.' printed at all).
    lda #<str_150
    ldy #>str_150
    jsr FP_FROM_ASCII
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #0
    jsr FP_TO_ASCII_SCI
    TEST_STRCMP_MACRO_V2 0, msg_to, str_t00_exp

    ; --- T01: same 150.0, 1 fractional digit - the .5 IS captured
    ;          this time, confirming the fractional loop engages
    ;          correctly once frac_count > 0 ---
    lda #<str_150
    ldy #>str_150
    jsr FP_FROM_ASCII
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #1
    jsr FP_TO_ASCII_SCI
    TEST_STRCMP_MACRO_V2 1, msg_to, str_t01_exp

    ; --- T02: FP_FROM_ASCII_SCI + FP_TO_ASCII_SCI round trip,
    ;          -6.25E-02 (see lib_fp_to_ascii_sci.s's own WORKED
    ;          EXAMPLE - this is that exact value). Exercises: a
    ;          negative mantissa sign, a negative exponent, and the
    ;          normalize-by-multiplying-up loop (0.0625 < 1.0, needs
    ;          two multiply-by-10 passes to reach [1,10)). 6.25 is
    ;          an exactly-representable binary fraction (0.25 =
    ;          2^-2), chosen deliberately so this is a genuine exact-
    ;          match test, not merely "looks about right".
    lda #<str_t02_in
    ldy #>str_t02_in
    jsr FP_FROM_ASCII_SCI
    bcs t02_fail                    ; carry set = no digits found
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII_SCI
    TEST_STRCMP_MACRO_V2 2, msg_roundtrip, str_t02_in
    jmp t02_done
t02_fail:
    TEST_FAILED_MACRO_V2 2, msg_roundtrip
t02_done:

    ; --- T03: FP_TO_ASCII_SCI_PROC, canonical zero, 2 fractional
    ;          digits - the dedicated @print_zero path, not the
    ;          normalize loop (which has no meaning for zero) ---
    lda #<str_zero
    ldy #>str_zero
    jsr FP_FROM_ASCII
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII_SCI
    TEST_STRCMP_MACRO_V2 3, msg_to, str_t03_exp

    ; --- T04: FP_FROM_ASCII_SCI_PROC, ORDINARY decimal with no 'E'
    ;          suffix at all (42.5) - confirms this routine remains
    ;          a strict superset of plain decimal parsing, not just
    ;          a scientific-only parser. 42.5/10 = 4.25 is exact in
    ;          binary (4.25 = 100.01), so the leading-digit
    ;          extraction (4) and single fractional digit (2, from
    ;          truncating 0.25*10=2.5) are both deterministic - the
    ;          discarded .5 is expected, per truncate-not-round.
    lda #<str_t04_in
    ldy #>str_t04_in
    jsr FP_FROM_ASCII_SCI
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #1
    jsr FP_TO_ASCII_SCI
    TEST_STRCMP_MACRO_V2 4, msg_from, str_t04_exp

    ; --- T05: FP_FROM_ASCII_SCI_PROC, "5E3" - no decimal point in
    ;          the mantissa, no explicit '+' on the exponent. Both
    ;          5 and its x1000 scale are exact powers/products of
    ;          small integers, so 5000.0 is exact. ---
    lda #<str_t05_in
    ldy #>str_t05_in
    jsr FP_FROM_ASCII_SCI
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #0
    jsr FP_TO_ASCII_SCI
    TEST_STRCMP_MACRO_V2 5, msg_from, str_t05_exp

    ; --- T06: FP_FROM_ASCII_SCI_PROC, "5E-1" - negative exponent,
    ;          no explicit '+' needed on the MANTISSA sign (there is
    ;          none - value is positive). See this file's WORKED
    ;          EXAMPLE in lib_fp_from_ascii_sci.s - this is that
    ;          exact value. ---
    lda #<str_t06_in
    ldy #>str_t06_in
    jsr FP_FROM_ASCII_SCI
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #0
    jsr FP_TO_ASCII_SCI
    TEST_STRCMP_MACRO_V2 6, msg_from, str_t06_exp

    ; --- T07: FP_FROM_ASCII_SCI_PROC, GENUINE lowercase 'e' exponent
    ;          marker (real PETSCII $65) - confirms the parser's
    ;          $45/$65 check actually accepts both, not just the $45
    ;          case exercised by every other test above. Built with
    ;          .literal (not .asciiz) so the source 'e' is stored
    ;          exactly as written, with no charmap translation to
    ;          second-guess - see this file's CHARMAP GOTCHA header
    ;          note. ---
    lda #<str_t07_in
    ldy #>str_t07_in
    jsr FP_FROM_ASCII_SCI
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #1
    jsr FP_TO_ASCII_SCI
    TEST_STRCMP_MACRO_V2 7, msg_from, str_t07_exp

    ; --- T08: EDGE CASE - magnitude overflow. "1E100" asks for
    ;          10^100, wildly outside this format's own representable
    ;          range (roughly 1e-39..1e38 - see lib_fp_to_ascii_sci.s's
    ;          WHY TWO EXPONENT DIGITS note). Scaling the parsed
    ;          mantissa (1.0) by that many powers of 10 overflows
    ;          partway through the FP_FMUL loop and traps via
    ;          FP_ERROR with the generic-overflow code (0 - see
    ;          lib_fp_error.s's own ERROR CODES list). This routine
    ;          installs no FP_ERROR_INIT_MACRO guard of its own BY
    ;          DESIGN (see its file header's ERROR HANDLING note) -
    ;          this test arms one HERE, at the call site, exactly as
    ;          that contract requires, and confirms the trap actually
    ;          reaches it rather than just trusting the comment. ---
    FP_ERROR_INIT_MACRO t08_recovery
    lda #<str_t08_in
    ldy #>str_t08_in
    jsr FP_FROM_ASCII_SCI
    FP_ERROR_CLEAR_MACRO            ; reached only if NO trap fired -
                                    ; that IS the failure case here,
                                    ; since this input exists purely
                                    ; to overflow
    TEST_FAILED_MACRO_V2 8, msg_overflow
    jmp t08_done
t08_recovery:
    ; landed here because FP_ERROR_PROC's stack-smashing unwind
    ; brought us here directly (see lib_fp_error.s's own header for
    ; the setjmp/longjmp-style mechanism) - confirm it's the SPECIFIC
    ; error expected (code 0), not merely that *some* trap fired
    lda FP_ERROR_CODE
    cmp #0
    bne t08_wrong_code
    TEST_PASSED_MACRO_V2 8, msg_overflow
    jmp t08_done
t08_wrong_code:
    TEST_FAILED_MACRO_V2 8, msg_overflow
t08_done:

    ; --- T09: EDGE CASE - magnitude underflow, the deliberate mirror
    ;          of T08. "1E-100" asks for 10^-100 - equally far outside
    ;          this format's range, but in the OPPOSITE direction.
    ;          This library's documented convention (see lib_fp.s's
    ;          own ERROR/OVERFLOW HANDLING note) is that underflow is
    ;          SILENT - no trap, the result is simply set to 0.0. No
    ;          FP_ERROR_INIT_MACRO guard is armed here on purpose: if
    ;          this input actually trapped, the whole test suite would
    ;          stop dead right here with no recovery point armed -
    ;          itself a blunt but real confirmation that the
    ;          documented "underflow never traps" behaviour holds. ---
    lda #<str_t09_in
    ldy #>str_t09_in
    jsr FP_FROM_ASCII_SCI
    lda FP1_EXP
    bne t09_fail                    ; nonzero exponent: did NOT settle
                                    ; to canonical zero as documented
    TEST_PASSED_MACRO_V2 9, msg_underflow
    jmp t09_done
t09_fail:
    TEST_FAILED_MACRO_V2 9, msg_underflow
t09_done:

    ; --- T10: EDGE CASE - "no number" at all. An empty string has no
    ;          mantissa digits whatsoever, so this confirms
    ;          FP_FROM_ASCII_SCI_PROC's documented carry-set contract
    ;          (matching FP_FROM_ASCII24_PROC's own Exit note) holds,
    ;          and that FP1 is genuinely left at 0.0 rather than some
    ;          leftover partial value from earlier arithmetic. ---
    lda #<str_t10_in
    ldy #>str_t10_in
    jsr FP_FROM_ASCII_SCI
    bcc t10_fail                    ; carry clear: WRONGLY reported
                                    ; "found a digit" for an empty
                                    ; string
    lda FP1_EXP
    bne t10_fail                    ; carry correct, but FP1 wasn't
                                    ; actually left at 0.0
    TEST_PASSED_MACRO_V2 10, msg_nodigits
    jmp t10_done
t10_fail:
    TEST_FAILED_MACRO_V2 10, msg_nodigits
t10_done:

    rts

.segment "RODATA"
msg_to:         .asciiz "asciisci to"
msg_from:       .asciiz "asciisci from"
msg_roundtrip:  .asciiz "asciisci roundtrip"
msg_overflow:   .asciiz "asciisci overflow trap"
msg_underflow:  .asciiz "asciisci underflow"
msg_nodigits:   .asciiz "asciisci no digits"
;
; --- no letters in these - .asciiz's translation is harmless either
;     way (digits/punctuation are untouched by .charmap), so these
;     stay .asciiz for consistency with the rest of the codebase ---
str_150:        .asciiz "150"
str_zero:       .asciiz "0"
str_t04_in:     .asciiz "42.5"
;
; --- everything below contains an 'E'/'e' marker and a REAL,
;     specific byte matters - built with .literal (no charmap
;     translation - see this file's CHARMAP GOTCHA note), each
;     terminated with an explicit trailing $0 ---
str_t00_exp:    .literal "1E+02", $0
str_t01_exp:    .literal "1.5E+02", $0
;
str_t02_in:     .literal "-6.25E-02", $0    ; used as both input and
                                            ; expected output
;
str_t03_exp:    .literal "0.00E+00", $0
;
str_t04_exp:    .literal "4.2E+01", $0
;
str_t05_in:     .literal "5E3", $0
str_t05_exp:    .literal "5E+03", $0
;
str_t06_in:     .literal "5E-1", $0
str_t06_exp:    .literal "5E-01", $0
;
str_t07_in:     .literal "2.5e2", $0        ; genuine lowercase 'e' -
                                            ; real PETSCII $65, no
                                            ; translation trickery
                                            ; needed - see CHARMAP
                                            ; GOTCHA note
str_t07_exp:    .literal "2.5E+02", $0      ; output is always real
                                            ; uppercase 'E' ($45)
                                            ; regardless of which
                                            ; marker byte the input
                                            ; used
;
; --- edge-case inputs (T08-T10) ---
str_t08_in:     .literal "1E100", $0        ; magnitude overflow
str_t09_in:     .literal "1E-100", $0       ; magnitude underflow
str_t10_in:     .literal $0                 ; empty string - "no
                                            ; number" at all, just
                                            ; the null terminator
.endproc
