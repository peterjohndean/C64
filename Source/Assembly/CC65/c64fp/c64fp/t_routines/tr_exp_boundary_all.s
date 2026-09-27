.include "tr.inc"
.include "lib_fp_error.h"

.export tr_exp_boundary_all

.import FP_FADD, FP_FSUB, FP_FMUL, FP_FDIV, FP_COMPARE
.import FP_TO_ASCII_SCI_V2, FP_TO_IEEE754, FP_TO_BASIC
.import TEST_PASSED, TEST_FAILED, TEST_FP1CMP, TEST_STRCMP, TEST_CHECK

.segment "CODE"
; ============================================================
; FILE    : tr_exp_boundary_all.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; Consolidated regression coverage for every exponent-boundary
; investigation this project has run: the $FF-exponent cross-
; consumer sweep (formerly tr_exp_boundary_ff.s), the FMUL/FDIV
; ovchk/norm1 CEILING+FLOOR fix (formerly tr_exp_muldiv_boundary.s),
; and NEW coverage for a gap found and fixed in the same session as
; the FMUL/FDIV fix: FADD/FSUB share norm/norm1/rts1's shared tail
; but had no classify logic of their own, so fp_norm_boundary_state -
; a global flag only ever SET by FMUL/FDIV - could be left dirty by
; an earlier, unrelated FMUL/FDIV call and silently corrupt or trap a
; completely ordinary, later FADD/FSUB call. See lib_fp.s's own
; EXPONENT OVERFLOW BOUNDARY note for the full fix history.
;
; tr_exp_boundary.s (the original hand-derived, never-hardware-
; confirmed S=127/S=128/S=-128 sweep) is RETIRED - its S=127/S=128
; cases are subsumed by T04/T02 below (now hardware-confirmed, where
; the retired file's own were not), and its S=-128 zero-collision
; observation is preserved as a documented note (see ZERO COLLISION
; below) rather than a live test, since - as that file's own header
; already said - there is still no agreed "correct" behaviour to
; assert against; it remains a known, separately-tracked limitation.
;
; ZERO COLLISION (inherited, still unresolved - not tested here)
; -----------------------------------------------------------------
; A value whose true exponent lands the biased byte at exactly $00
; (e.g. S=-128 in the old FMUL derivation) is indistinguishable from
; canonical zero to every FP1_EXP==0 check in this library (FP_COMPARE,
; FP_FDIV's divide-by-zero test, etc), even when its mantissa is
; genuinely nonzero. This was observed, not fixed, by the retired
; tr_exp_boundary.s's T02. It is a real, still-open gap - noted here
; so it isn't lost in the file merge, not asserted as pass/fail
; because no correct behaviour has been agreed yet.
;
; MACRO SIGNATURES - CORRECTED AGAINST THE REAL tr.inc/fp_test_macros.s
; -----------------------------------------------------------------
; tr_exp_boundary_ff.s's draft guessed several macro shapes before
; the real fp_test_macros.s was available. Corrected here: every
; TEST_PASSED_MACRO_V2/TEST_FAILED_MACRO_V2 call takes exactly
; (test_num, test_msg) - no third argument - and TEST_FP1CMP_MACRO/
; TEST_STRCMP_MACRO_V2 take (test_num, test_msg, expected_label).
;
; TEST INVENTORY
; -----------------
; --- Section A: $FF-exponent cross-consumer sweep (ex-tr_exp_boundary_ff.s) ---
;   T00  FADD  ff_val(FP1) + ten_const(FP2)          -> succeeds
;   T01  FADD  ten_const(FP1) + ff_val(FP2)          -> succeeds
;   T02  FSUB  ff_val(FP1), ten_const(FP2)           -> succeeds
;        [UPDATED] originally the reproduction case for the NOW-
;        FIXED fsub stale-carry alignment bug (see lib_fp.s's
;        EXPONENT $FF BOUNDARY note) - success is now correct,
;        not a trap.
;   T03  FSUB  ten_const(FP1), ff_val(FP2)           -> succeeds
;   T04  FMUL  ff_val * ten_const                    -> traps (code 0,
;        ordinary overflow - exponents ADD, unrelated to the CEILING/
;        FLOOR fix; contrast case)
;   T05  FDIV  ff_val / ten_const                    -> succeeds
;   T06  COMPARE ff_val vs ten_const                 -> succeeds
;        [UPDATED] mirrors T02's now-fixed outcome
;   T07  FSUB  boundary-mantissa ff_val - ten_const  -> traps (the
;        SEPARATE, already-documented fcompl 2's-complement-overflow
;        case, kept isolated from T02's now-fixed case)
;   T08  FP_TO_ASCII_SCI_V2(ff_val)                     -> succeeds,
;        string-compared (not just no-trap) against a hardware-
;        confirmed expected string
;   T09  FP_TO_IEEE754(ff_val)                       -> succeeds
;   T10  FP_TO_BASIC(ff_val)                         -> traps (code 0,
;        documented Eb=Ew+1 byte-wrap - see lib_fp_basic.s)
;
; --- Section B: FMUL/FDIV CEILING/FLOOR ovchk/norm1 fix
;     (ex-tr_exp_muldiv_boundary.s, hardware-confirmed passing) ---
;   T11  FMUL regression: 10.0*10.0=100.0 (must be unaffected by the fix)
;   T12  FMUL motivating case: 2,200,000.0*10^32 ~= 2.2e38 (was: traps;
;        now: succeeds at true ceiling)
;   T13  FMUL genuine overflow: true sum=128 -> traps, code 0
;   T14  FMUL genuine underflow: true sum=-131 -> silent 0.0, no trap
;   T15  FMUL exact CEILING: true sum=127 -> succeeds, lands at $FF
;   T16  FMUL exact FLOOR: true sum=-128 -> succeeds, lands at $00
;        (nonzero mantissa - the zero-collision case, see ZERO
;        COLLISION above; included here as observed behaviour, not
;        because the collision itself is resolved)
;   T17  FDIV exact CEILING: quotient true exp=127 -> succeeds
;   T18  FDIV genuine overflow: quotient true exp=128 -> traps, code 0
;   T19  FDIV genuine underflow: quotient true exp=-129 -> silent 0.0
;   T20  FMUL genuine underflow at true sum=-129 -> silent 0.0
;
; --- Section C: NEW - FADD/FSUB CEILING/FLOOR classify-flag gap ---
;     This gap was found DURING the FMUL/FDIV fix's own verification:
;     fp_norm_boundary_state is a ONE global flag, set only by
;     FMUL/FDIV's classify block, but consulted by norm/norm1/rts1's
;     shared FP1_EXP==0 ambiguous-decrement logic - which FADD/FSUB
;     ALSO reach, via fadd's direct add path and fsub's own jsr fcompl
;     negation detour (a THIRD reentry into the shared tail, per
;     lib_fp.s's own DOUBLE-ENTRY TRICK note - discovered to matter
;     here specifically because it runs BEFORE fadd's own entry-point
;     reset). Confirmed via direct empirical poisoning (not hardware
;     yet - see VERIFICATION STATUS below): an ordinary FADD/FSUB
;     landing at FP1_EXP==0 could silently trap or corrupt depending
;     ENTIRELY on unrelated, earlier FMUL/FDIV call history, not on
;     anything about the FADD/FSUB operands themselves. Fixed by
;     resetting fp_norm_boundary_state to NORMAL at BOTH fadd's AND
;     fsub's own entry points (fsub's reset is required separately -
;     resetting only at fadd's entry left fsub's negation path still
;     vulnerable, confirmed by the poisoning tests failing without it).
;
;   T21  FADD at the genuine floor: two small operands at exponent
;        $00 whose sum needs a renormalizing left-shift - confirms
;        the ambiguous branch is REACHABLE via fadd and produces the
;        correct answer with the flag at its honest default (NORMAL).
;   T22  FADD, SAME operands as T21, but fp_norm_boundary_state is
;        deliberately poisoned to CEILING via a preceding, unrelated
;        FMUL call before T22's own FADD runs. Must produce the
;        IDENTICAL result to T21 - this is the actual regression
;        marker for the bug: without the entry-point reset, this
;        traps instead.
;   T23  FSUB at the same genuine floor, via the fcompl negation path
;        specifically (FP1 needs negating) - confirms fsub's OWN
;        entry-point reset, not just fadd's, since fcompl's pass
;        through norm happens before fsub's jmp fadd ever runs.
;   T24  FSUB, SAME operands as T23, poisoned to FLOOR beforehand.
;        Must match T23 exactly - without fsub's own reset, this
;        test returns FP2 unchanged instead of the real difference.
;   T25  FSUB, SAME operands as T23, poisoned to CEILING beforehand.
;        Must match T23 exactly - without fsub's own reset, this
;        test produces a wildly wrong magnitude AND sign.
;
; ============================================================
; ADDITIONS TO tr_exp_boundary_all.s - T26 through T31
; ============================================================
; T26/T27 close a gap the diag1.py/diag2.py harness fix exposed
; tonight: lib_fp.s's own header claimed the FMUL CEILING straddle
; splits 98% rescued / 2% genuine-overflow-trap. That figure was
; measured with a simulator harness bug (stopping the instant PC
; reached .rts1's ADDRESS, before letting .rts1's OWN code decide
; whether to trap - see diag25.py for the confirming trace) that
; silently miscounted every genuine-trap case as a clean success.
; The CORRECTED, re-measured split is 71.6% rescued / 28.4%
; genuine-overflow-trap (see diag2.py's OVERFLOW STRADDLE sweep,
; post-fix). T15 (existing) only exercises the "needs decrement,
; rescued" side with a hand-picked 1.5*1.5 mantissa pair - nothing
; in the existing suite exercised the "already normalized, genuine
; trap" side at all. T26/T27 close that gap with a CONFIRMED
; (py65-simulator-executed, not hand-derived) example of each.
;
; T28-T31 cover FDIV's SECOND exponent-boundary collision, found
; and fixed in the same session as T26/T27's gap. FDIV's provisional
; exponent arithmetic (raw biased-byte subtraction, no "+1" pre-
; compensation the way FMUL's md3 has) creates a DIFFERENT collision
; than the one FMUL/FDIV's original fix addressed: true_diff=-128
; (the genuine, valid floor) and true_diff=+128 (invalid, one step
; past the true ceiling) both alias to the same raw byte ($80,
; becoming $00 after md3's eor). Unlike the ALREADY-FIXED $FF
; collision (true_diff=127/-129, where the invalid side is
; UNCONDITIONALLY invalid regardless of mantissa), THIS collision's
; invalid side (+128) CAN be rescued to a valid result (127) if the
; mantissa needs a decrement - and its valid side (-128) CAN
; genuinely underflow if the mantissa needs a decrement (landing on
; -129, invalid). This needed the SAME kind of CEILING/FLOOR
; classify-and-defer treatment the original fix gave FMUL/FDIV's
; first collision, just with the V-flag mapping INVERTED (confirmed
; via verify_v_flag.py's exact 6502 SBC emulation - naively copying
; the first collision's V=0=>CEILING,V=1=>FLOOR convention would
; have been exactly backwards here).
;
; VERIFICATION STATUS: T26-T31 all use operand bytes taken directly
; from confirmed py65 simulator execution (diag24.py/diag25.py/
; diag26.py) - not hand-derived. NOT YET run on physical C64U/VICE -
; treat as simulator-confirmed, hardware-pending until run for real,
; per this project's standing "hardware is the authority" principle.
; ============================================================
;
; VERIFICATION STATUS
; -----------------------
; Section A: hardware-confirmed (T00-T10 all pass on real C64U/VICE
; per this project's live test output).
; Section B: hardware-confirmed (T11-T20 all pass on real C64U/VICE
; per this project's live test output).
; Section C: CONFIRMED via py65 instruction-level simulation with
; direct memory poisoning of fp_norm_boundary_state (see the
; accompanying diagnostic session), cross-checked against the actual
; assembled binary - NOT YET run on physical C64U/VICE. Per this
; project's own standing principle, treat T21-T25 as simulator-
; confirmed, hardware-pending until run for real.
; ============================================================
.proc tr_exp_boundary_all
    TEST_ROUTINE_HEADER_MACRO @msg_header

    ; ============================================================
    ; SECTION A - $FF-exponent cross-consumer sweep
    ; ============================================================

    ; --- T00: FADD, ff_val(FP1) + ten_const(FP2) ---
    FP_ERROR_INIT_MACRO @t00_trapped
    FP_LOAD1_MACRO ff_val
    FP_LOAD2_MACRO LIBFP_CONSTANTS::ten_const
    jsr FP_FADD
    FP_ERROR_CLEAR_MACRO
    TEST_PASSED_MACRO_V2 0, @msg_t00
    jmp @t00_done
@t00_trapped:
    TEST_FAILED_MACRO_V2 0, @msg_t00
@t00_done:

    ; --- T01: FADD, ten_const(FP1) + ff_val(FP2) ---
    FP_ERROR_INIT_MACRO @t01_trapped
    FP_LOAD1_MACRO LIBFP_CONSTANTS::ten_const
    FP_LOAD2_MACRO ff_val
    jsr FP_FADD
    FP_ERROR_CLEAR_MACRO
    TEST_PASSED_MACRO_V2 1, @msg_t01
    jmp @t01_done
@t01_trapped:
    TEST_FAILED_MACRO_V2 1, @msg_t01
@t01_done:

    ; --- T02: FSUB, ff_val(FP1), ten_const(FP2) - [UPDATED] the
    ; fsub stale-carry bug this test originally targeted is fixed
    ; (see lib_fp.s's jmp fadd fix) - success is now correct. ---
    FP_ERROR_INIT_MACRO @t02_trapped
    FP_LOAD1_MACRO ff_val
    FP_LOAD2_MACRO LIBFP_CONSTANTS::ten_const
    jsr FP_FSUB
    FP_ERROR_CLEAR_MACRO
    TEST_PASSED_MACRO_V2 2, @msg_t02
    jmp @t02_done
@t02_trapped:
    TEST_FAILED_MACRO_V2 2, @msg_t02
@t02_done:

    ; --- T03: FSUB, ten_const(FP1), ff_val(FP2) ---
    FP_ERROR_INIT_MACRO @t03_trapped
    FP_LOAD1_MACRO LIBFP_CONSTANTS::ten_const
    FP_LOAD2_MACRO ff_val
    jsr FP_FSUB
    FP_ERROR_CLEAR_MACRO
    TEST_PASSED_MACRO_V2 3, @msg_t03
    jmp @t03_done
@t03_trapped:
    TEST_FAILED_MACRO_V2 3, @msg_t03
@t03_done:

    ; --- T04: FMUL, ff_val * ten_const - ordinary overflow, exponents
    ; ADD ($FF+$83 excess-128), unrelated to the CEILING/FLOOR fix. ---
    FP_ERROR_INIT_MACRO @t04_trapped
    FP_LOAD1_MACRO ff_val
    FP_LOAD2_MACRO LIBFP_CONSTANTS::ten_const
    jsr FP_FMUL
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 4, @msg_t04
    jmp @t04_done
@t04_trapped:
    lda FP_ERROR_CODE
    cmp #FP_ERROR_CODE_GENERIC_OVERFLOW
    bne @t04_wrong_code
    TEST_PASSED_MACRO_V2 4, @msg_t04
    jmp @t04_done
@t04_wrong_code:
    TEST_FAILED_MACRO_V2 4, @msg_t04
@t04_done:

    ; --- T05: FDIV, ff_val / ten_const - exponents SUBTRACT ---
    FP_ERROR_INIT_MACRO @t05_trapped
    FP_LOAD1_MACRO LIBFP_CONSTANTS::ten_const   ; FP1 = divisor
    FP_LOAD2_MACRO ff_val                       ; FP2 = dividend
    jsr FP_FDIV
    FP_ERROR_CLEAR_MACRO
    TEST_PASSED_MACRO_V2 5, @msg_t05
    jmp @t05_done
@t05_trapped:
    TEST_FAILED_MACRO_V2 5, @msg_t05
@t05_done:

    ; --- T06: COMPARE, ff_val vs ten_const - mirrors T02's fixed
    ; outcome, since FP_COMPARE_PROC is a guarded FP_FSUB. ---
    FP_ERROR_INIT_MACRO @t06_trapped
    FP_LOAD1_MACRO ff_val
    FP_COMPARE_TO_MACRO LIBFP_CONSTANTS::ten_const
    FP_ERROR_CLEAR_MACRO
    TEST_PASSED_MACRO_V2 6, @msg_t06
    jmp @t06_done
@t06_trapped:
    TEST_FAILED_MACRO_V2 6, @msg_t06
@t06_done:

    ; --- T07: FSUB against the boundary mantissa - the SEPARATE,
    ; already-documented fcompl 2's-complement-overflow case. ---
    FP_ERROR_INIT_MACRO @t07_trapped
    FP_LOAD1_MACRO ff_val_boundary
    FP_LOAD2_MACRO LIBFP_CONSTANTS::ten_const
    jsr FP_FSUB
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 7, @msg_t07
    jmp @t07_done
@t07_trapped:
    TEST_PASSED_MACRO_V2 7, @msg_t07
@t07_done:

    ; --- T08: FP_TO_ASCII_SCI_V2(ff_val) - string-compared, not just
    ; no-trap. ---
    FP_ERROR_INIT_MACRO @t08_trapped
    FP_LOAD1_MACRO ff_val
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    ldx #6
    jsr FP_TO_ASCII_SCI_V2
    FP_ERROR_CLEAR_MACRO
    TEST_STRCMP_MACRO_V2 8, @msg_t08, @exp_t08
    jmp @t08_done
@t08_trapped:
    TEST_FAILED_MACRO_V2 8, @msg_t08
@t08_done:

    ; --- T09: FP_TO_IEEE754(ff_val) - positive input, FP_NEGATE never
    ; invoked, expected to succeed regardless of the FADD/FSUB fix. ---
    FP_ERROR_INIT_MACRO @t09_trapped
    FP_LOAD1_MACRO ff_val
    jsr FP_TO_IEEE754
    FP_ERROR_CLEAR_MACRO
    TEST_PASSED_MACRO_V2 9, @msg_t09
    jmp @t09_done
@t09_trapped:
    TEST_FAILED_MACRO_V2 9, @msg_t09
@t09_done:

    ; --- T10: FP_TO_BASIC(ff_val) - documented Eb=Ew+1 byte-wrap trap. ---
    FP_ERROR_INIT_MACRO @t10_trapped
    FP_LOAD1_MACRO ff_val
    lda #<TestData::out_buffer
    ldy #>TestData::out_buffer
    jsr FP_TO_BASIC
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 10, @msg_t10
    jmp @t10_done
@t10_trapped:
    lda FP_ERROR_CODE
    cmp #FP_ERROR_CODE_GENERIC_OVERFLOW
    bne @t10_wrong_code
    TEST_PASSED_MACRO_V2 10, @msg_t10
    jmp @t10_done
@t10_wrong_code:
    TEST_FAILED_MACRO_V2 10, @msg_t10
@t10_done:

    ; ============================================================
    ; SECTION B - FMUL/FDIV CEILING/FLOOR ovchk/norm1 fix
    ; ============================================================

    ; --- T11: FMUL regression: 10.0*10.0=100.0 ---
    FP_ERROR_INIT_MACRO @t11_recover
    FP_LOAD1_MACRO LIBFP_CONSTANTS::ten_const
    FP_LOAD2_MACRO LIBFP_CONSTANTS::ten_const
    jsr FP_FMUL
    FP_ERROR_CLEAR_MACRO
@t11_recover:
    TEST_FP1CMP_MACRO 11, @msg_t11, TestValue::val_100

    ; --- T12: FMUL motivating case: 2,200,000.0 * 10^32 ~= 2.2e38 ---
    FP_ERROR_INIT_MACRO @t12_recover
    FP_LOAD1_MACRO t12_a
    FP_LOAD2_MACRO t12_b
    jsr FP_FMUL
    FP_ERROR_CLEAR_MACRO
    lda FP1_EXP
    cmp #$ff
    beq @t12_ok
    TEST_FAILED_MACRO_V2 12, @msg_t12
    jmp @t12_done
@t12_ok:
    TEST_PASSED_MACRO_V2 12, @msg_t12
    jmp @t12_done
@t12_recover:
    TEST_FAILED_MACRO_V2 12, @msg_t12
@t12_done:

    ; --- T13: FMUL genuine overflow: true sum=128 ---
    FP_ERROR_INIT_MACRO @t13_recover
    FP_LOAD1_MACRO t13_a
    FP_LOAD2_MACRO t13_b
    jsr FP_FMUL
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 13, @msg_t13
    jmp @t13_done
@t13_recover:
    lda FP_ERROR_CODE
    cmp #FP_ERROR_CODE_GENERIC_OVERFLOW
    bne @t13_wrong_code
    TEST_PASSED_MACRO_V2 13, @msg_t13
    jmp @t13_done
@t13_wrong_code:
    TEST_FAILED_MACRO_V2 13, @msg_t13
@t13_done:

    ; --- T14: FMUL genuine underflow: true sum=-131 ---
    FP_ERROR_INIT_MACRO @t14_recover
    FP_LOAD1_MACRO t14_a
    FP_LOAD2_MACRO t14_b
    jsr FP_FMUL
    FP_ERROR_CLEAR_MACRO
    lda FP1_EXP
    bne @t14_fail
    lda FP1_MANT
    ora FP1_MANT+1
    ora FP1_MANT+2
    bne @t14_fail
    TEST_PASSED_MACRO_V2 14, @msg_t14
    jmp @t14_done
@t14_fail:
    TEST_FAILED_MACRO_V2 14, @msg_t14
    jmp @t14_done
@t14_recover:
    TEST_FAILED_MACRO_V2 14, @msg_t14
@t14_done:

    ; --- T15: FMUL exact CEILING: true sum=127 ---
    FP_ERROR_INIT_MACRO @t15_recover
    FP_LOAD1_MACRO t15_a
    FP_LOAD2_MACRO t15_b
    jsr FP_FMUL
    FP_ERROR_CLEAR_MACRO
    TEST_FP1CMP_MACRO 15, @msg_t15, t15_exp
    jmp @t15_done
@t15_recover:
    TEST_FAILED_MACRO_V2 15, @msg_t15
@t15_done:

    ; --- T16: FMUL exact FLOOR: true sum=-128 (zero-collision case -
    ; see ZERO COLLISION above; observed, not resolved) ---
    FP_ERROR_INIT_MACRO @t16_recover
    FP_LOAD1_MACRO t16_a
    FP_LOAD2_MACRO t16_b
    jsr FP_FMUL
    FP_ERROR_CLEAR_MACRO
@t16_recover:
    TEST_FP1CMP_MACRO 16, @msg_t16, t16_exp

    ; --- T17: FDIV exact CEILING: quotient true exp=127 ---
    FP_ERROR_INIT_MACRO @t17_recover
    FP_LOAD1_MACRO t17_divisor
    FP_LOAD2_MACRO t17_dividend
    jsr FP_FDIV
    FP_ERROR_CLEAR_MACRO
@t17_recover:
    TEST_FP1CMP_MACRO 17, @msg_t17, t15_exp

    ; --- T18: FDIV genuine overflow: quotient true exp=128 ---
    FP_ERROR_INIT_MACRO @t18_recover
    FP_LOAD1_MACRO t18_divisor
    FP_LOAD2_MACRO t18_dividend
    jsr FP_FDIV
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 18, @msg_t18
    jmp @t18_done
@t18_recover:
    lda FP_ERROR_CODE
    cmp #FP_ERROR_CODE_GENERIC_OVERFLOW
    bne @t18_wrong_code
    TEST_PASSED_MACRO_V2 18, @msg_t18
    jmp @t18_done
@t18_wrong_code:
    TEST_FAILED_MACRO_V2 18, @msg_t18
@t18_done:

    ; --- T19: FDIV genuine underflow: quotient true exp=-129 ---
    FP_ERROR_INIT_MACRO @t19_fail
    FP_LOAD1_MACRO t19_divisor
    FP_LOAD2_MACRO t19_dividend
    jsr FP_FDIV
    FP_ERROR_CLEAR_MACRO
    lda FP1_EXP
    bne @t19_fail
    lda FP1_MANT
    ora FP1_MANT+1
    ora FP1_MANT+2
    bne @t19_fail
    TEST_PASSED_MACRO_V2 19, @msg_t19
    jmp @t19_done
@t19_fail:
    TEST_FAILED_MACRO_V2 19, @msg_t19
@t19_done:

    ; --- T20: FMUL genuine underflow at true sum=-129 ---
    FP_ERROR_INIT_MACRO @t20_recover
    FP_LOAD1_MACRO t20_a
    FP_LOAD2_MACRO t20_b
    jsr FP_FMUL
    FP_ERROR_CLEAR_MACRO
    lda FP1_EXP
    bne @t20_fail
    lda FP1_MANT
    ora FP1_MANT+1
    ora FP1_MANT+2
    bne @t20_fail
    TEST_PASSED_MACRO_V2 20, @msg_t20
    jmp @t20_done
@t20_fail:
    TEST_FAILED_MACRO_V2 20, @msg_t20
    jmp @t20_done
@t20_recover:
    TEST_FAILED_MACRO_V2 20, @msg_t20
@t20_done:

    ; ============================================================
    ; SECTION C - NEW: FADD/FSUB CEILING/FLOOR classify-flag gap
    ; ============================================================

    ; --- T21: FADD at the genuine floor, flag at honest default. ---
    FP_ERROR_INIT_MACRO @t21_recover
    FP_LOAD1_MACRO t21_a
    FP_LOAD2_MACRO t21_b
    jsr FP_FADD
    FP_ERROR_CLEAR_MACRO
@t21_recover:
    TEST_FP1CMP_MACRO 21, @msg_t21, t21_exp

    ; --- T22: SAME FADD operands as T21, but fp_norm_boundary_state
    ; poisoned to CEILING by a preceding, unrelated FMUL first - the
    ; actual regression marker for the bug. Must match T21 exactly. ---
    FP_ERROR_INIT_MACRO @t22_poison_recover
    FP_LOAD1_MACRO t22_poison_a       ; a genuine FMUL CEILING case,
    FP_LOAD2_MACRO t22_poison_b       ; run ONLY to leave
    jsr FP_FMUL                       ; fp_norm_boundary_state dirty -
    FP_ERROR_CLEAR_MACRO              ; its own result is discarded
@t22_poison_recover:
    FP_ERROR_INIT_MACRO @t22_recover
    FP_LOAD1_MACRO t21_a              ; same operands as T21
    FP_LOAD2_MACRO t21_b
    jsr FP_FADD
    FP_ERROR_CLEAR_MACRO
@t22_recover:
    TEST_FP1CMP_MACRO 22, @msg_t22, t21_exp   ; must match T21's own expectation

    ; --- T23: FSUB at the same genuine floor, via fcompl's negation
    ; path specifically (FP1 needs negating), flag at honest default. ---
    FP_ERROR_INIT_MACRO @t23_recover
    FP_LOAD1_MACRO t23_a
    FP_LOAD2_MACRO t23_b
    jsr FP_FSUB
    FP_ERROR_CLEAR_MACRO
@t23_recover:
    TEST_FP1CMP_MACRO 23, @msg_t23, t23_exp

    ; --- T24: SAME FSUB operands as T23, poisoned to FLOOR beforehand.
    ; Must match T23 exactly - without fsub's own entry-point reset,
    ; this returns FP2 unchanged instead of the real difference. ---
    FP_ERROR_INIT_MACRO @t24_poison_recover
    FP_LOAD1_MACRO t24_poison_a        ; a genuine FMUL FLOOR case
    FP_LOAD2_MACRO t24_poison_b
    jsr FP_FMUL
    FP_ERROR_CLEAR_MACRO
@t24_poison_recover:
    FP_ERROR_INIT_MACRO @t24_recover
    FP_LOAD1_MACRO t23_a
    FP_LOAD2_MACRO t23_b
    jsr FP_FSUB
    FP_ERROR_CLEAR_MACRO
@t24_recover:
    TEST_FP1CMP_MACRO 24, @msg_t24, t23_exp

    ; --- T25: SAME FSUB operands as T23, poisoned to CEILING
    ; beforehand. Must match T23 exactly - without fsub's own reset,
    ; this produces a wildly wrong magnitude AND sign. ---
    FP_ERROR_INIT_MACRO @t25_poison_recover
    FP_LOAD1_MACRO t22_poison_a        ; reuse T22's FMUL CEILING case
    FP_LOAD2_MACRO t22_poison_b
    jsr FP_FMUL
    FP_ERROR_CLEAR_MACRO
@t25_poison_recover:
    FP_ERROR_INIT_MACRO @t25_recover
    FP_LOAD1_MACRO t23_a
    FP_LOAD2_MACRO t23_b
    jsr FP_FSUB
    FP_ERROR_CLEAR_MACRO
@t25_recover:
    TEST_FP1CMP_MACRO 25, @msg_t25, t23_exp

    ; --- T26: FMUL CEILING straddle, ALREADY-NORMALIZED mantissa -
    ; the ~28.4% sub-case (corrected from the original mismeasured
    ; 2%) where NO decrement occurs and the result genuinely,
    ; correctly overflows. Confirmed via diag26.py's own sweep. ---
    FP_ERROR_INIT_MACRO @t26_recover
    FP_LOAD1_MACRO t26_a
    FP_LOAD2_MACRO t26_b
    jsr FP_FMUL
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 26, @msg_t26
    jmp @t26_done
@t26_recover:
    lda FP_ERROR_CODE
    cmp #FP_ERROR_CODE_GENERIC_OVERFLOW
    bne @t26_wrong_code
    TEST_PASSED_MACRO_V2 26, @msg_t26
    jmp @t26_done
@t26_wrong_code:
    TEST_FAILED_MACRO_V2 26, @msg_t26
@t26_done:

    ; --- T27: FMUL CEILING straddle, NEEDS-DECREMENT mantissa - the
    ; ~71.6% sub-case where norm1's rescue correctly fires. Confirmed
    ; via diag26.py's own sweep. ---
    FP_ERROR_INIT_MACRO @t27_recover
    FP_LOAD1_MACRO t27_a
    FP_LOAD2_MACRO t27_b
    jsr FP_FMUL
    FP_ERROR_CLEAR_MACRO
    TEST_FP1CMP_MACRO 27, @msg_t27, t27_exp
    jmp @t27_done
@t27_recover:
    TEST_FAILED_MACRO_V2 27, @msg_t27
@t27_done:

    ; --- T28: FDIV 2nd collision, VALID FLOOR (te2-te1=-128), NO
    ; decrement needed - must succeed, staying at the true floor.
    ; Confirmed via diag23.py. ---
    FP_ERROR_INIT_MACRO @t28_recover
    FP_LOAD1_MACRO t28_divisor
    FP_LOAD2_MACRO t28_dividend
    jsr FP_FDIV
    FP_ERROR_CLEAR_MACRO
    TEST_FP1CMP_MACRO 28, @msg_t28, t28_exp
    jmp @t28_done
@t28_recover:
    TEST_FAILED_MACRO_V2 28, @msg_t28
@t28_done:

    ; --- T29: FDIV 2nd collision, VALID FLOOR (te2-te1=-128), NEEDS
    ; decrement - true final would be -129 (invalid), must FORCE
    ; ZERO. This is the case that was 48% silently corrupted before
    ; the fix (diag24.py). ---
    FP_ERROR_INIT_MACRO @t29_recover
    FP_LOAD1_MACRO t29_divisor
    FP_LOAD2_MACRO t29_dividend
    jsr FP_FDIV
    FP_ERROR_CLEAR_MACRO
    lda FP1_EXP
    bne @t29_fail
    lda FP1_MANT
    ora FP1_MANT+1
    ora FP1_MANT+2
    bne @t29_fail
    TEST_PASSED_MACRO_V2 29, @msg_t29
    jmp @t29_done
@t29_fail:
    TEST_FAILED_MACRO_V2 29, @msg_t29
    jmp @t29_done
@t29_recover:
    TEST_FAILED_MACRO_V2 29, @msg_t29
@t29_done:

    ; --- T30: FDIV 2nd collision, INVALID one-past-ceiling
    ; (te2-te1=128), NO decrement needed - true final genuinely IS
    ; 128 (invalid), must TRAP. Confirmed via diag25.py's clean
    ; single-instruction trace (the case that originally exposed
    ; the harness's own .rts1-early-stop bug). ---
    FP_ERROR_INIT_MACRO @t30_recover
    FP_LOAD1_MACRO t30_divisor
    FP_LOAD2_MACRO t30_dividend
    jsr FP_FDIV
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 30, @msg_t30
    jmp @t30_done
@t30_recover:
    lda FP_ERROR_CODE
    cmp #FP_ERROR_CODE_GENERIC_OVERFLOW
    bne @t30_wrong_code
    TEST_PASSED_MACRO_V2 30, @msg_t30
    jmp @t30_done
@t30_wrong_code:
    TEST_FAILED_MACRO_V2 30, @msg_t30
@t30_done:

    ; --- T31: FDIV 2nd collision, INVALID one-past-ceiling
    ; (te2-te1=128), NEEDS decrement - true final becomes 128-1=127
    ; (VALID, the true ceiling), must be RESCUED, not trapped. This
    ; is the case that was 100% spuriously trapped before the fix
    ; (diag24.py). ---
    FP_ERROR_INIT_MACRO @t31_recover
    FP_LOAD1_MACRO t31_divisor
    FP_LOAD2_MACRO t31_dividend
    jsr FP_FDIV
    FP_ERROR_CLEAR_MACRO
    TEST_FP1CMP_MACRO 31, @msg_t31, t31_exp
    jmp @t31_done
@t31_recover:
    TEST_FAILED_MACRO_V2 31, @msg_t31
@t31_done:

    rts

.segment "RODATA"
@msg_header: .asciiz "fp exponent boundary (all)"

@msg_t00: .asciiz "fadd (ff+10)"
@msg_t01: .asciiz "fadd (10+ff)"
@msg_t02: .asciiz "fsub (ff-10)"
@msg_t03: .asciiz "fsub (10-ff)"
@msg_t04: .asciiz "fmul trap (ff*10)"
@msg_t05: .asciiz "fdiv (ff/10)"
@msg_t06: .asciiz "compare (ff,10)"
@msg_t07: .asciiz "fsub trap (boundary mantissa)"
@msg_t08: .asciiz "asciisci (ff)"
@msg_t09: .asciiz "fp->ieee754 (ff)"
@msg_t10: .asciiz "fp->basic trap (ff)"

@msg_t11: .asciiz "fmul regres (10*10)"
@msg_t12: .asciiz "fmul motive (2.2e38)"
@msg_t13: .asciiz "fmul overflow (sum=128)"
@msg_t14: .asciiz "fmul underflow (sum=-131)"
@msg_t15: .asciiz "fmul u/l (sum=127)"
@msg_t16: .asciiz "fmul l/l (sum=-128)"
@msg_t17: .asciiz "fdiv u/l (q=127)"
@msg_t18: .asciiz "fdiv overflow (q=128)"
@msg_t19: .asciiz "fdiv underflow (q=-129)"
@msg_t20: .asciiz "fmul underflow (sum=-129)"

@msg_t21: .asciiz "fadd flag=normal"
@msg_t22: .asciiz "fadd flag poisoned"
@msg_t23: .asciiz "fsub flag=normal"
@msg_t24: .asciiz "fsub flag p'd (l/l)"
@msg_t25: .asciiz "fsub flag p'd (u/l)"

; --- RODATA additions ---
@msg_t26: .asciiz "fmul ceiling, no-dec (trap)"
@msg_t27: .asciiz "fmul ceiling, dec/r"
@msg_t28: .asciiz "fdiv 2nd/c,floor nd"
@msg_t29: .asciiz "fdiv 2nd/c,floor dec (0)"
@msg_t30: .asciiz "fdiv 2nd/c,ceil+1 ndt"
@msg_t31: .asciiz "fdiv 2nd/c,cei+1 dr"

; --- Section A operands ---
@exp_t08:        .asciiz "1.899985e+38"
ff_val:          .byte $ff,$47,$78,$43
ff_val_boundary: .byte $ff,$80,$00,$00

; --- Section B operands (from tr_exp_muldiv_boundary.s, hardware-
; confirmed) ---
t12_a:      .byte $95,$43,$23,$80   ; 2,200,000.0
t12_b:      .byte $ea,$4e,$e2,$d7   ; 10^32
t13_a:      .byte $c0,$40,$00,$00   ; 1.0 * 2^64
t13_b:      .byte $c0,$40,$00,$00   ; 1.0 * 2^64 -> sum=128
t14_a:      .byte $3f,$40,$00,$00   ; te=-65
t14_b:      .byte $3e,$40,$00,$00   ; te=-66 -> sum=-131
t15_a:      .byte $c0,$40,$00,$00   ; te=64
t15_b:      .byte $bf,$40,$00,$00   ; te=63 -> sum=127
t15_exp:    .byte $ff,$40,$00,$00
t16_a:      .byte $40,$40,$00,$00   ; te=-64
t16_b:      .byte $40,$40,$00,$00   ; te=-64 -> sum=-128
t16_exp:    .byte $00,$40,$00,$00
t17_dividend: .byte $c0,$40,$00,$00 ; te=64
t17_divisor:  .byte $41,$40,$00,$00 ; te=-63 -> 64-(-63)=127
t18_dividend: .byte $c0,$40,$00,$00 ; te=64
t18_divisor:  .byte $40,$40,$00,$00 ; te=-64 -> 64-(-64)=128
t19_dividend: .byte $40,$40,$00,$00 ; te=-64
t19_divisor:  .byte $c1,$40,$00,$00 ; te=65 -> -64-65=-129
t20_a:        .byte $40,$40,$00,$00 ; 1.0 * 2^-64 (te=-64)
t20_b:        .byte $3f,$40,$00,$00 ; 1.0 * 2^-65 (te=-65) -> sum=-129

; --- Section C operands ---
; T21/T22: FADD at the genuine floor - two small mantissas at
; exponent $00 whose sum needs a renormalizing left-shift. Confirmed
; via diag17.py: sum = $00,40,00,00.
t21_a:   .byte $00,$20,$00,$00
t21_b:   .byte $00,$20,$00,$00
t21_exp: .byte $00,$40,$00,$00

; T22's poison source: an arbitrary genuine FMUL CEILING case
; (reuses T15's own operands/shape) - its OWN result is discarded,
; only its side effect on fp_norm_boundary_state matters.
t22_poison_a: .byte $c0,$40,$00,$00
t22_poison_b: .byte $bf,$40,$00,$00

; T23/T24/T25: FSUB at the same genuine floor, via fcompl's negation
; path (FP1's mantissa is negative, forcing the fcompl detour).
; Confirmed via diag18.py: FP2($00,60,00,00)=4.408...e-39 -
; FP1($00,20,00,00)=1.469...e-39 -> 2.938735877e-39 = $00,40,00,00.
t23_a:   .byte $00,$20,$00,$00
t23_b:   .byte $00,$60,$00,$00
t23_exp: .byte $00,$40,$00,$00

; T24's poison source: an arbitrary genuine FMUL FLOOR case (reuses
; T16's own operands/shape).
t24_poison_a: .byte $40,$40,$00,$00
t24_poison_b: .byte $40,$40,$00,$00

; T26/T27: confirmed via diag26.py's own sweep (seed=0, te_sum=127)
t26_a: .byte $bf,$84,$f8,$cf
t26_b: .byte $c0,$9b,$f4,$b7
; expected: TRAPS, code 0 (generic overflow) - no expected bytes

t27_a: .byte $bf,$6f,$47,$90
t27_b: .byte $c0,$47,$30,$80
t27_exp: .byte $ff,$7b,$c7,$b7  ; $b6

; T28/T29: confirmed via diag23.py/diag24.py (te2-te1=-128)
t28_divisor:  .byte $c0,$40,$00,$00
t28_dividend: .byte $40,$40,$00,$00
t28_exp:      .byte $00,$40,$00,$00

t29_divisor:  .byte $c0,$84,$f8,$cf
t29_dividend: .byte $40,$9b,$f4,$b7
; expected: canonical zero - no expected-bytes constant needed,
; checked directly via FP1_EXP/FP1_MANT above

; T30/T31: confirmed via diag24.py/diag25.py (te2-te1=128)
t30_divisor:  .byte $40,$40,$00,$00
t30_dividend: .byte $c0,$40,$00,$00
; expected: TRAPS, code 0 (generic overflow) - no expected bytes

t31_divisor:  .byte $40,$84,$f8,$cf
t31_dividend: .byte $c0,$9b,$f4,$b7
t31_exp:      .byte $ff,$68,$16,$4e
.endproc
