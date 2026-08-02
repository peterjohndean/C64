.include "macros_fp.s"
.include "macros_rom_basic.s"
.include "macros_rom_kernal.s"

.export FP_ERROR

.segment "CODE"

; ============================================================
; FILE    : lib_fp_error.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; Replaces the three bare BRK traps in library_fp.s (FP_CORE_PROC's
; overflow trap, FP_LOG_PROC's domain-error trap, FP_EXP_PROC's
; overflow trap) with a handler that prints a description of what
; went wrong and then unwinds cleanly, instead of halting via BRK
; or falling through into undefined territory.
;
; MUST INCLUDE BEFORE lib_fp.s
; ------------------------------------
; library_fp.s's trap sites JMP directly to FP_ERROR_PROC by name -
; include this file before it.
;
; THE CONTRACT: CALL FP_ERROR_INIT_MACRO WITH A RECOVERY LABEL
; BEFORE ANY FP OPERATION THAT MIGHT TRAP
; -----------------------------------------------------------------
; FP_ERROR_PROC does not know, and cannot generally know, how many
; JSR levels deep a trap occurred - FP_CORE_PROC's overflow trap
; alone can be reached directly from FADD/FSUB/FMUL/FDIV/FIX, or
; indirectly through any of those when called from deep inside
; FP_LOG_PROC or FP_EXP_PROC. Rather than try to unwind exactly one
; level (which would leave execution resuming inside whichever
; intermediate routine happened to be running, with FP1/FP2 in an
; undefined mid-computation state - not obviously safer than BRK),
; this library uses the same technique as C's setjmp/longjmp:
; FP_ERROR_INIT_MACRO (macros_fp.s) takes a label YOU choose -
; typically placed right after the risky call, or at a dedicated
; error-handling block - and pushes a return address pointing
; there, then records the resulting stack depth. If ANYTHING traps
; afterward, no matter how deep, FP_ERROR_PROC restores that exact
; stack depth and RTS's, which lands at your recovery label as if
; every intervening JSR had never happened. This has the same
; contract as setjmp/longjmp: a trap with no armed recovery point
; is undefined - almost certainly a crash, not a controlled one.
; Every risky call needs its own FP_ERROR_INIT_MACRO immediately
; before it (or one guard can cover several risky calls in a row,
; as long as you're equally happy landing at the same recovery
; label regardless of which one failed).
;
; ONE GUARD AT A TIME - FP_ERROR_SP IS STALE ONCE CONSUMED
; -------------------------------------------------------------
; There's only one recovery point remembered at a time, in one
; zero page byte. Once a guard is consumed - either a trap actually
; unwinds to it, or you discard it yourself with
; FP_ERROR_CLEAR_MACRO on the success path - FP_ERROR_SP still
; holds that OLD stack depth, which no longer corresponds to
; anything real. If something traps again before the NEXT
; FP_ERROR_INIT_MACRO call re-arms it, the unwind uses that stale
; value and the result is exactly the undefined crash this whole
; mechanism exists to prevent. In practice: re-arm immediately
; before every risky call (or block of calls) and don't leave a
; gap of un-guarded FP operations between one guard being consumed
; and the next one being armed. test_fp.s's T32-T36 follow this
; pattern - each arms its own guard right before the call it
; expects might trap, with nothing risky in between.
;
; WHAT THE CALLER SEES ON RETURN
; ---------------------------------
; After a trap, execution resumes at your chosen recovery label,
; with FP_ERROR_CODE (labels_fp.s, $FE) holding the code below.
; FP1/FP2 are left in whatever state the failing operation
; abandoned them in - not meaningful, don't use them without
; reloading first.
;
; ERROR CODES
; ------------
;   0  generic overflow      - FADD/FSUB/FMUL/FDIV/FIX exponent
;                               went out of range (magnitude too
;                               large to represent)
;   1  division by zero      - FP_FDIV's divisor (FP1 on entry) was
;                               exactly 0.0, checked explicitly at
;                               FDIV's entry (see library_fp.s) so
;                               this is reported distinctly rather
;                               than falling through to the generic
;                               overflow trap it would otherwise
;                               eventually hit
;   2  log domain error       - FP_LOG_PROC/FP_LOG10_PROC's argument
;                               was <= 0 (no real logarithm)
;   3  exp overflow            - FP_EXP_PROC's argument was large
;                               enough that e^x overflows this
;                               format's exponent range
;   4  IEEE-754 Infinity
;   5  IEEE-754 NaN
;
; NOTE ON "DIVISION BY ZERO" VS GENERIC OVERFLOW
; --------------------------------------------------
; Verified against the real algorithm (not assumed): with the
; divisor exactly 0.0, FDIV's exponent arithmetic reliably lands in
; the same "looks negative" branch as a genuine magnitude overflow
; would - both routed to the same trap before this file existed.
; The explicit FP1_EXP=0 check added at FDIV's entry (see
; library_fp.s) catches the exact-zero case up front and reports it
; as code 1 before any of that arithmetic runs. A divisor that is
; merely VERY SMALL (not exactly zero) but still produces an
; unrepresentably large quotient will still come through as code 0
; (generic overflow), not code 1 - only literal 0.0 is distinguished.
; ============================================================

.scope FP_MSG
msg0: .asciiz "trapped error: "
msg1: .asciiz "division by zero"
msg2: .asciiz "overflow"
msg3: .asciiz "log domain error"
msg4: .asciiz "exp overflow"
msg5: .asciiz "ieee754 infinity"
msg6: .asciiz "ieee754 nan"
.endscope

; ============================================================
; PROCEDURE : FP_ERROR_PROC
; Purpose : Print a description of a trapped FP error, then unwind
;           to the recovery point recorded by the most recent
;           FP_ERROR_INIT_MACRO (see macros_fp.s and the file
;           header's setjmp/longjmp comparison).
; Entry   : A = error code (see file header)
; Exit    : does not return to its caller in the normal sense -
;           execution resumes after whichever FP_ERROR_INIT_MACRO
;           call is currently active. FP_ERROR_CODE ($FE) holds the
;           code that was passed in A.
; Destroys: A, X; the entire C64 stack above FP_ERROR_SP's saved
;           depth is discarded (this is the point of the unwind)
; ============================================================
.proc FP_ERROR_PROC
    sta FP_ERROR_CODE
    pha
    BASIC_STROUT_MACRO FP_MSG::msg0     ; "trapped error: "
    pla
    cmp #1
    beq @div_zero
    cmp #2
    beq @log_domain
    cmp #3
    beq @exp_ovfl
    cmp #4
    beq @ieee_inf
    cmp #5
    beq @ieee_nan
    BASIC_STROUT_MACRO FP_MSG::msg2     ; default (code 0): "overflow"
    jmp @done
@div_zero:
    BASIC_STROUT_MACRO FP_MSG::msg1
    jmp @done
@log_domain:
    BASIC_STROUT_MACRO FP_MSG::msg3
    jmp @done
@exp_ovfl:
    BASIC_STROUT_MACRO FP_MSG::msg4
    jmp @done
@ieee_inf:
    BASIC_STROUT_MACRO FP_MSG::msg5
    jmp @done
@ieee_nan:
    BASIC_STROUT_MACRO FP_MSG::msg6
@done:
    KERNAL_CHROUT_MACRO $0d
    ldx FP_ERROR_SP                     ; restore the stack depth recorded
    txs                                 ; by FP_ERROR_INIT_MACRO...
    rts                                 ; ...and "return" there
.endproc

; ------------------------------------------------------------
; Short public aliases, matching the rest of the library's
; FP_FADD-style naming (no _PROC suffix).
; ------------------------------------------------------------
FP_ERROR = FP_ERROR_PROC
