
.include "labels_fp.s"
.include "tr.inc"

.export tr_trig_poison

.import FP_SIN_FULL, FP_COS, FP_TAN, FP_COMPARE
.import TEST_PASSED, TEST_FAILED
.import FP_NORM_BOUNDARY_STATE

.segment "CODE"
; ============================================================
; FILE    : tr_trig_poison.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; ============================================================
; PURPOSE
; -------
; Direct-flag-poison coverage for the three trig entry points, the
; same class of gap tr_exp_boundary_all.s's T22/T24/T25 were meant
; to cover for FADD/FSUB - except those three tests DON'T actually
; poison the flag (running an FMUL first clears it again on the
; way out through norm/norm1/rts1's own FP_NORM_STATE_NORMAL_MACRO
; calls). These tests poison FP_NORM_BOUNDARY_STATE DIRECTLY, by
; storing into it, then call the trig function and require the
; result to match the same call made with the flag at its honest
; NORMAL default.
;
; WHAT THIS TESTS
; ---------------
; Every trig entry point routes through FP_FADD/FP_FSUB/FP_FMUL/
; FP_FDIV somewhere inside FP_SIN_FULL/FP_COS/FP_TAN. All four of
; those arithmetic entry points reset FP_NORM_BOUNDARY_STATE to
; NORMAL on entry (the fix documented in lib_fp.s's EXPONENT
; OVERFLOW BOUNDARY note). If any of those resets is ever removed
; or skipped along one of the trig call paths, a stale flag from
; an earlier, unrelated operation could silently corrupt or trap a
; trig result - and nothing in the current trig test suite would
; notice, because no existing trig test poisons the flag.
;
; The chosen angle for every test is rad_30 (30 degrees) - small
; enough that no internal operation's exponent is anywhere near
; the CEILING/FLOOR boundaries the flag actually governs, which
; means a passing result PROVES the flag was reset (not merely
; that the poisoned state happened to coincide with the correct
; routing for this input). A test using an angle that naturally
; lands at FP1_EXP==0 would be weaker.
;
; VERIFICATION STATUS
; -------------------
; New as of this session. Simulator-pending / hardware-pending
; until first run.
; ============================================================
.proc tr_trig_poison
    TEST_ROUTINE_HEADER_MACRO msg_header

    ; --------------------------------------------------------
    ; T00: FP_SIN_FULL, flag = NORMAL (baseline)
    ; --------------------------------------------------------
    lda #FP_NORM_STATE_NORMAL
    sta FP_NORM_BOUNDARY_STATE
    FP_LOAD1_MACRO TestValue::rad_30
    jsr FP_SIN_FULL
    FP_STORE1_MACRO baseline

    ; --------------------------------------------------------
    ; T01: FP_SIN_FULL, flag = CEILING
    ; --------------------------------------------------------
    lda #FP_NORM_STATE_CEILING
    sta FP_NORM_BOUNDARY_STATE
    FP_LOAD1_MACRO TestValue::rad_30
    FP_ERROR_INIT_MACRO t01_recover
    jsr FP_SIN_FULL
    FP_ERROR_CLEAR_MACRO
t01_recover:
    FP_COMPARE_TO_MACRO baseline
    beq @t01_ok
    TEST_FAILED_MACRO_V2 1, msg_t01
    jmp @t01_done
@t01_ok:
    TEST_PASSED_MACRO_V2 1, msg_t01
@t01_done:

    ; --------------------------------------------------------
    ; T02: FP_SIN_FULL, flag = FLOOR
    ; --------------------------------------------------------
    lda #FP_NORM_STATE_FLOOR
    sta FP_NORM_BOUNDARY_STATE
    FP_LOAD1_MACRO TestValue::rad_30
    FP_ERROR_INIT_MACRO t02_recover
    jsr FP_SIN_FULL
    FP_ERROR_CLEAR_MACRO
t02_recover:
    FP_COMPARE_TO_MACRO baseline
    beq @t02_ok
    TEST_FAILED_MACRO_V2 2, msg_t02
    jmp @t02_done
@t02_ok:
    TEST_PASSED_MACRO_V2 2, msg_t02
@t02_done:

    ; --------------------------------------------------------
    ; T03: FP_COS, flag = NORMAL (baseline)
    ; --------------------------------------------------------
    lda #FP_NORM_STATE_NORMAL
    sta FP_NORM_BOUNDARY_STATE
    FP_LOAD1_MACRO TestValue::rad_30
    jsr FP_COS
    FP_STORE1_MACRO baseline

    ; --------------------------------------------------------
    ; T04: FP_COS, flag = CEILING
    ; --------------------------------------------------------
    lda #FP_NORM_STATE_CEILING
    sta FP_NORM_BOUNDARY_STATE
    FP_LOAD1_MACRO TestValue::rad_30
    FP_ERROR_INIT_MACRO t04_recover
    jsr FP_COS
    FP_ERROR_CLEAR_MACRO
t04_recover:
    FP_COMPARE_TO_MACRO baseline
    beq @t04_ok
    TEST_FAILED_MACRO_V2 4, msg_t04
    jmp @t04_done
@t04_ok:
    TEST_PASSED_MACRO_V2 4, msg_t04
@t04_done:

    ; --------------------------------------------------------
    ; T05: FP_COS, flag = FLOOR
    ; --------------------------------------------------------
    lda #FP_NORM_STATE_FLOOR
    sta FP_NORM_BOUNDARY_STATE
    FP_LOAD1_MACRO TestValue::rad_30
    FP_ERROR_INIT_MACRO t05_recover
    jsr FP_COS
    FP_ERROR_CLEAR_MACRO
t05_recover:
    FP_COMPARE_TO_MACRO baseline
    beq @t05_ok
    TEST_FAILED_MACRO_V2 5, msg_t05
    jmp @t05_done
@t05_ok:
    TEST_PASSED_MACRO_V2 5, msg_t05
@t05_done:

    ; --------------------------------------------------------
    ; T06: FP_TAN, flag = NORMAL (baseline)
    ; --------------------------------------------------------
    lda #FP_NORM_STATE_NORMAL
    sta FP_NORM_BOUNDARY_STATE
    FP_LOAD1_MACRO TestValue::rad_30
    jsr FP_TAN
    FP_STORE1_MACRO baseline

    ; --------------------------------------------------------
    ; T07: FP_TAN, flag = CEILING
    ; --------------------------------------------------------
    lda #FP_NORM_STATE_CEILING
    sta FP_NORM_BOUNDARY_STATE
    FP_LOAD1_MACRO TestValue::rad_30
    FP_ERROR_INIT_MACRO t07_recover
    jsr FP_TAN
    FP_ERROR_CLEAR_MACRO
t07_recover:
    FP_COMPARE_TO_MACRO baseline
    beq @t07_ok
    TEST_FAILED_MACRO_V2 7, msg_t07
    jmp @t07_done
@t07_ok:
    TEST_PASSED_MACRO_V2 7, msg_t07
@t07_done:

    ; --------------------------------------------------------
    ; T08: FP_TAN, flag = FLOOR
    ; --------------------------------------------------------
    lda #FP_NORM_STATE_FLOOR
    sta FP_NORM_BOUNDARY_STATE
    FP_LOAD1_MACRO TestValue::rad_30
    FP_ERROR_INIT_MACRO t08_recover
    jsr FP_TAN
    FP_ERROR_CLEAR_MACRO
t08_recover:
    FP_COMPARE_TO_MACRO baseline
    beq @t08_ok
    TEST_FAILED_MACRO_V2 8, msg_t08
    jmp @t08_done
@t08_ok:
    TEST_PASSED_MACRO_V2 8, msg_t08
@t08_done:

    rts

.segment "BSS"
baseline: .res 4

.segment "RODATA"
msg_header: .asciiz "trigonometry: classify-flag poison"
msg_t01:    .asciiz "sin(30) flag=ceiling"
msg_t02:    .asciiz "sin(30) flag=floor"
msg_t04:    .asciiz "cos(30) flag=ceiling"
msg_t05:    .asciiz "cos(30) flag=floor"
msg_t07:    .asciiz "tan(30) flag=ceiling"
msg_t08:    .asciiz "tan(30) flag=floor"
.endproc
