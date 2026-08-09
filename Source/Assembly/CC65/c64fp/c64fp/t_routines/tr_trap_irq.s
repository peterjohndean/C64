
.include "tr.inc"

.export tr_trap_irq

.import FP_FDIV
.import TEST_PASSED, TEST_FAILED   ; only needed if you call these
                                    ; directly rather than through
                                    ; TEST_PASSED_MACRO_V2/
                                    ; TEST_FAILED_MACRO_V2 - kept for
                                    ; clarity; TEST_WAIT itself is
                                    ; NOT called directly by this file
                                    ; anymore (see the [BUG FIX] note
                                    ; at local_recovery below for why)

.segment "CODE"
; ============================================================
; FILE    : tr_trap_irq.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; A single, deliberately-provoked trap - a division by zero, fired
; from INSIDE a php/sei-protected critical section with no local
; error guard - to exercise the exact code path lib_fp_error.s's
; [BUG FIX] CLI in FP_ERROR_PROC exists to fix. This isn't testing
; FP_FDIV itself (that's already covered elsewhere); it's testing
; FP_ERROR_PROC's UNWIND MECHANISM's interaction with an
; interrupt-disabled critical section.
;
; THE BUG THIS PINS DOWN
; -------------------------
; FP_ERROR_PROC's unwind (ldx FP_ERROR_SP / txs / ...) is a raw
; stack-pointer restore, not an ordinary RTS chain - by design, it
; discards EVERYTHING pushed above the depth FP_ERROR_INIT_MACRO
; recorded, not just return addresses. A php-pushed status byte is
; just another byte on that same stack. If a trap fires while
; execution is inside a php/sei window, and the guard actually used
; to unwind was armed BEFORE that window opened (exactly fp_tests.s's
; own situation: its FP_ERROR_INIT_MACRO is armed once, before @loop
; even starts, well before any individual test's php/sei), the
; matching plp is never reached - the sei's effect is never undone,
; and interrupts stay disabled for the rest of the program's life
; (not scoped to this .proc, or even this SYS call). See
; lib_fp_error.s's FP_ERROR_PROC for the CLI that now closes this.
;
; WHY THIS TEST ARMS ITS OWN LOCAL GUARD (NOT FP_TESTS'S SHARED ONE)
; -----------------------------------------------------------------------
; An earlier version of this test relied entirely on the guard
; fp_tests.s itself arms once, before @loop starts, assuming
; FP_ERROR_SP would still point there by the time this (deliberately
; last-registered) test ran. Confirmed WRONG on real hardware: by the
; time this test runs, several earlier tests in the suite have almost
; certainly armed and CLEARED their own local guards for their own
; deliberate-trap tests (div-by-zero, log domain error, exp overflow,
; the tan asymptote - all exist elsewhere in this library) - per
; lib_fp_error.s's own documented contract, "FP_ERROR_SP IS STALE ONCE
; CONSUMED". The observed failure: the trap below unwound using
; whatever stale depth an EARLIER test's cleared guard left behind,
; not fp_tests.s's outer one, walking back out past fp_tests.s AND
; main.s entirely, straight to BASIC's READY. prompt - no "unexpected
; error" ever printed. fp_tests.s's unexpected_trap-based IRQ check
; was consequently never even reached by this test.
;
; Fix: arm THIS TEST'S OWN guard, immediately before the php/sei
; below, pointing at a LOCAL recovery label in this same file. That
; makes the test deterministic regardless of what any other test in
; the suite did before it, and - as a bonus - means this test now
; returns normally to fp_tests.s's @loop afterward instead of
; aborting the rest of the suite, so it no longer needs to be
; registered last (though there's no harm in leaving it there).
;
; WHY THIS TEST STILL DOESN'T FOLLOW THE USUAL TEST_WAIT/rts SHAPE
; -----------------------------------------------------------------------
; Every other test file in this suite eventually falls through to
; TEST_WAIT/an rts, back into fp_tests.s's @loop, having printed a
; pass/fail via TEST_CHECK/TEST_FP1CMP/TEST_STRCMP. This one prints
; its own pass/fail directly at its local recovery label instead (see
; local_recovery below) - there's no floating point RESULT to compare
; here (the "result" under test is a CPU flag, not an FP1 value), so
; none of the usual TEST_*CMP machinery applies. It still ends by
; falling into TEST_WAIT/returning to @loop like everything else,
; once its own guard (not fp_tests.s's) has done its job.
;
; WHY FP_FDIV WITH A ZERO DIVISOR, SPECIFICALLY
; -------------------------------------------------
; The most explicit, deterministic trap in the whole library:
; library_fp.s's fdiv checks FP1_EXP (the divisor) for exact zero
; BEFORE any exponent/shift arithmetic runs at all, and reports it as
; error code 1 (division by zero) every time, unconditionally - no
; dependence on rounding, magnitude, or any other value-specific
; edge case that could make this test flaky or unclear about what,
; exactly, triggered it.
;
; WHAT A FAILURE HERE WOULD MEAN
; ---------------------------------
; If FP_ERROR_PROC's CLI (lib_fp_error.s) is ever removed or
; regresses, this test reports FAIL on its own IRQ check immediately
; - and, less visibly but far worse, the C64 would be left running
; with interrupts permanently disabled: no blinking cursor, no
; keyboard repeat, no jiffy clock, and (per the actual bug this was
; written to catch) any subsequent serial/IEC bus operation - printer
; output being the one that surfaced it - hanging indefinitely
; waiting on IRQ-driven bus timing that will never happen.
;
; VERIFIED ON HARDWARE (partially - see the note above)
; -----------------------------------------------------------------
; The FIRST version of this test (relying on fp_tests.s's shared
; guard) was run on real hardware and confirmed NOT to reach
; fp_tests.s's IRQ check at all, for the stale-guard reason explained
; above - that failure is what led to this self-contained redesign.
; This version has NOT yet itself been confirmed on VICE/hardware -
; do that before trusting it, per this project's usual workflow.
;
; Entry   : none (called via fp_tests.s's SMC dispatch, same as every
;           other entry in test_vectors)
; Exit    : returns normally via TEST_WAIT, same as any other test -
;           see above for why this no longer needs to be last in
;           test_vectors
; Destroys: A, X, Y; FP1, FP2; whatever FP_FDIV itself destroys
; ============================================================
.proc tr_trap_irq
    ; -----------------------------------------------------------------
    ; No separate "announcing" print here (an earlier draft had one,
    ; now removed) - TEST_PASSED_MACRO_V2/TEST_FAILED_MACRO_V2 below
    ; already call SET_TESTDATA_SCOPE_MACRO + SHOW_CURRENT_TEST_MACRO
    ; internally (see tp_passed.s/tp_failed.s), so a manual print here
    ; would just duplicate the group/test number and message a second
    ; time before the real one.
    ; -----------------------------------------------------------------

    ; --- arm OUR OWN guard, BEFORE the critical section below ---
    ; This is the exact vulnerable shape being tested: a guard armed
    ; OUTSIDE/BEFORE a php/sei window, with the risky call happening
    ; INSIDE that window - see the file header for why this must be
    ; a local guard rather than relying on fp_tests.s's shared one.
    FP_ERROR_INIT_MACRO @local_recovery

    ; --- begin interrupt-protected critical section -----------
    ; php/sei, matching the pattern this suite's own SMC-patched
    ; comparison loops already use (tp_fp1cmp.s, tp_strcmp.s) -
    ; that's deliberate: this test is only meaningful if it
    ; reproduces the SAME shape of critical section a real bug
    ; would occur inside of, not a synthetic worst case.
    php
    sei

    FP_LOAD1_MACRO zero_const   ; FP1 = 0.0 - FP_FDIV's DIVISOR
    FP_LOAD2_MACRO one_const    ; FP2 = 1.0 - the dividend (value
                                ; doesn't matter - only the zero
                                ; divisor triggers the trap)
    jsr FP_FDIV                 ; traps: divisor is exactly 0.0 -
                                ; see the file header. Unwinds via
                                ; OUR guard above straight to
                                ; local_recovery below - the plp and
                                ; FP_ERROR_CLEAR_MACRO immediately
                                ; after this call are the SUCCESS
                                ; path and are never reached (this
                                ; call is guaranteed to trap - see
                                ; WHY FP_FDIV above)

    plp                          ; unreachable success-path release -
                                 ; documents what a non-trapping call
                                 ; inside this critical section would
                                 ; have needed to do
    FP_ERROR_CLEAR_MACRO         ; unreachable success-path guard
                                 ; release, for the same reason
    rts                          ; also unreachable, same reason -
                                 ; matches the "success path would
                                 ; just return normally" shape

@local_recovery:
    ; --- this IS reached: the trap landed here via OUR guard -----
    ; If lib_fp_error.s's CLI fix is working, interrupts are enabled
    ; here despite the sei above never having reached its plp (the
    ; unwind discarded that php-pushed byte along with everything
    ; else above our recorded stack depth - see the file header).
    ; Check directly with the standard php/pla flag-read idiom -
    ; there's no "read status into A" instruction, so this pushes
    ; status and immediately pulls it back rather than discarding it.
    php
    pla
    and #%00000100           ; isolate the I (interrupt disable) flag
    beq @irq_ok               ; zero: I flag clear, interrupts enabled

    ; -----------------------------------------------------------------
    ; [BUG FIX] Call the pass/fail macro EXACTLY ONCE, as the very
    ; last action on each branch, followed by our OWN rts - not a
    ; second unconditional macro call afterward, and not an extra
    ; explicit jsr TEST_WAIT.
    ;
    ; WHY THE EARLIER VERSION CRASHED
    ; ----------------------------------
    ; TEST_PASSED_PROC/TEST_FAILED_PROC (tp_passed.s/tp_failed.s) both
    ; end with `jmp TEST_WAIT`, not jsr/rts - a deliberate tail call:
    ; since they're entered via jsr, the return address still on the
    ; stack belongs to OUR code, and TEST_WAIT's own rts pops that,
    ; landing back right after wherever we invoked the macro from.
    ; The previous version of this file called the macro TWICE in a
    ; row (once here, once unconditionally afterward for a second,
    ; meaningless "message") and THEN added a third, fully redundant
    ; `jsr TEST_WAIT` with nothing after it. Once that extra call
    ; returned, execution fell straight off the end of this .proc and
    ; began executing zero_const/one_const/the message strings as if
    ; they were 6502 instructions - that's what actually crashed,
    ; not the trap-and-recover mechanism itself (which was already
    ; working correctly, per the PASS result seen before the crash).
    ;
    ; Also worth noting: TEST_FAILED dumps TestData::fac_snapshot (a
    ; copy of FP1) as the "got" value - meaningless here, since this
    ; test checks a CPU flag, not an FP1 result. Using it anyway
    ; keeps this test consistent with the rest of the suite's shared
    ; reporting infrastructure rather than hand-rolling a one-off
    ; printer; the hex bytes shown on a FAIL just aren't meaningful
    ; and shouldn't be read as anything.
    ; -----------------------------------------------------------------
    TEST_FAILED_MACRO_V2 0, msg_t00
    rts
@irq_ok:
    TEST_PASSED_MACRO_V2 0, msg_t00
    rts

zero_const: .byte $00,$00,$00,$00   ; 0.0 (canonical zero - exponent
                                    ; byte 0 marks canonical zero
                                    ; regardless of mantissa content;
                                    ; see labels_fp.s / the "exponent
                                    ; 0 = canonical zero" note reused
                                    ; throughout this library, e.g.
                                    ; lib_fp_compare.s)
one_const:  .byte $80,$40,$00,$00   ; 1.0 (same bytes used for 1.0
                                    ; elsewhere in this library, e.g.
                                    ; lib_fp_floor.s's one_const)
msg_t00:    .asciiz "trap (/0, irq in php/sei)" ; "trap in php/sei: irq enabled after"
.endproc
