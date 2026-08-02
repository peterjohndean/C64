
.include "tr.inc"

.export tr_ascii24

.import FP_FROM_ASCII
.import FP_FROM_ASCII24, FP_TO_ASCII24
.import TEST_STRCMP

.proc tr_ascii24
    ; --- T56: FP_TO_ASCII24_PROC, integer-only, at the exact max
    ;          value FP_TO_INT24 can represent (8,388,607) - the
    ;          mirror image of T53's overflow trap at 8,388,608, and
    ;          well beyond FP_TO_ASCII_PROC's 16-bit ceiling --
    lda #<str_test00
    ldy #>str_test00
    jsr FP_FROM_ASCII
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #0
    jsr FP_TO_ASCII24
    TEST_STRCMP_MACRO_V2 0, msg_t00, str_test00

    ; --- T57: FP_TO_ASCII24_PROC, integer-only, at 100,000 - well
    ;          above FP_TO_ASCII_PROC's 65,535 ceiling, proving the
    ;          wider routine actually reaches where the original
    ;          couldn't, not just that it still works below 65,536 -
    lda #<str_test01
    ldy #>str_test01
    jsr FP_FROM_ASCII
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #0
    jsr FP_TO_ASCII24
    TEST_STRCMP_MACRO_V2 1, msg_t00, str_test01

    ; --- T58: FP_TO_ASCII24_PROC, large integer part WITH a
    ;          fraction (70000.25) - exercises the fractional
    ;          loop (unchanged from FP_TO_ASCII_PROC, but never
    ;          tested downstream of a 3-byte integer part before)
    ;          and confirms the integer/fraction boundary still
    ;          lands in the right place with the wider extraction.
    ;          .25 is exactly representable (2^-2), so - like T12/
    ;          T18 - this is meant as a genuine exact-match test.
    ;          VALUE CHOSEN FOR PRECISION, NOT JUST RANGE: this
    ;          format has ~23 bits of exact mantissa precision (see
    ;          T56's comment). FP_FROM_ASCII_PROC accumulates ALL
    ;          digits (integer + fraction) into one Horner-method
    ;          intermediate BEFORE dividing back down by 10 per
    ;          fractional digit - so that intermediate itself must
    ;          fit in ~23 bits, not just the final value. A value
    ;          like 1234567.25 looks safely in-range on its own
    ;          (needs 23 bits), but its unscaled parse intermediate
    ;          (123456725) needs 27 bits and rounds BEFORE the
    ;          divide-back-down step ever runs - silently corrupting
    ;          both the integer and fractional digits. 70000.25's
    ;          unscaled intermediate (7000025) needs exactly 23 bits
    ;          - same margin as T56's 8388607 - and every /10 step
    ;          along the way (700002.5, then 70000.25) also lands on
    ;          an exactly-representable value, so nothing rounds.
    ;          Integer part still exceeds 65,535, so this still
    ;          genuinely exercises the 3-byte path FP_TO_ASCII_PROC
    ;          could never reach.
    lda #<str_test02
    ldy #>str_test02
    jsr FP_FROM_ASCII
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII24
    TEST_STRCMP_MACRO_V2 2, msg_t00, str_test02

    ; --- T59: FP_FROM_ASCII24_PROC + FP_TO_ASCII24_PROC, exact-match
    ;          regression test for the ORIGINAL reported-broken value
    ;          (1234567.25). Real-hardware VICE debugging traced this
    ;          all the way through: FP_FROM_ASCII24_PROC's parser fix
    ;          is exact here (int_part=1234567.0, fraction=0.25,
    ;          and FP_FADD combining them was independently verified
    ;          via register dumps to produce exactly 1234567.25 - not
    ;          a bug at all, despite this test once claiming
    ;          otherwise). The actual remaining loss was traced to
    ;          FP_TO_ASCII24_PROC's OWN fractional-remainder
    ;          extraction (an FP_NORM+FP_FSUB reconstruction that
    ;          returned exactly 0.0 for this input on real hardware,
    ;          for reasons that resisted full static explanation even
    ;          against disassembly) - now replaced there with a
    ;          direct bit-mask extraction that never calls FP_FSUB.
    ;          See lib_fp_to_ascii24.s's FRACTIONAL EXTRACTION note.
    lda #<str_test04
    ldy #>str_test04
    jsr FP_FROM_ASCII24
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII24
    TEST_STRCMP_MACRO_V2 3, msg_t04, str_test04

    ; --- T60: FP_FROM_ASCII24_PROC, PRIMARY exact-match regression
    ;          proof (700002.25). Old-routine unscaled intermediate
    ;          (70000225) needs 27 bits - same failure class as the
    ;          originally-reported bug - but 700002 itself only
    ;          needs 20 mantissa bits, leaving enough headroom for
    ;          FP_FADD's alignment shift to land 0.25 inside the
    ;          visible mantissa (see T59's comment for why 1234567.25
    ;          specifically can't do this). This is the value that
    ;          actually proves the parser fix end-to-end.
    lda #<str_test05
    ldy #>str_test05
    jsr FP_FROM_ASCII24
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII24
    TEST_STRCMP_MACRO_V2 4, msg_t04, str_test05

    ; --- T61: FP_FROM_ASCII24_PROC, negative number (-70000.25) -
    ;          exercises is_negative/FP_NEGATE together with the new
    ;          split-accumulator logic. Reuses T58's magnitude (a
    ;          value already confirmed exact both ways) so this is
    ;          purely a sign-handling check, not another precision
    ;          case.
    lda #<str_test06
    ldy #>str_test06
    jsr FP_FROM_ASCII24
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII24
    TEST_STRCMP_MACRO_V2 5, msg_t04, str_test06

    ; --- T62: FP_FROM_ASCII24_PROC, integer-only input with no
    ;          decimal point at all (8388607, reusing T56's string).
    ;          Confirms the "@no_fraction" path - int_part loaded
    ;          straight into FP1 with no FADD - matches
    ;          FP_FROM_ASCII_PROC's result for an input that was
    ;          never at risk from the combined-digit bug in the
    ;          first place.
    lda #<str_test00
    ldy #>str_test00
    jsr FP_FROM_ASCII24
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #0
    jsr FP_TO_ASCII24
    TEST_STRCMP_MACRO_V2 6, msg_t04, str_test00

    ; --- T63: FP_FROM_ASCII24_PROC, fraction-only input with a
    ;          zero integer part (0.25, no digits before the point).
    ;          int_part never accumulates anything (stays 0.0,
    ;          stashed as-is), and FP_TO_ASCII24_PROC's own leading-
    ;          zero suppression is relied on to still print the "0"
    ;          before the point.
    lda #<str_test07
    ldy #>str_test07
    jsr FP_FROM_ASCII24
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII24
    TEST_STRCMP_MACRO_V2 7, msg_t04, str_test07

    ; --- T64: ascii24 precision floor, 1234567.35 -> 1234567.25 ---
    ; 1234567 leaves only 2 fractional bits (granularity 1/4 - see
    ; lib_fp_to_ascii24.s's precision-budget table). .35 isn't a
    ; multiple of .25, so it floors down to the nearest one during
    ; FP_FROM_ASCII24_PROC's parse-time FP_FADD combine. This isn't
    ; a bug - it's the same fact T56-T63 already established, just
    ; codified as a permanent regression test instead of a one-off
    ; manual check. Confirmed on real hardware during development.
    lda #<str_test08_in
    ldy #>str_test08_in
    jsr FP_FROM_ASCII24
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII24
    TEST_STRCMP_MACRO_V2 8, msg_t04, str_test08_exp

    ; --- T65: ascii24 precision floor, 1234567.55 -> 1234567.50 ---
    ; Same mechanism as T64, next quarter-bucket up.
    lda #<str_test09_in
    ldy #>str_test09_in
    jsr FP_FROM_ASCII24
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII24
    TEST_STRCMP_MACRO_V2 9, msg_t04, str_test09_exp

    ; --- T66: ascii24 precision floor, 1234567.95 -> 1234567.75 ---
    ; Same mechanism, top quarter-bucket - the largest possible floor
    ; distance at this magnitude (up to just under 0.25 lost).
    lda #<str_test10_in
    ldy #>str_test10_in
    jsr FP_FROM_ASCII24
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #2
    jsr FP_TO_ASCII24
    TEST_STRCMP_MACRO_V2 10, msg_t04, str_test10_exp
    rts

.segment "RODATA"
msg_t00:        .asciiz "ascii24 to"
msg_t04:        .asciiz "ascii24 from"
;
str_test00:     .asciiz  "8388607"
str_test01:     .asciiz  "100000"
str_test02:     .asciiz  "70000.25"
str_test04:     .asciiz  "1234567.25"
str_test05:     .asciiz  "700002.25"
str_test06:     .asciiz  "-70000.25"
str_test07:     .asciiz  "0.25"
; --- T64-T66: ascii24 precision-floor edge cases (1234567 magnitude,
;     2 fractional bits available - see lib_fp_to_ascii24.s's
;     precision-budget table). Values confirmed on real hardware
;     during development; kept here as permanent regression tests. ---
str_test08_in:  .asciiz "1234567.35"
str_test08_exp: .asciiz "1234567.25"
str_test09_in:  .asciiz "1234567.55"
str_test09_exp: .asciiz "1234567.50"
str_test10_in:  .asciiz "1234567.95"
str_test10_exp: .asciiz "1234567.75"
.endproc

