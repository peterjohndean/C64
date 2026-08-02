
.include "tr.inc"

.export tr_ascii16

.import FP_FROM_ASCII, FP_TO_ASCII
.import TEST_FP1CMP, TEST_STRCMP, TEST_FAILED

.proc tr_ascii16
    ; --- T11: ASCII round trip, "-42" (integer only) ------------
    ; Deliberately integer-only: FP_FROM_ASCII_PROC's fractional
    ; path divides by 10.0 once per fractional digit, and division
    ; by 10 isn't exact in binary even when the final decimal
    ; result happens to be exactly representable (e.g. 0.25) - see
    ; T18 for a fractional round trip checked by eye instead of by
    ; exact match, and why.
    lda #<str_test00
    ldy #>str_test00
    jsr FP_FROM_ASCII
    bcs t11_fail                    ; carry set = no digits found
    TEST_FP1CMP_MACRO 0, msg_t00, TestValue::val_neg42
    jmp t11_done
t11_fail:
    TEST_FAILED_MACRO_V2 0, msg_t00
t11_done:

    ; --- T12: ASCII edge case - no digits at all ---------------
    ; "abc" contains no digits; FP_FROM_ASCII_PROC must report
    ; carry set and leave FP1 at 0.0, not silently return garbage.
    lda #<str_test01
    ldy #>str_test01
    jsr FP_FROM_ASCII
    bcc t12_fail                    ; carry SHOULD be set (no digits)
    TEST_FP1CMP_MACRO 1, msg_t00, TestValue::val_0
    jmp t12_done
t12_fail:
    TEST_FAILED_MACRO_V2 1, msg_t00
t12_done:

    ; --- T17: fractional ASCII round trip, printed for manual
    ;          inspection (see T12's comment on why this isn't an
    ;          automated exact-match test) ------------------------
    ; Parses "-42.25", then formats the result straight back out
    ; with FP_TO_ASCII_PROC (2 fractional digits). Expect the
    ; printed string to read "-42.25" or something extremely close
    ; (e.g. "-42.24" or "-42.26" would indicate the divide-by-10
    ; rounding accumulated more error than expected and is worth a
    ; closer look).
    lda #<str_test02
    ldy #>str_test02
    jsr FP_FROM_ASCII
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII
    TEST_STRCMP_MACRO_V2 2, msg_t00, str_test02

    ; --- T55: ASCII Parser Noise Rejection ("-42abc" -> -42.0) -
    ; Ensures the parser cleanly halts upon encountering non-numeric
    ; characters without crashing or corrupting the parsed value.
    lda #<str_test03
    ldy #>str_test03
    jsr FP_FROM_ASCII
    bcs t55_fail                    ; Carry SHOULD be clear (valid digits were found)
    TEST_FP1CMP_MACRO 3, msg_t00, TestValue::val_neg42
    jmp t55_done
t55_fail:
    TEST_FAILED_MACRO_V2 3, msg_t00
t55_done:

    
    ; --- T67: plain ascii, 20000.25 -> 20000.25 (exact) ------------
    ; 20000 leaves 8 fractional bits (granularity 1/256), and .25 is
    ; an exact multiple of that (64/256) - sanity check that flooring
    ; only happens for genuinely non-representable fractions, not
    ; every fraction at this magnitude.
    lda #<str_test04
    ldy #>str_test04
    jsr FP_FROM_ASCII
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII
    TEST_STRCMP_MACRO_V2 4, msg_t00, str_test04

    ; --- T68: plain ascii precision floor, 20000.10 -> 20000.09 ---
    ; 1/256 granularity is much finer than ascii24's worst case, so
    ; the floor distance here is small - this is normal decimal-to-
    ; binary imprecision (the same reason 0.1 isn't exact in any
    ; binary float), not a large magnitude-driven loss like T64-T66.
    lda #<str_test05_in
    ldy #>str_test05_in
    jsr FP_FROM_ASCII
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII
    TEST_STRCMP_MACRO_V2 5, msg_t00, str_test05_exp

    ; --- T69: plain ascii precision floor, 20000.30 -> 20000.29 ---
    lda #<str_test06_in
    ldy #>str_test06_in
    jsr FP_FROM_ASCII
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII
    TEST_STRCMP_MACRO_V2 6, msg_t00, str_test06_exp

    ; --- T70: plain ascii precision floor, 20000.90 -> 20000.89 ---
    lda #<str_test07_in
    ldy #>str_test07_in
    jsr FP_FROM_ASCII
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII
    TEST_STRCMP_MACRO_V2 7, msg_t00, str_test07_exp
    rts

.segment "RODATA"
msg_t00:        .asciiz "ascii from"
;
str_test00:     .asciiz "-42"
str_test01:     .asciiz "abc"
str_test02:     .asciiz "-42.25"
str_test03:     .asciiz "-42abc"
; --- T67-T70: plain ascii (16-bit) precision-floor edge cases
;     (20000 magnitude, 8 fractional bits available - a much finer
;     granularity than ascii24's worst case, deliberately chosen well
;     under any 16-bit signed/unsigned ceiling question - see
;     lib_fp_to_ascii16.s's own header). Computed, not yet confirmed
;     on hardware - verify and correct if reality differs. ---
str_test04:     .asciiz "20000.25"  ; exact at this magnitude -
                                    ; sanity check that flooring
                                    ; only kicks in when the input
                                    ; genuinely isn't representable
str_test05_in:  .asciiz "20000.10"
str_test05_exp: .asciiz "20000.09"
str_test06_in:  .asciiz "20000.30"
str_test06_exp: .asciiz "20000.29"
str_test07_in:  .asciiz "20000.90"
str_test07_exp: .asciiz "20000.89"
.endproc

