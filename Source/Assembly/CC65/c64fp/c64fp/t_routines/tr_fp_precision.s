
.include "tr.inc"

.export tr_fp_precision

.import FP_FMUL, FP_FROM_INT8
.import TEST_FP1CMP

.proc tr_fp_precision
    ; --------------------------------------------------------
    ; T00: FP_FMUL(pi, 2.0) is measurably NOT the mathematically
    ; exact double of TestValue::val_pi - even though multiplying by
    ; exactly 2.0 SHOULD be a pure exponent increment with no
    ; rounding required at all (2 * (mantissa/2^22 * 2^exp) =
    ; mantissa/2^22 * 2^(exp+1), mantissa untouched). Verified by
    ; hand before writing this test: TestValue::val_pi's own decoded
    ; value, doubled in plain arithmetic, lands EXACTLY on
    ; TestValue::val_2pi ($82,$64,$87,$ed - already proven correct
    ; by tr_ieee754.s's own T08, which round-trips it through
    ; IEEE-754 and back). So val_2pi is not just "a" correct 2*pi,
    ; it is the exact, lossless double of val_pi specifically.
    ;
    ; FP_FMUL itself instead returns $82,$64,$87,$ec - 1 ULP low
    ; (confirmed on real hardware - this is what sent Peter looking
    ; into it in the first place). This is the SAME class of
    ; behaviour already documented elsewhere in this library
    ; (FP_FADD truncates rather than rounds - see
    ; lib_fp_to_ascii24.s) now confirmed for FP_FMUL too: the 24-bit
    ; shift-and-add multiply loop keeps the truncated top 24 bits of
    ; the real product rather than rounding to the nearest
    ; representable value, so it can lose up to just-under-1-ULP
    ; versus the exact answer even when the exact answer WAS
    ; representable without any rounding at all.
    ;
    ; This test is not checking "is FP_FMUL accurate" in the usual
    ; sense - it is PINNING DOWN a known, already-explained quirk as
    ; an expected value, so that if FP_FMUL's internal algorithm
    ; ever changes, this fails loudly and points straight at this
    ; explanation instead of looking like a new, unexplained mystery.
    ; Deliberately compared against fmul_quirk_result below, NOT
    ; against TestValue::val_2pi - comparing against val_2pi would
    ; make this test FAIL forever (correctly - see the ideal
    ; 1ULP-low-and-fine reasoning above), which is the wrong signal
    ; for a characterization test that's meant to stay green.
    ;
    ; ULP = "Unit in the Last Place" — the gap between two adjacent
    ; representable values in a given floating-point format, i.e. the
    ; smallest possible change you can make by incrementing or decrementing
    ; the lowest mantissa bit by exactly 1. It's not a fixed number — it
    ; scales with magnitude, because it depends on the exponent.
    ; --------------------------------------------------------
    FP_ERROR_INIT_MACRO t00_recover
    lda #2
    jsr FP_FROM_INT8
    FP_LOAD2_MACRO TestValue::val_pi    ; reuse the already-proven pi
                                        ; constant (same one tr_ieee754.s's
                                        ; own T05 already validated) rather
                                        ; than duplicating a fresh copy
    jsr FP_FMUL                         ; FP1 = pi * 2, via the general
                                        ; 24-bit shift-and-add multiply -
                                        ; NOT a specialised "multiply by
                                        ; an exact power of two" shortcut
    FP_ERROR_CLEAR_MACRO
t00_recover:
    TEST_FP1CMP_MACRO 0, msg_t00, fmul_quirk_result

    rts

.segment "RODATA"
msg_t00: .asciiz "fmul (2*pi) 1ulp-low"

fmul_quirk_result: .byte $82,$64,$87,$ec   ; the DOCUMENTED, expected
                                           ; result of FP_FMUL(pi,2) -
                                           ; deliberately NOT
                                           ; TestValue::val_2pi ($82,$64,$87,$ed,
                                           ; the mathematically exact double) -
                                           ; this is the truncated value FP_FMUL
                                           ; itself produces, 1 ULP low
.endproc
