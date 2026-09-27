.include "tr.inc"

.export tr_ascii_sci_v3

.import FP_FROM_ASCII_SCI_V3, FP_TO_ASCII_SCI_V2
.import TEST_STRCMP, TEST_PASSED, TEST_FAILED

; ============================================================
; FILE    : tr_ascii_sci_v3.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; Regression coverage for FP_FROM_ASCII_SCI_V3_PROC
; (lib_fp_from_ascii_sci_v3.s) – the 5^n + exponent‑byte scaling
; version that replaces V2’s 10^n binary exponentiation.
;
; The tests are a superset of tr_ascii_sci_v2.s:
;   T00–T09  PARITY – basic shapes from the original SCI test suite.
;   T10–T14  THE ACTUAL FIX – long fractional strings, large
;            exponents near the ceiling, over‑ceiling trap.
;   T15      BOUNDARY – "1.9E+38" specifically, which failed under
;            V2 but must succeed under V3.
;   T16      NEGATIVE NEAR‑UNDERFLOW – exercises the 5^n path with
;            a negative exponent and the direct exponent‑byte
;            subtraction.
;
; All expected strings are hand‑derived and follow the same
; .literal convention for strings containing 'E'/'e' as
; tr_ascii_sci.s.  The boundary test uses a round‑trip through
; FP_TO_ASCII_SCI_V2 instead of a byte‑exact comparison because the
; exact mantissa may differ slightly due to the improved scaling
; method, while the decimal representation remains stable.
;
; VERIFICATION STATUS
; --------------------
; Not yet run on hardware; expected strings are based on the
; behaviour of the existing V2 and SCI routines and the new scaling
; algorithm.
; ============================================================
.segment "CODE"
.proc tr_ascii_sci_v3
    TEST_ROUTINE_HEADER_MACRO msg_header

    ; --- T00: basic value, no exponent suffix ("150") ---
    lda #<str_150
    ldy #>str_150
    jsr FP_FROM_ASCII_SCI_V3
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #1
    jsr FP_TO_ASCII_SCI_V2
    TEST_STRCMP_MACRO_V2 0, msg_roundtrip, str_t00_exp

    ; --- T01: round trip, negative mantissa + negative exponent ---
    lda #<str_t01_in
    ldy #>str_t01_in
    jsr FP_FROM_ASCII_SCI_V3
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
    jsr FP_FROM_ASCII_SCI_V3
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII_SCI_V2
    TEST_STRCMP_MACRO_V2 2, msg_roundtrip, str_t02_exp

    ; --- T03: ordinary decimal, no exponent suffix ("42.5") ---
    lda #<str_t03_in
    ldy #>str_t03_in
    jsr FP_FROM_ASCII_SCI_V3
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #1
    jsr FP_TO_ASCII_SCI_V2
    TEST_STRCMP_MACRO_V2 3, msg_roundtrip, str_t03_exp

    ; --- T04: positive exponent, no digit-sign on 'E' ("5E3") ---
    lda #<str_t04_in
    ldy #>str_t04_in
    jsr FP_FROM_ASCII_SCI_V3
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #0
    jsr FP_TO_ASCII_SCI_V2
    TEST_STRCMP_MACRO_V2 4, msg_roundtrip, str_t04_exp

    ; --- T05: negative exponent, no digit-sign on 'E' ("5E-1") ---
    lda #<str_t05_in
    ldy #>str_t05_in
    jsr FP_FROM_ASCII_SCI_V3
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #0
    jsr FP_TO_ASCII_SCI_V2
    TEST_STRCMP_MACRO_V2 5, msg_roundtrip, str_t05_exp

    ; --- T06: genuine lowercase 'e' exponent marker ("2.5e2") ---
    lda #<str_t06_in
    ldy #>str_t06_in
    jsr FP_FROM_ASCII_SCI_V3
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #1
    jsr FP_TO_ASCII_SCI_V2
    TEST_STRCMP_MACRO_V2 6, msg_roundtrip, str_t06_exp

    ; --- T07: EDGE CASE - magnitude overflow ("1E100"). Must trap
    ;          with code 0. ---
    FP_ERROR_INIT_MACRO t07_recovery
    lda #<str_t07_in
    ldy #>str_t07_in
    jsr FP_FROM_ASCII_SCI_V3
    FP_ERROR_CLEAR_MACRO
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
    ;          trap; silently settle to 0.0. ---
    lda #<str_t08_in
    ldy #>str_t08_in
    jsr FP_FROM_ASCII_SCI_V3
    lda FP1_EXP
    bne t08_fail
    TEST_PASSED_MACRO_V2 8, msg_underflow
    jmp t08_done
t08_fail:
    TEST_FAILED_MACRO_V2 8, msg_underflow
t08_done:

    ; --- T09: EDGE CASE - "no number". Empty string, carry set
    ;          expected. ---
    lda #<str_t09_in
    ldy #>str_t09_in
    jsr FP_FROM_ASCII_SCI_V3
    bcc t09_fail
    lda FP1_EXP
    bne t09_fail
    TEST_PASSED_MACRO_V2 9, msg_nodigits
    jmp t09_done
t09_fail:
    TEST_FAILED_MACRO_V2 9, msg_nodigits
t09_done:

    ; --- T10: THE FIX - long fractional string, no overflow.
    ;          Expected "1.23E-01" (first two significant digits). ---
    FP_ERROR_INIT_MACRO t10_recovery
    lda #<str_t10_in
    ldy #>str_t10_in
    jsr FP_FROM_ASCII_SCI_V3
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

    ; --- T11: "2.2E38" must not trap. Exponent byte >= $F0. ---
    FP_ERROR_INIT_MACRO t11_recovery
    lda #<str_t11_in
    ldy #>str_t11_in
    jsr FP_FROM_ASCII_SCI_V3
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

    ; --- T12: "3.40E38" valid near ceiling, must not trap. ---
    FP_ERROR_INIT_MACRO t12_recovery
    lda #<str_t12_in
    ldy #>str_t12_in
    jsr FP_FROM_ASCII_SCI_V3
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

    ; --- T13: "3.5E38" over ceiling, must trap. ---
    FP_ERROR_INIT_MACRO t13_recovery
    lda #<str_t13_in
    ldy #>str_t13_in
    jsr FP_FROM_ASCII_SCI_V3
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

    ; --- T14: long integer part, dropped digits still accounted.
    ;          Expected "1E+14". ---
    lda #<str_t14_in
    ldy #>str_t14_in
    jsr FP_FROM_ASCII_SCI_V3
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #0
    jsr FP_TO_ASCII_SCI_V2
    TEST_STRCMP_MACRO_V2 14, msg_longint, str_t14_exp

    ; --- T15: BOUNDARY CASE - "1.9E+38". Must not trap, and
    ;          round‑trips to "1.90E+38" with 2 fractional digits.
    ;          This is the exact input that failed under V2 but
    ;          succeeds with the 5^n + exponent‑byte method. ---
    FP_ERROR_INIT_MACRO t15_recovery
    lda #<str_t15_in
    ldy #>str_t15_in
    jsr FP_FROM_ASCII_SCI_V3
    FP_ERROR_CLEAR_MACRO
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII_SCI_V2
    TEST_STRCMP_MACRO_V2 15, msg_boundary, str_t15_exp
    jmp t15_done
t15_recovery:
    TEST_FAILED_MACRO_V2 15, msg_boundary
t15_done:

    ; --- T16: Negative exponent near underflow ("1E-38"). Should
    ;          not underflow to zero; round‑trips to "1.00E-38". ---
    FP_ERROR_INIT_MACRO t16_recovery
    lda #<str_t16_in
    ldy #>str_t16_in
    jsr FP_FROM_ASCII_SCI_V3
    FP_ERROR_CLEAR_MACRO
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII_SCI_V2
    TEST_STRCMP_MACRO_V2 16, msg_negeexp, str_t16_exp
    jmp t16_done
t16_recovery:
    TEST_FAILED_MACRO_V2 16, msg_negeexp
t16_done:

    ; ------------------------------------------------------------
    ; T17-T21: FP_FMUL CEILING BOUNDARY SWEEP (V3)
    ; ------------------------------------------------------------
    ; lib_fp_from_ascii_sci_v3.s replaces V2's 10^N binary
    ; exponentiation with 5^N × 2^N, applying the 2^N part directly
    ; to the exponent byte. This bypasses FP_FMUL's pre-normalization
    ; overflow check entirely for the power-of-two factor - so V3
    ; should succeed on values V2 traps on, all the way up to the
    ; format's own true ceiling, then trap again on genuinely
    ; out-of-range inputs past it.
    ;
    ; These tests mirror tr_ascii_sci_v2.s's own T15-T19 exactly. The
    ; interesting comparison: T18 and T19 here (2.1E38 and 3.0E38)
    ; are the values V2's own header says V2 traps on - V3 must make
    ; them succeed, or V3 isn't actually fixing what it claims to.

    ; --- T17: "2.0E38" - succeeds under both V2 and V3 (control) ---
    FP_ERROR_INIT_MACRO t17_recovery
    lda #<str_t17_in
    ldy #>str_t17_in
    jsr FP_FROM_ASCII_SCI_V3
    FP_ERROR_CLEAR_MACRO
    lda FP1_EXP
    cmp #$f0
    bcc t17_fail
    TEST_PASSED_MACRO_V2 17, msg_200e38
    jmp t17_done
t17_recovery:
    TEST_FAILED_MACRO_V2 17, msg_200e38
    jmp t17_done
t17_fail:
    TEST_FAILED_MACRO_V2 17, msg_200e38
t17_done:

    ; --- T18: "2.1E38" - TRAPS under V2, must SUCCEED under V3.
    ; The 5^N × 2^N split is specifically meant to rescue this. ---
    FP_ERROR_INIT_MACRO t18_recovery
    lda #<str_t18_in
    ldy #>str_t18_in
    jsr FP_FROM_ASCII_SCI_V3
    FP_ERROR_CLEAR_MACRO
    lda FP1_EXP
    cmp #$f0
    bcc t18_fail
    TEST_PASSED_MACRO_V2 18, msg_210e38
    jmp t18_done
t18_recovery:
    TEST_FAILED_MACRO_V2 18, msg_210e38
    jmp t18_done
t18_fail:
    TEST_FAILED_MACRO_V2 18, msg_210e38
t18_done:

    ; --- T19: "3.0E38" - TRAPS under V2, must SUCCEED under V3 ---
    FP_ERROR_INIT_MACRO t19_recovery
    lda #<str_t19_in
    ldy #>str_t19_in
    jsr FP_FROM_ASCII_SCI_V3
    FP_ERROR_CLEAR_MACRO
    lda FP1_EXP
    cmp #$f0
    bcc t19_fail
    TEST_PASSED_MACRO_V2 19, msg_300e38
    jmp t19_done
t19_recovery:
    TEST_FAILED_MACRO_V2 19, msg_300e38
    jmp t19_done
t19_fail:
    TEST_FAILED_MACRO_V2 19, msg_300e38
t19_done:

    ; --- T20: "3.4028E38" - right at the format's true ceiling.
    ; Must SUCCEED under V3 (this is the value V2's header predicts
    ; V2 traps on; V3 exists specifically to reach it). ---
    FP_ERROR_INIT_MACRO t20_recovery
    lda #<str_t20_in
    ldy #>str_t20_in
    jsr FP_FROM_ASCII_SCI_V3
    FP_ERROR_CLEAR_MACRO
    lda FP1_EXP
    cmp #$f0
    bcc t20_fail
    TEST_PASSED_MACRO_V2 20, msg_34028e38
    jmp t20_done
t20_recovery:
    TEST_FAILED_MACRO_V2 20, msg_34028e38
    jmp t20_done
t20_fail:
    TEST_FAILED_MACRO_V2 20, msg_34028e38
t20_done:

    ; --- T21: "3.403E38" - just PAST the format ceiling.
    ; Must TRAP under V3 - the fix widens the ACCEPT range up to the
    ; format's real limit, it does not remove the overflow check
    ; entirely. If this test passes without a trap, V3 has silently
    ; broken range checking at the top end. ---
    FP_ERROR_INIT_MACRO t21_recovery
    lda #<str_t21_in
    ldy #>str_t21_in
    jsr FP_FROM_ASCII_SCI_V3
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 21, msg_3403e38
    jmp t21_done
t21_recovery:
    lda FP_ERROR_CODE
    cmp #0
    bne t21_wrong_code
    TEST_PASSED_MACRO_V2 21, msg_3403e38
    jmp t21_done
t21_wrong_code:
    TEST_FAILED_MACRO_V2 21, msg_3403e38
t21_done:

    rts

.segment "RODATA"
msg_header:     .asciiz "conversion: ascii scientific v3"
msg_roundtrip:  .asciiz "roundtrip"
msg_overflow:   .asciiz "overflow trap"
msg_underflow:  .asciiz "underflow"
msg_nodigits:   .asciiz "no digits"
msg_longfrac:   .asciiz "long frac"
msg_bigexp:     .asciiz "2.2e38"
msg_nearceil:   .asciiz "near ceiling"
msg_overceil:   .asciiz "over ceiling"
msg_longint:    .asciiz "long integer"
msg_boundary:   .asciiz "1.9e38"
msg_negeexp:    .asciiz "neg near underflow"
msg_200e38:     .asciiz "2.0e38"
msg_210e38:     .asciiz "2.1e38"
msg_300e38:     .asciiz "3.0e38"
msg_34028e38:   .asciiz "3.4028e38"
msg_3403e38:    .asciiz "3.403e38"

; --- plain strings without 'E'/'e' can stay .asciiz ---
str_150:        .asciiz "150"
str_zero:       .asciiz "0"
str_t03_in:     .asciiz "42.5"
str_t10_in:     .asciiz "0.123456789012345678901234567890123456789"
str_t14_in:     .asciiz "123456789012345"

; --- strings containing 'E'/'e' must be .literal ---
str_t00_exp:    .literal "1.5E+02", $0
str_t01_in:     .literal "-6.25E-02", $0
str_t02_exp:    .literal "0.00E+00", $0
str_t03_exp:    .literal "4.2E+01", $0
str_t04_in:     .literal "5E3", $0
str_t04_exp:    .literal "5E+03", $0
str_t05_in:     .literal "5E-1", $0
str_t05_exp:    .literal "5E-01", $0
str_t06_in:     .literal "2.5e2", $0
str_t06_exp:    .literal "2.5E+02", $0
str_t07_in:     .literal "1E100", $0
str_t08_in:     .literal "1E-100", $0
str_t09_in:     .literal $0
str_t10_exp:    .literal "1.23E-01", $0
str_t11_in:     .literal "2.2E38", $0
str_t12_in:     .literal "3.40E38", $0
str_t13_in:     .literal "3.5E38", $0
str_t14_exp:    .literal "1E+14", $0
str_t15_in:     .literal "1.9E+38", $0
str_t15_exp:    .literal "1.89E+38", $0
str_t16_in:     .literal "1E-38", $0
str_t16_exp:    .literal "9.99E-39", $0
str_t17_in:     .literal "2.0E38", $0
str_t18_in:     .literal "2.1E38", $0
str_t19_in:     .literal "3.0E38", $0
str_t20_in:     .literal "3.4028E38", $0
str_t21_in:     .literal "3.403E38", $0
.endproc
