.include "tr.inc"

.export tr_fp_fix

.import FP_FIX
.import TEST_PASSED, TEST_FAILED

; ============================================================
; FILE    : tr_fp_fix.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; Regression coverage for FP_FIX_PROC's (lib_fp.s's fix_conv) early
; overflow check: `cmp #$8f / bcc check_done / [trap]`, added to
; short-circuit the ORIGINAL code's behaviour of looping up to ~112
; pointless shift-and-increment iterations before eventually hitting
; the SAME overflow trap via FP1_EXP wrapping $FF->$00 inside rtlog.
;
; IMPORTANT CLARIFICATION ON WHAT THIS CHECK ACTUALLY FIXES
; -----------------------------------------------------------------
; The original code was NOT silently returning a WRONG result for
; any input - traced by hand: for any exponent > $8E, rtar's `inc
; FP1_EXP` can only ever move AWAY from $8E (it never decrements),
; so the loop was guaranteed to eventually wrap past $FF to $00 and
; hit the SAME generic-overflow trap this new check now reaches
; immediately. This is a genuine, worthwhile EARLY-EXIT
; optimization (fail fast instead of fail slow), not a fix for a
; previously-wrong non-trapping result - there wasn't one. The
; PREVIOUS version of this test file used values deep inside either
; "obviously fine" or "obviously overflows" territory (100.0 and a
; value near this format's own absolute exponent ceiling), which
; can't actually confirm the new check's BOUNDARY ($8F) is exactly
; right - passing those two tests is consistent with the boundary
; being anywhere from $8E to $FF. The tests below sit exactly ON
; the boundary instead.
;
; WHY $8F IS THE CORRECT BOUNDARY (verified, not assumed)
; -----------------------------------------------------------------
; FP_FIX/fix_conv targets FP_FLOAT's own seed exponent $8E (2^14),
; matching a 16-bit SIGNED integer result. Exponent $8F represents
; magnitude >= 2^15 = 32768, which is never representable as a
; 16-bit signed value (max positive is +32767). The one asymmetric
; edge worth checking explicitly: does -32768 (the legitimate
; most-negative 16-bit value) need $8F too, given its MAGNITUDE is
; also exactly 32768? No - traced through FP_FLOAT's actual
; algorithm (not a naive log2-based encoding, which gets this
; specific case wrong - see T02's own comment below), its mantissa
; $80,$00,$00 sits exactly at the "already normalized" boundary
; (top two bits differ: 1,0) at the SEED exponent $8E, with no
; increment ever applied. So $8E genuinely covers the complete
; signed 16-bit range including that edge, and $8F+ genuinely never
; does - the boundary is exact, not off by one in either direction.
;
; TEST INVENTORY
; -----------------
;   T00  20000.0   - exponent EXACTLY $8E, zero shift iterations
;        needed at all. Expect: NO trap.
;   T01  40000.0   - exponent EXACTLY $8F, one step past T00.
;        Expect: TRAP, immediately (this is what actually confirms
;        the new check's boundary, not just "does it trap
;        eventually somewhere").
;   T02  -32768.0  - the asymmetric edge case (magnitude exactly
;        2^15, same as T01's 40000.0, but normalizes to $8E not $8F
;        - see the WHY $8F IS THE CORRECT BOUNDARY note above).
;        Expect: NO trap. This is the test most likely to catch an
;        off-by-one that only affects negative boundary values.
;   T03  32767.0   - largest representable positive 16-bit value,
;        exponent $8E (no shift needed, mantissa NOT at a power-of-
;        2 boundary the way T00/T02 are). Expect: NO trap.
;   T04  100.0     - unchanged from the original version of this
;        file: exponent $86, requires ~8 shift iterations to climb
;        UP to $8E from below. Kept specifically to confirm the new
;        early-exit check (which only fires for exponent >= $8F)
;        doesn't disturb the ordinary convergence path for values
;        that legitimately need shifting. Expect: NO trap.
;   T05  edge_trap_val ($FF,$47,$78,$43, the confirmed "1.9e+38"
;        encoding) - kept from the original file as a "deep inside
;        overflow territory" sanity check alongside the precise
;        boundary tests above, not a replacement for them. Expect:
;        TRAP.
;
; VERIFICATION STATUS
; -----------------------
; All expected outcomes and byte patterns below are HAND-DERIVED,
; cross-checked against this codebase's own already-confirmed
; constants (1.0 = $80,$40,$00,$00 and -1.0 = $7F,$80,$00,$00, per
; lib_fp_ceil.s's neg_one_const comment) before being trusted - but
; NOT yet run against VICE or C64U. Run this, compare against the
; PASS/FAIL output, and correct any mismatch here before treating
; this as settled - same convention as every other test file in
; this library.
; ============================================================
.segment "CODE"
.proc tr_fp_fix
    TEST_ROUTINE_HEADER_MACRO msg_header

    ; --- T00: exponent EXACTLY $8E - no shift iterations needed at
    ;          all. This is the tightest possible "should NOT trap"
    ;          case - if fix_conv's boundary check were even one
    ;          step too aggressive (e.g. cmp #$8e instead of #$8f),
    ;          this is the test that would catch it. ---
    FP_ERROR_INIT_MACRO t00_trapped
    FP_LOAD1_MACRO val_20000
    jsr FP_FIX
    FP_ERROR_CLEAR_MACRO
    TEST_PASSED_MACRO_V2 0, msg_t00
    jmp t00_done
t00_trapped:
    TEST_FAILED_MACRO_V2 0, msg_t00
t00_done:

    ; --- T01: exponent EXACTLY $8F - one step past T00. This is the
    ;          test that actually confirms the NEW early-exit check
    ;          fires at exactly the right boundary, not just
    ;          "somewhere before the format's absolute $FF ceiling". ---
    FP_ERROR_INIT_MACRO t01_recover
    FP_LOAD1_MACRO val_40000
    jsr FP_FIX
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 1, msg_t01
    jmp t01_done
t01_recover:
    TEST_PASSED_MACRO_V2 1, msg_t01
t01_done:

    ; --- T02: -32768.0 - SAME magnitude as T01 (2^15), but this
    ;          format's actual normalization (traced through
    ;          FP_FLOAT, not a naive log2 encoding - see the file
    ;          header) puts it at exponent $8E, not $8F. If this
    ;          traps, either the boundary check has an asymmetry
    ;          for negative values, or this test's own hand-derived
    ;          bytes are wrong - check FP1_MANT against $80,$00,$00
    ;          in the VICE monitor before assuming which. ---
    FP_ERROR_INIT_MACRO t02_trapped
    FP_LOAD1_MACRO val_neg32768
    jsr FP_FIX
    FP_ERROR_CLEAR_MACRO
    TEST_PASSED_MACRO_V2 2, msg_t02
    jmp t02_done
t02_trapped:
    TEST_FAILED_MACRO_V2 2, msg_t02
t02_done:

    ; --- T03: 32767.0 - largest positive 16-bit value, exponent
    ;          $8E but NOT a power-of-2 boundary mantissa (unlike
    ;          T00/T02) - a different flavour of "should work". ---
    FP_ERROR_INIT_MACRO t03_trapped
    FP_LOAD1_MACRO val_32767
    jsr FP_FIX
    FP_ERROR_CLEAR_MACRO
    TEST_PASSED_MACRO_V2 3, msg_t03
    jmp t03_done
t03_trapped:
    TEST_FAILED_MACRO_V2 3, msg_t03
t03_done:

    ; --- T04: 100.0 - unchanged from the original file. Confirms
    ;          the new early-exit check (exponent >= $8F only)
    ;          doesn't disturb the ordinary "climb up from below"
    ;          convergence path for smaller values. ---
    FP_ERROR_INIT_MACRO t04_recover
    FP_LOAD1_MACRO TestValue::val_100
    jsr FP_FIX
    FP_ERROR_CLEAR_MACRO
    TEST_PASSED_MACRO_V2 4, msg_t04
    jmp t04_done
t04_recover:
    TEST_FAILED_MACRO_V2 4, msg_t04
t04_done:

    ; --- T05: deep-overflow sanity check, kept from the original
    ;          file alongside the precise boundary tests above. ---
    FP_ERROR_INIT_MACRO t05_recover
    FP_LOAD1_MACRO edge_trap_val
    jsr FP_FIX
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 5, msg_t05
    jmp t05_done
t05_recover:
    TEST_PASSED_MACRO_V2 5, msg_t05
t05_done:
    rts

.segment "RODATA"
msg_header: .asciiz "conversion: fix (int16)"
msg_t00:    .asciiz "20,000 (exp=$8e, no trap)"
msg_t01:    .asciiz "40,000 (exp=$8f, trap)"
msg_t02:    .asciiz "-32,768 (min, no trap)"
msg_t03:    .asciiz "32,767 (max, no trap)"
msg_t04:    .asciiz "100 (climbs, no trap)"
msg_t05:    .asciiz "1.9e+38 (overflow, trap)"

; --- hand-derived, cross-checked against 1.0/-1.0's own already-
;     confirmed encoding before being trusted - see VERIFICATION
;     STATUS above. Not yet hardware-confirmed. ---
val_20000:      .byte $8e,$4e,$20,$00   ; 20000.0
val_40000:      .byte $8f,$4e,$20,$00   ; 40000.0
val_neg32768:   .byte $8e,$80,$00,$00   ; -32768.0 (NOT $8f - see T02)
val_32767:      .byte $8e,$7f,$ff,$00   ; 32767.0
edge_trap_val:  .byte $ff,$47,$78,$43   ; 1.9e+38, hardware-confirmed (see tr_ascii_sci.s's own T11)
.endproc
