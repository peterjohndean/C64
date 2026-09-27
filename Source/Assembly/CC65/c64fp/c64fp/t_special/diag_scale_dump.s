.include "../t_routines/tr.inc"

.export DIAG_SCALE_DUMP

.import FP_FROM_ASCII_SCI, FP_FMUL
.import FP_CLEANUP_FAC1FAC2

; ============================================================
; FILE    : diag_scale_dump.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; ONE-OFF DIAGNOSTIC, NOT PERMANENT REGRESSION COVERAGE. Not part of
; fp_tests.s's dispatch table - do not add it there. Its job is to
; answer exactly one question and then be deleted or archived:
; WHERE, in FP_FROM_ASCII_SCI_PROC's 38-iteration "multiply by 10.0"
; scaling loop (parsing something like "1.9E+38"), does the running
; value first diverge from the mathematically correct trajectory?
;
; WHY THIS EXISTS (recap of the conversation that produced it)
; -----------------------------------------------------------------
; A prior session confirmed, via tr_exp_boundary.s's T00/T01, that
; FP_CORE_PROC's own overflow check (the md2/ovchk/md3 block in
; lib_fp.s) is CORRECT - S=127 cleanly produces exponent byte $FF
; with no trap, and S=128 cleanly traps. That rules out FP_CORE_PROC
; as the source of the bug. Separately, a Python recomputation of the
; TRUE binary exponent trajectory for 1.9 * 10^k (k=1..38) shows the
; correct target NEVER exceeds byte $FF at any single step - meaning
; a real trap anywhere in this chain is unambiguously a rounding/
; drift artifact of the CHAIN, not a legitimate boundary case. This
; file finds exactly which iteration that drift first appears at,
; by replicating the real loop instruction-for-instruction (3 lines:
; FP_LOAD2_MACRO ten_const / jsr FP_FMUL / dec+bne - see
; lib_fp_from_ascii_sci.s's own @scale_multiply_loop) and dumping
; FP1_EXP against a precomputed reference table after every call.
;
; WHY THE MANTISSA IS PARSED VIA THE REAL FP_FROM_ASCII_SCI, NOT
; HAND-CONSTRUCTED
; -----------------------------------------------------------------
; Unlike tr_exp_boundary.s (which hand-built FP1/FP2 bytes to isolate
; FP_CORE_PROC from any parsing effects), this diagnostic is
; INVESTIGATING the parsing/scaling side, so it deliberately starts
; from whatever FP_FROM_ASCII_SCI_PROC's own already-tested mantissa
; parser actually produces for "1.9" - that part of the parser isn't
; in question here (it's exercised and passing elsewhere in
; tr_ascii_sci.s), so reusing it keeps this diagnostic focused on the
; ONE piece of code actually under suspicion: the scaling loop.
;
; REFERENCE TABLE - HOW IT WAS COMPUTED
; -----------------------------------------------------------------
; expected_table[k-1] = floor(log2(1.9 * 10^k)) + 128, k=1..38,
; computed in double-precision Python (not this format's own ~1e-7
; relative precision) - i.e. this is the exponent byte a perfectly
; exact multiply-by-10 chain would produce at each step. This
; library's own ~1e-7 relative precision floor means the LAST digit
; of the MANTISSA can legitimately differ from a double-precision
; reference without that being a bug - what this table checks is
; coarser and much more diagnostic than that: whether the EXPONENT
; BYTE (which only changes a handful of times total, at each power-
; of-2 crossing) matches. A mismatch there means an entire spurious
; (or missing) doubling occurred somewhere in the chain - not
; ordinary last-bit rounding noise.
;
; HOW TO READ THE OUTPUT
; --------------------------
; Each line: "n=NN act=$AA exp=$EE  mant=$MM MM MM" where NN is the
; iteration (1-38), AA is FP1_EXP after that iteration's FP_FMUL,
; EE is the reference table's expected byte, MM MM MM is FP1_MANT.
; A line ending in " <-- mismatch" is the FIRST place actual and
; expected diverge - that iteration's FP_FMUL call is where to put
; the next VICE breakpoint (at FP_CORE_PROC's fmul/mul1 loop) and
; look at the RAW 24-bit product before normalization, not just the
; final normalized result this dump shows.
; If a trap occurs instead of reaching n=38, that iteration number
; is printed directly - per lib_fp_error.s's own documented contract,
; FP1/FP2's contents right after a trap are NOT meaningful, so this
; tool deliberately does not print them at that point (see the
; comment at @print_trap below).
;
; HOW TO INVOKE
; ----------------
; Not wired into fp_tests.s on purpose (this is disposable, not
; regression coverage). JSR DIAG_SCALE_DUMP from wherever is
; convenient for a one-off run - a temporary SYS entry point, or a
; throwaway call inserted at the top of your existing test harness's
; main routine. Remove the call (and this file) once the actual
; divergence point has been found and the real fix is written and
; verified.
;
; [BUG FIX] WHY EVERY PRINTED LINE MUST COME FROM A SNAPSHOT, NEVER
; DIRECTLY FROM FP1_EXP/FP1_MANT
; -----------------------------------------------------------------
; FP1 is aliased onto BASIC's own FAC1 zero page ($61-$6E - see
; labels_fp.s's own ZERO PAGE MAP note), and BASIC_STROUT is already
; documented elsewhere in this codebase as corrupting FAC1/FAC2 when
; called. An earlier version of this file called BASIC_STROUT_MACRO
; (for the "act=$"/"exp=$"/"mant=$" labels) BEFORE reading FP1_EXP
; in @print_line - meaning FP1 got clobbered to some fixed leftover
; state on the VERY FIRST print, and since this loop (unlike every
; tr_xxx.s test, which reloads FP1 fresh before each operation)
; CARRIES FP1 forward as the running accumulator across iterations,
; that corruption fed straight into the next iteration's FP_FMUL as
; if it were the real value - confirmed on real hardware: every
; single line printed the exact same bytes (act=$06, mant=$850a19),
; n=1 through n=38, which is the unmistakable signature of FP1 never
; actually carrying a value forward at all. The fix: snapshot FP1
; into ordinary (non-FAC-aliased) RAM immediately after FP_FMUL,
; BEFORE any BASIC_STROUT call, print only from that snapshot, and
; restore FP1 from it before the next iteration's FP_FMUL runs. This
; is the same "transient use only, never held across a JSR out to
; other code" caution labels_fp.s already documents for FP_STRPTR
; and the REU library's own aliasing-detection scratch bytes -
; applied here to FP1/FP2 themselves, which turns out to need it too
; whenever a loop (unusually) holds a live FP1 across a print call.
; ============================================================
.segment "CODE"
.proc DIAG_SCALE_DUMP
    TEST_ROUTINE_HEADER_MACRO msg_header
    
    BASIC_STROUT_MACRO msg_banner
    KERNAL_CHROUT_MACRO $0d

    ; --- parse the mantissa only, via the REAL, already-tested
    ;     parser - see the file header for why this part is reused
    ;     rather than hand-constructed ---
    lda #<mantissa_str
    ldy #>mantissa_str
    jsr FP_FROM_ASCII_SCI
    bcc @have_mantissa
    BASIC_STROUT_MACRO msg_parse_fail   ; shouldn't happen for "1.9" -
    jmp @done

@have_mantissa:
    lda #0
    sta iter_count

@loop:
    inc iter_count

    ; --- this IS lib_fp_from_ascii_sci.s's own @scale_multiply_loop
    ;     body, verbatim (FP_LOAD2_MACRO / jsr FP_FMUL) - the only
    ;     addition is the FP_ERROR_INIT_MACRO guard (so a trap stops
    ;     THIS diagnostic cleanly instead of crashing) and the dump
    ;     call after each iteration ---
    FP_LOAD2_MACRO LIBFP_CONSTANTS::ten_const
    FP_ERROR_INIT_MACRO @trapped
    jsr FP_FMUL
    FP_ERROR_CLEAR_MACRO

    ; --- [BUG FIX] snapshot FP1 to scratch RAM BEFORE any printing -
    ;     see the file header's [BUG FIX] note. @print_line reads
    ;     ONLY snap_exp/snap_mant from here on, never FP1_EXP/
    ;     FP1_MANT directly, so BASIC_STROUT's FAC1 corruption inside
    ;     it can't touch the value being reported. ---
    lda FP1_EXP
    sta snap_exp
    lda FP1_MANT
    sta snap_mant
    lda FP1_MANT+1
    sta snap_mant+1
    lda FP1_MANT+2
    sta snap_mant+2

    jsr @print_line

    ; --- [BUG FIX] restore FP1 from the snapshot before the NEXT
    ;     iteration's FP_FMUL - load-bearing, not defensive: without
    ;     this, @print_line's own BASIC_STROUT calls (which ran
    ;     between the snapshot above and here) have already clobbered
    ;     the LIVE FP1_EXP/FP1_MANT that the next FP_FMUL would
    ;     otherwise read as its running accumulator. ---
    lda snap_exp
    sta FP1_EXP
    lda snap_mant
    sta FP1_MANT
    lda snap_mant+1
    sta FP1_MANT+1
    lda snap_mant+2
    sta FP1_MANT+2

    lda iter_count
    cmp #38
    bne @loop

    BASIC_STROUT_MACRO msg_done
    KERNAL_CHROUT_MACRO $0d
    jmp @done

@trapped:
    ; --- FP1/FP2 are left in whatever state the failing FP_FMUL
    ;     abandoned them in - lib_fp_error.s's own header is explicit
    ;     that this is "not meaningful, don't use them without
    ;     reloading first". So this deliberately prints ONLY the
    ;     iteration number and error code, not FP1's bytes - anything
    ;     else would be actively misleading, not just unhelpful. The
    ;     LAST successfully-printed line (from @print_line, the
    ;     previous iteration) is the last KNOWN-GOOD state - that's
    ;     the one to trust, not anything read from FP1 here. ---
    BASIC_STROUT_MACRO msg_trapped
    lda iter_count
    ldx #$20
    jsr OUTPUT_BYTETODEC
    lda #' '
    jsr KERNAL_CHROUT
    BASIC_STROUT_MACRO msg_code
    lda FP_ERROR_CODE
    jsr OUTPUT_BYTETOHEX
    KERNAL_CHROUT_MACRO $0d
    jmp @done

; --- @print_line: "n=NN act=$AA exp=$EE  mant=$MM MM MM[ <-- mismatch]\r"
;     Entry: FP1 already holds this iteration's result, iter_count
;     already incremented (1-38). Destroys A,X,Y (via OUTPUT_BYTETODEC/
;     OUTPUT_BYTETOHEX) - everything needed for the NEXT print_line
;     call is re-read fresh from memory each time, per those routines'
;     own documented register-clobbering, not carried in registers
;     across this routine's own internal calls. ---
@print_line:
    lda #'n'
    jsr KERNAL_CHROUT
    lda #'='
    jsr KERNAL_CHROUT
    lda iter_count
    ldx #$20                    ; space-padded, so columns line up
    jsr OUTPUT_BYTETODEC        ; destroys A,X,Y - prints iter_count

    BASIC_STROUT_MACRO msg_act
    lda snap_exp                ; [BUG FIX] read the SNAPSHOT, not
    sta actual_byte             ; live FP1_EXP - BASIC_STROUT above
                                ; would otherwise be read AFTER it
                                ; already clobbered FP1 (see file
                                ; header's [BUG FIX] note)
    jsr OUTPUT_BYTETOHEX        ; preserves X,Y (see lib_chrout_bytetohex.s's
                                ; own header) - only A needs restoring

    BASIC_STROUT_MACRO msg_exp
    ldy iter_count
    dey                          ; 0-based index into expected_table
    lda expected_table,y
    sta expected_byte
    jsr OUTPUT_BYTETOHEX

    BASIC_STROUT_MACRO msg_mant
    lda snap_mant                ; [BUG FIX] snapshot, not live FP1_MANT
    jsr OUTPUT_BYTETOHEX
    lda snap_mant+1
    jsr OUTPUT_BYTETOHEX
    lda snap_mant+2
    jsr OUTPUT_BYTETOHEX

    lda actual_byte
    cmp expected_byte
    beq @print_cr
    BASIC_STROUT_MACRO msg_mismatch
@print_cr:
    KERNAL_CHROUT_MACRO $0d

@done:
    jsr FP_CLEANUP_FAC1FAC2
    rts

.segment "RODATA"
msg_header:     .asciiz "special: dump scale"

mantissa_str:    .asciiz "1.9"

; --- reference trajectory: floor(log2(1.9*10^k))+128 for k=1..38,
;     computed independently in double-precision Python - see the
;     file header REFERENCE TABLE note. index 0 = k=1 (after the
;     FIRST multiply), ... index 37 = k=38 (the final, full 1.9E+38
;     result). ---
expected_table:
    .byte $84,$87,$8a,$8e,$91,$94,$98,$9b,$9e,$a2
    .byte $a5,$a8,$ac,$af,$b2,$b6,$b9,$bc,$c0,$c3
    .byte $c6,$ca,$cd,$d0,$d3,$d7,$da,$dd,$e1,$e4
    .byte $e7,$eb,$ee,$f1,$f5,$f8,$fb,$ff

msg_banner:      .asciiz "diag: 1.9e+38 scale-loop dump"
msg_parse_fail:  .asciiz "mantissa parse of 1.9 failed - stopping"
msg_done:        .asciiz "done: n=38 reached"
msg_trapped:     .asciiz "trapped at n="
msg_code:        .asciiz " code=$"
msg_act:         .asciiz " act=$"
msg_exp:         .asciiz " exp=$"
msg_mant:        .asciiz "  mant=$"
msg_mismatch:    .asciiz " <-- mismatch"

.segment "BSS"
iter_count:     .byte 0
actual_byte:    .byte 0
expected_byte:  .byte 0
snap_exp:       .byte 0     ; [BUG FIX] FP1_EXP snapshot, taken before
                            ; any BASIC_STROUT call each iteration
snap_mant:      .res 3,0    ; [BUG FIX] FP1_MANT (3 bytes) snapshot, same reasoning
.endproc
