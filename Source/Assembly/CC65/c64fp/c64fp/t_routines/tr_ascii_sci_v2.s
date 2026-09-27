
.include "tr.inc"

.export tr_ascii_sci_v2

.import FP_FROM_ASCII_SCI_V2, FP_TO_ASCII_SCI_V2
.import TEST_STRCMP, TEST_PASSED, TEST_FAILED

; ============================================================
; FILE    : tr_ascii_sci_v2.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; Regression coverage for FP_FROM_ASCII_SCI_V2_PROC
; (lib_fp_from_ascii_sci_v2.s) - the significant-digits + decimal-
; exponent replacement for FP_FROM_ASCII_SCI_PROC. Two groups of
; tests:
;
;   T00-T09  PARITY - the same shapes of input tr_ascii_sci.s's own
;            T00-T10 already exercise against the ORIGINAL routine
;            (basic values, round trips, both exponent signs, both
;            marker cases, and the overflow/underflow/no-digits
;            edge cases), re-run here against the NEW routine, to
;            confirm the rewrite didn't change behaviour for any
;            input the original already handled correctly.
;   T10-T14  THE ACTUAL FIX - inputs chosen specifically to exercise
;            the two bugs lib_fp_from_ascii_sci_v2.s's own header
;            documents (a long fractional digit string; the exact
;            "2.2E38" case that motivated this whole file), plus a
;            near-ceiling/over-ceiling pair confirming the fix
;            reaches all the way up to this format's REAL limit
;            without having quietly widened what counts as "in
;            range".
;
; WHY FP_TO_ASCII_SCI_V2 (UNCHANGED, ALREADY PROVEN) IS THE
; VERIFICATION INSTRUMENT HERE
; -----------------------------------------------------------------
; This file only imports FP_FROM_ASCII_SCI_V2 as the thing under
; test - FP_TO_ASCII_SCI_PROC (lib_fp_to_ascii_sci.s) is reused
; completely unmodified as the READOUT mechanism, exactly the same
; role it already plays in tr_ascii_sci.s. That file's own T00-T07
; already establish FP_TO_ASCII_SCI_PROC's own correctness
; independently of anything this file does, so a mismatch here
; points at FP_FROM_ASCII_SCI_V2_PROC (the new code), not at the
; readout - the same "keep the thing being verified separate from
; the thing doing the verifying" reasoning lib_fp_compare.s's own
; header applies to FP_FSUB/FP_COMPARE_PROC's relationship.
;
; A CAVEAT WORTH FLAGGING, NOT FIXING HERE
; -----------------------------------------------------------------
; FP_TO_ASCII_SCI_PROC's own normalize loop (lib_fp_to_ascii_sci.s)
; is a SERIAL divide-by-10 loop, structurally the same shape as the
; scaling loop THIS file's whole reason for existing just replaced
; on the parsing side - for a value sitting very near this format's
; real exponent ceiling, that loop could in principle need close to
; as many steps, with the same theoretical compounding-error
; exposure. T11/T12 below therefore verify FP_FROM_ASCII_SCI_V2_PROC's
; OWN output (FP1's raw exponent byte) directly rather than trusting
; a full round-trip through FP_TO_ASCII_SCI_PROC for their pass/fail
; condition, specifically to keep this file's verification from
; depending on that unaudited code path. Whether
; FP_TO_ASCII_SCI_PROC's own normalize loop needs the same binary-
; exponentiation treatment is worth a follow-up, but is out of scope
; for what was asked here.
;
; VERIFICATION STATUS - READ BEFORE TRUSTING THESE
; -----------------------------------------------------------------
; Every expected value below is hand/Python-derived (see
; lib_fp_from_ascii_sci_v2.s's own WORKED EXAMPLE entries for T10's
; and T14's arithmetic in particular), not yet confirmed against
; actual VICE or C64U output. Per this project's usual workflow,
; run this group, compare the PASS/FAIL output against what's
; expected here, and correct either the test or the routine if
; reality differs.
;
; TEST INVENTORY
; -----------------
;   T00  basic value, no exponent suffix ("150")
;   T01  round trip, negative mantissa + negative exponent
;   T02  canonical zero
;   T03  ordinary decimal, no exponent suffix at all ("42.5")
;   T04  positive exponent, no digit-sign on 'E'
;   T05  negative exponent, no digit-sign on 'E'
;   T06  genuine lowercase 'e' exponent marker
;   T07  EDGE CASE: magnitude overflow ("1E100") - must trap, code 0
;   T08  EDGE CASE: magnitude underflow ("1E-100") - must NOT trap
;   T09  EDGE CASE: "no number" - empty string, carry set expected
;   T10  THE FIX, bug #1: a 39-digit fractional string that would
;        build an oversized intermediate under the OLD routine's
;        unbounded Horner accumulation - must not trap, and its
;        first few significant digits must be correct
;   T11  THE FIX, bug #2: "2.2E38" itself - the exact input that
;        spuriously overflowed under the OLD routine's 38-step
;        serial scaling loop - must not trap
;   T12  boundary companion to T11: "3.40E38", closer still to this
;        format's real ceiling (~3.402823264e38) but still validly
;        inside it - must not trap
;   T13  boundary companion to T12: "3.5E38", genuinely PAST this
;        format's real ceiling - MUST trap. Paired deliberately with
;        T11/T12 to confirm the fix reaches the format's real limit
;        without having quietly stopped rejecting anything at all
;   T14  bug #1's INTEGER-side counterpart: a 15-digit integer part,
;        confirming dropped-integer-digit k_value bookkeeping (not
;        just the dropped-fractional-digit side T10 exercises)
; ============================================================
.segment "CODE"
.proc tr_ascii_sci_v2
    TEST_ROUTINE_HEADER_MACRO msg_header
    
    ; --- T00: basic value, no exponent suffix at all ---
    lda #<str_150
    ldy #>str_150
    jsr FP_FROM_ASCII_SCI_V2
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #1
    jsr FP_TO_ASCII_SCI_V2
    TEST_STRCMP_MACRO_V2 0, msg_roundtrip, str_t00_exp

    ; --- T01: round trip, negative mantissa + negative exponent -
    ;          same value as tr_ascii_sci.s's own T02, re-run here
    ;          against the new routine ---
    lda #<str_t01_in
    ldy #>str_t01_in
    jsr FP_FROM_ASCII_SCI_V2
    bcs t01_fail
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII_SCI_V2
    TEST_STRCMP_MACRO_V2 1, msg_roundtrip, str_t01_in
    jmp t01_done
t01_fail:
    TEST_FAILED_MACRO_V2 1, msg_roundtrip
t01_done:

    ; --- T02: canonical zero ---
    lda #<str_zero
    ldy #>str_zero
    jsr FP_FROM_ASCII_SCI_V2
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII_SCI_V2
    TEST_STRCMP_MACRO_V2 2, msg_roundtrip, str_t02_exp

    ; --- T03: ordinary decimal, no exponent suffix ("42.5") ---
    lda #<str_t03_in
    ldy #>str_t03_in
    jsr FP_FROM_ASCII_SCI_V2
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #1
    jsr FP_TO_ASCII_SCI_V2
    TEST_STRCMP_MACRO_V2 3, msg_roundtrip, str_t03_exp

    ; --- T04: positive exponent, no digit-sign on 'E' ("5E3") ---
    lda #<str_t04_in
    ldy #>str_t04_in
    jsr FP_FROM_ASCII_SCI_V2
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #0
    jsr FP_TO_ASCII_SCI_V2
    TEST_STRCMP_MACRO_V2 4, msg_roundtrip, str_t04_exp

    ; --- T05: negative exponent, no digit-sign on 'E' ("5E-1") ---
    lda #<str_t05_in
    ldy #>str_t05_in
    jsr FP_FROM_ASCII_SCI_V2
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #0
    jsr FP_TO_ASCII_SCI_V2
    TEST_STRCMP_MACRO_V2 5, msg_roundtrip, str_t05_exp

    ; --- T06: genuine lowercase 'e' exponent marker ("2.5e2") -
    ;          real PETSCII $65, built via .literal per this whole
    ;          family's CHARMAP GOTCHA precedent (see tr_ascii_sci.s
    ;          for the full history of why .literal, not .asciiz,
    ;          is required for any string containing a specific
    ;          'E'/'e' byte that matters) ---
    lda #<str_t06_in
    ldy #>str_t06_in
    jsr FP_FROM_ASCII_SCI_V2
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #1
    jsr FP_TO_ASCII_SCI_V2
    TEST_STRCMP_MACRO_V2 6, msg_roundtrip, str_t06_exp

    ; --- T07: EDGE CASE - magnitude overflow ("1E100"). Same
    ;          contract as tr_ascii_sci.s's own T08 - traps via
    ;          FP_FMUL's generic-overflow path (code 0) partway
    ;          through the scaling loop, propagating to the guard
    ;          armed here since this routine installs none of its
    ;          own (see its file header's ERROR HANDLING note). ---
    FP_ERROR_INIT_MACRO t07_recovery
    lda #<str_t07_in
    ldy #>str_t07_in
    jsr FP_FROM_ASCII_SCI_V2
    FP_ERROR_CLEAR_MACRO            ; reached only if NO trap fired -
                                    ; the failure case, since this
                                    ; input exists purely to overflow
    TEST_FAILED_MACRO_V2 7, msg_overflow
    jmp t07_done
t07_recovery:
    lda FP_ERROR_CODE
    cmp #0
    bne t07_wrong_code
    TEST_PASSED_MACRO_V2 7, msg_overflow
    jmp t07_done
t07_wrong_code:
    TEST_FAILED_MACRO_V2 7, msg_overflow
t07_done:

    ; --- T08: EDGE CASE - magnitude underflow ("1E-100"). Must NOT
    ;          trap - this library's documented convention is that
    ;          underflow silently settles to 0.0 (see lib_fp.s's own
    ;          ERROR/OVERFLOW HANDLING note). Deliberately un-guarded,
    ;          same reasoning as tr_ascii_sci.s's own T09: if this
    ;          DID trap with no recovery armed, the whole suite
    ;          stopping dead right here is itself a blunt but real
    ;          confirmation that the documented behaviour doesn't
    ;          hold. ---
    lda #<str_t08_in
    ldy #>str_t08_in
    jsr FP_FROM_ASCII_SCI_V2
    lda FP1_EXP
    bne t08_fail
    TEST_PASSED_MACRO_V2 8, msg_underflow
    jmp t08_done
t08_fail:
    TEST_FAILED_MACRO_V2 8, msg_underflow
t08_done:

    ; --- T09: EDGE CASE - "no number" at all. Empty string, no
    ;          mantissa digits whatsoever - confirms the documented
    ;          carry-set contract holds for this routine too, and
    ;          that FP1 is genuinely left at 0.0. ---
    lda #<str_t09_in
    ldy #>str_t09_in
    jsr FP_FROM_ASCII_SCI_V2
    bcc t09_fail                    ; carry clear: WRONGLY reported
                                    ; "found a digit" for an empty
                                    ; string
    lda FP1_EXP
    bne t09_fail
    TEST_PASSED_MACRO_V2 9, msg_nodigits
    jmp t09_done
t09_fail:
    TEST_FAILED_MACRO_V2 9, msg_nodigits
t09_done:

    ; --- T10: THE FIX, bug #1 - a 39-digit fractional string. Under
    ;          the OLD routine (FP_FROM_ASCII_SCI_PROC), every one
    ;          of these digits would feed the SAME unbounded Horner
    ;          accumulator, building a 39-digit intermediate that
    ;          could itself overflow even though the true value
    ;          (~0.123...) is utterly ordinary. This routine collects
    ;          only the first 9 significant digits (123456789) and
    ;          drops the remaining 30 without accumulating them - see
    ;          lib_fp_from_ascii_sci_v2.s's own WORKED EXAMPLE for the
    ;          "0.000123"-style trace this generalizes from.
    ;          Verified to only 2 fractional digits ("1.23E-01")
    ;          deliberately, not further - the LEADING few digits of
    ;          a 9-digit Horner accumulation are far more reliably
    ;          predictable by hand than the trailing ones (truncation
    ;          error concentrates in the low-order bits, i.e. the
    ;          LAST couple of the 9 collected decimal digits), so
    ;          this checks exactly what can be predicted with
    ;          confidence without needing bit-exact truncation
    ;          behaviour worked out by hand. Guarded with
    ;          FP_ERROR_INIT_MACRO defensively (not because a trap is
    ;          expected - it isn't - but so a residual bug here
    ;          reports a clean FAIL instead of halting the whole
    ;          suite, unlike T08's deliberately-unguarded underflow
    ;          check above). ---
    FP_ERROR_INIT_MACRO t10_recovery
    lda #<str_t10_in
    ldy #>str_t10_in
    jsr FP_FROM_ASCII_SCI_V2
    FP_ERROR_CLEAR_MACRO
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII_SCI_V2
    TEST_STRCMP_MACRO_V2 10, msg_longfrac, str_t10_exp
    jmp t10_done
t10_recovery:
    TEST_FAILED_MACRO_V2 10, msg_longfrac
t10_done:

    ; --- T11: THE FIX, bug #2 - "2.2E38" itself, the exact input
    ;          that motivated this whole file (confirmed on hardware
    ;          to spuriously trap under the OLD routine's 38-step
    ;          serial scaling loop, despite 2.2e38 sitting
    ;          comfortably under this format's real ~3.402823264e38
    ;          ceiling). Verified directly against FP1's own raw
    ;          exponent byte rather than through a full
    ;          FP_TO_ASCII_SCI_V2 round trip - see this file's own A
    ;          CAVEAT WORTH FLAGGING header note for why. 2.2e38 sits
    ;          just past 2^127 (~1.701e38) - true binary exponent 127,
    ;          excess-128 byte $FF, this format's own maximum
    ;          exponent byte (see labels_fp.s's own "EXPONENT $FF -
    ;          FULLY VALID AND SAFE" note - landing exactly there is
    ;          expected, not a boundary bug). Checked against a
    ;          slightly looser >= $F0 threshold rather than an exact
    ;          $FF match, to allow for whatever small, ordinary
    ;          rounding the 3-multiplication scaling chain (32+4+1)
    ;          itself introduces without making this test more
    ;          brittle than the thing it's actually trying to catch
    ;          (a GROSS error - wrong-by-many-powers-of-2 - not a
    ;          one-ULP rounding difference). ---
    FP_ERROR_INIT_MACRO t11_recovery
    lda #<str_t11_in
    ldy #>str_t11_in
    jsr FP_FROM_ASCII_SCI_V2
    FP_ERROR_CLEAR_MACRO
    lda FP1_EXP
    cmp #$f0
    bcc t11_fail
    TEST_PASSED_MACRO_V2 11, msg_bigexp
    jmp t11_done
t11_recovery:
    TEST_FAILED_MACRO_V2 11, msg_bigexp
    jmp t11_done
t11_fail:
    TEST_FAILED_MACRO_V2 11, msg_bigexp
t11_done:

    ; --- T12: boundary companion to T11 - "3.40E38", closer still to
    ;          this format's real ceiling but still validly inside
    ;          it. Same verification approach as T11. ---
    FP_ERROR_INIT_MACRO t12_recovery
    lda #<str_t12_in
    ldy #>str_t12_in
    jsr FP_FROM_ASCII_SCI_V2
    FP_ERROR_CLEAR_MACRO
    lda FP1_EXP
    cmp #$f0
    bcc t12_fail
    TEST_PASSED_MACRO_V2 12, msg_nearceil
    jmp t12_done
t12_recovery:
    TEST_FAILED_MACRO_V2 12, msg_nearceil
    jmp t12_done
t12_fail:
    TEST_FAILED_MACRO_V2 12, msg_nearceil
t12_done:

    ; --- T13: boundary companion to T12 - "3.5E38", genuinely PAST
    ;          this format's real ceiling. MUST trap - paired
    ;          deliberately with T11/T12 to confirm this fix reaches
    ;          the format's actual limit without having quietly
    ;          widened what counts as "in range" (i.e. this isn't
    ;          "accept everything now", it's "correctly accept
    ;          everything the format can actually hold, and still
    ;          correctly reject what it can't"). ---
    FP_ERROR_INIT_MACRO t13_recovery
    lda #<str_t13_in
    ldy #>str_t13_in
    jsr FP_FROM_ASCII_SCI_V2
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 13, msg_overceil
    jmp t13_done
t13_recovery:
    lda FP_ERROR_CODE
    cmp #0
    bne t13_wrong_code
    TEST_PASSED_MACRO_V2 13, msg_overceil
    jmp t13_done
t13_wrong_code:
    TEST_FAILED_MACRO_V2 13, msg_overceil
t13_done:

    ; --- T14: bug #1's INTEGER-side counterpart - a 15-digit integer
    ;          part (no decimal point at all), confirming the
    ;          budget_full branch's "dropped INTEGER digit still
    ;          bumps k_value" bookkeeping (T10 only exercises the
    ;          fractional-side "dropped digit contributes nothing"
    ;          branch) - see lib_fp_from_ascii_sci_v2.s's own
    ;          "123456789012.5" WORKED EXAMPLE, which this is a
    ;          close relative of. Checked with 0 fractional digits,
    ;          for the same "only the reliably-predictable leading
    ;          digit" reasoning as T10. ---
    lda #<str_t14_in
    ldy #>str_t14_in
    jsr FP_FROM_ASCII_SCI_V2
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #0
    jsr FP_TO_ASCII_SCI_V2
    TEST_STRCMP_MACRO_V2 14, msg_longint, str_t14_exp

    ; ------------------------------------------------------------
    ; T15-T19: FP_FMUL CEILING BOUNDARY SWEEP (V2)
    ; ------------------------------------------------------------
    ; lib_fp_from_ascii_sci_v2.s's own header ("FP_FMUL BOUNDARY
    ; LIMITATION") documents a pre-existing pre-normalization overflow
    ; check inside FP_CORE_PROC's multiply path that rejects any
    ; multiplication whose operands' true exponent sum is >= 127.
    ; The header's empirical claim: values 1.0E38 through 2.0E38
    ; succeed, and EVERY value from 2.1E38 up (well into the format's
    ; own valid range) TRAPS. This sweep pins where that boundary
    ; actually falls, so a future fix (or a discovered mismatch
    ; between code and header) is visible immediately.
    ;
    ; NOTE: these tests deliberately CONTRADICT the existing T11/T12
    ; (which expect 2.2E38 and 3.40E38 to NOT trap). Whichever pair
    ; is correct, exactly one set will fail - that failure IS the
    ; diagnostic. Reconcile afterwards by either fixing the failing
    ; tests to match reality, or fixing V2 to match the header's
    ; stated "no traps up to the format's real ceiling" intent (the
    ; latter is what V3 exists to do).

    ; --- T15: "2.0E38" - upper edge of V2's documented OK range ---
    FP_ERROR_INIT_MACRO t15_recovery
    lda #<str_t15_in
    ldy #>str_t15_in
    jsr FP_FROM_ASCII_SCI_V2
    FP_ERROR_CLEAR_MACRO
    lda FP1_EXP
    cmp #$f0
    bcc t15_fail
    TEST_PASSED_MACRO_V2 15, msg_200e38
    jmp t15_done
t15_recovery:
    TEST_FAILED_MACRO_V2 15, msg_200e38
    jmp t15_done
t15_fail:
    TEST_FAILED_MACRO_V2 15, msg_200e38
t15_done:

    ; --- T16: "2.1E38" - the value V2's ORIGINAL header claimed
    ; V2 traps on. It doesn't. Confirmed via the boundary sweep run
    ; that produced these replacements: V2 outputs $FF,$4E,$FE,$42
    ; for this input without trapping. See lib_fp_from_ascii_sci_v2.s's
    ; corrected FP_FMUL BOUNDARY section. ---
    FP_ERROR_INIT_MACRO t16_recovery
    lda #<str_t16_in
    ldy #>str_t16_in
    jsr FP_FROM_ASCII_SCI_V2
    FP_ERROR_CLEAR_MACRO
    lda FP1_EXP
    cmp #$f0
    bcc t16_fail
    TEST_PASSED_MACRO_V2 16, msg_210e38
    jmp t16_done
t16_recovery:
    TEST_FAILED_MACRO_V2 16, msg_210e38
    jmp t16_done
t16_fail:
    TEST_FAILED_MACRO_V2 16, msg_210e38
t16_done:

    ; --- T17: "3.0E38" - also NOT trapped by V2, contrary to the
    ; original header. Observed output: $FF,$70,$D8,$F0. ---
    FP_ERROR_INIT_MACRO t17_recovery
    lda #<str_t17_in
    ldy #>str_t17_in
    jsr FP_FROM_ASCII_SCI_V2
    FP_ERROR_CLEAR_MACRO
    lda FP1_EXP
    cmp #$f0
    bcc t17_fail
    TEST_PASSED_MACRO_V2 17, msg_300e38
    jmp t17_done
t17_recovery:
    TEST_FAILED_MACRO_V2 17, msg_300e38
    jmp t17_done
t17_fail:
    TEST_FAILED_MACRO_V2 17, msg_300e38
t17_done:

    ; --- T18: "3.4028E38" - right at the format's true ceiling,
    ; just below the 3.402823264e38 limit. V2 handles it; observed
    ; output $FF,$7F,$FF,$C2. The next test (T19) confirms V2 still
    ; traps one step past this, so this isn't "V2 stopped checking
    ; range" - it's "V2's boundary is exactly where the header says
    ; the FORMAT's boundary is, not where the old header text
    ; claimed V2's own boundary was". ---
    FP_ERROR_INIT_MACRO t18_recovery
    lda #<str_t18_in
    ldy #>str_t18_in
    jsr FP_FROM_ASCII_SCI_V2
    FP_ERROR_CLEAR_MACRO
    lda FP1_EXP
    cmp #$f0
    bcc t18_fail
    TEST_PASSED_MACRO_V2 18, msg_34028e38
    jmp t18_done
t18_recovery:
    TEST_FAILED_MACRO_V2 18, msg_34028e38
    jmp t18_done
t18_fail:
    TEST_FAILED_MACRO_V2 18, msg_34028e38
t18_done:

    ; --- T19: "3.403E38" - just PAST the format's true ceiling.
    ; V2 traps here, and this is the CORRECT behaviour - past the
    ; ceiling is genuine overflow, not the spurious kind. Paired
    ; with T18 to show the boundary is exactly at the format's own
    ; limit, not lower. ---
    FP_ERROR_INIT_MACRO t19_recovery
    lda #<str_t19_in
    ldy #>str_t19_in
    jsr FP_FROM_ASCII_SCI_V2
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 19, msg_3403e38
    jmp t19_done
t19_recovery:
    lda FP_ERROR_CODE
    cmp #0
    bne t19_wrong_code
    TEST_PASSED_MACRO_V2 19, msg_3403e38
    jmp t19_done
t19_wrong_code:
    TEST_FAILED_MACRO_V2 19, msg_3403e38
t19_done:
    rts

.segment "RODATA"
msg_header:     .asciiz "conversion: ascii scientific v2"
msg_roundtrip:  .asciiz "roundtrip"
msg_overflow:   .asciiz "overflow trap"
msg_underflow:  .asciiz "underflow"
msg_nodigits:   .asciiz "no digits"
msg_longfrac:   .asciiz "long frac"
msg_bigexp:     .asciiz "2.2e38"
msg_nearceil:   .asciiz "near ceiling"
msg_overceil:   .asciiz "over ceiling"
msg_longint:    .asciiz "long integer"
;msg_boundary:   .asciiz "(1.9e+38) -> fp"
;
; --- no letters in these - .asciiz's translation is harmless either
;     way (see tr_ascii_sci.s's own CHARMAP GOTCHA note) ---
str_150:        .asciiz "150"
str_zero:       .asciiz "0"
str_t03_in:     .asciiz "42.5"
str_t10_in:     .asciiz "0.123456789012345678901234567890123456789"
str_t14_in:     .asciiz "123456789012345"
;
; --- everything below contains an 'E'/'e' marker - built with
;     .literal (no charmap translation), terminated with an
;     explicit trailing $0 - see tr_ascii_sci.s's CHARMAP GOTCHA
;     note for the full history of why ---
str_t00_exp:    .literal "1.5E+02", $0
;
str_t01_in:     .literal "-6.25E-02", $0    ; used as both input and
                                            ; expected output
;
str_t02_exp:    .literal "0.00E+00", $0
;
str_t03_exp:    .literal "4.2E+01", $0
;
str_t04_in:     .literal "5E3", $0
str_t04_exp:    .literal "5E+03", $0
;
str_t05_in:     .literal "5E-1", $0
str_t05_exp:    .literal "5E-01", $0
;
str_t06_in:     .literal "2.5e2", $0        ; genuine lowercase 'e'
str_t06_exp:    .literal "2.5E+02", $0
;
str_t07_in:     .literal "1E100", $0        ; magnitude overflow
;
str_t08_in:     .literal "1E-100", $0       ; magnitude underflow
;
str_t09_in:     .literal $0                 ; empty string
;
str_t10_exp:    .literal "1.23E-01", $0
;
str_t11_in:     .literal "2.2E38", $0       ; THE motivating case
str_t12_in:     .literal "3.40E38", $0      ; valid, near ceiling
str_t13_in:     .literal "3.5E38", $0       ; invalid, over ceiling
;
str_t14_exp:    .literal "1E+14", $0

;
msg_200e38:     .asciiz "2.0e38"
msg_210e38:     .asciiz "2.1e38"
msg_300e38:     .asciiz "3.0e38"
msg_34028e38:   .asciiz "3.4028e38"
msg_3403e38:    .asciiz "3.403e38"
str_t15_in:     .literal "2.0E38", $0
str_t16_in:     .literal "2.1E38", $0
str_t17_in:     .literal "3.0E38", $0
str_t18_in:     .literal "3.4028E38", $0
str_t19_in:     .literal "3.403E38", $0
.endproc
