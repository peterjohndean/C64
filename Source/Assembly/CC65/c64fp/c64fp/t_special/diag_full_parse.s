.include "../t_routines/tr.inc"

.export DIAG_FULL_PARSE

.import FP_FROM_ASCII_SCI
.import OUTPUT_BYTETOHEX
.import FP_CLEANUP_FAC1FAC2

; ============================================================
; FILE    : diag_full_parse.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; ONE-OFF DIAGNOSTIC, NOT PERMANENT REGRESSION COVERAGE - same
; status as diag_scale_dump.s and diag_exp_digit_parse.s.
;
; The two previous diagnostics this session independently proved:
;   - FP_CORE_PROC's overflow check is correct (tr_exp_boundary.s
;     T00/T01: S=127 -> $FF cleanly, S=128 -> clean trap)
;   - FP_FROM_ASCII_SCI_PROC's @scale_multiply_loop is correct when
;     driven with mantissa=1.9 and a hand-set scale_count=38
;     (diag_scale_dump.s: matched the exact reference trajectory on
;     all 38 steps, reached $FF, no trap)
;   - FP_FROM_ASCII_SCI_PROC's exponent-digit parser is correct:
;     "e+38" produces exp_value=38, exp_is_negative=0
;     (diag_exp_digit_parse.s)
;
; Every piece checked out. This diagnostic is the one test that
; hasn't actually been run yet: the REAL, completely unmodified
; FP_FROM_ASCII_SCI_PROC, called ONCE, on a string this file
; constructs itself (so there is no possibility of stale buffer
; content, leftover digits from a previous UI entry, or anything
; else upstream of the parser - see WHY THIS MATTERS below).
;
; TWO POSSIBLE OUTCOMES, AND WHAT EACH ONE MEANS
; -----------------------------------------------------------------
;   1. This SUCCEEDS (FP1_EXP=$FF, matching what all three isolated
;      pieces already predict): this is a strong result. It would
;      mean FP_FROM_ASCII_SCI_PROC itself is entirely innocent, end
;      to end, for this exact input - and the real "1.9E+38 traps"
;      bug reported from the converter UI is NOT in this library at
;      all. It's upstream, in whatever code builds/holds the string
;      the UI actually hands to FP_FROM_ASCII_SCI_PROC - e.g. a
;      stale or padded edit buffer, given this project's own memory
;      of a SEPARATE, already-known, still-unresolved bug in that
;      UI ("changing from a larger to smaller decimal value appears
;      to retain the previous result"). Worth literally dumping the
;      exact bytes of the string the UI is passing at the real call
;      site, rather than assuming it's a clean "1.9E+38".
;   2. This TRAPS: genuinely surprising given the three isolated
;      results above, and means there's an interaction between the
;      mantissa pass, the exponent-digit pass, and the scale loop
;      that none of the three isolated tests exercised - at that
;      point the right move is an actual VICE single-step through
;      the whole real proc for this one input (not another isolated
;      unit test - the isolation approach has now ruled out every
;      individual piece, so what's left to find is necessarily about
;      how they're sequenced together).
;
; WHY THIS MATTERS: RULING OUT "IT'S NOT THE STRING I THINK IT IS"
; -----------------------------------------------------------------
; Every previous diagnostic this session constructed its own known-
; good input by hand. This one does too, deliberately, for the same
; reason: if the REAL converter UI is (for whatever reason) passing
; FP_FROM_ASCII_SCI_PROC something other than a clean "1.9E+38" -
; extra trailing digits, a leftover character, wrong length - this
; test's clean, hand-built string won't reproduce that, and its
; result tells you definitively whether the bug is IN this parser
; or UPSTREAM of it.
;
; HOW TO INVOKE
; ----------------
; JSR DIAG_FULL_PARSE from the same throwaway entry point used for
; the other two diagnostics.
; ============================================================
.segment "CODE"
.proc DIAG_FULL_PARSE
    TEST_ROUTINE_HEADER_MACRO msg_header

    BASIC_STROUT_MACRO msg_banner
    KERNAL_CHROUT_MACRO $0d

    ; --- [BUG FIX] FP_ERROR_INIT_MACRO's own header says plainly:
    ;     "Destroys: A" (it does two LDA #imm's to build the pushed
    ;     recovery address). An earlier version of this file called
    ;     it AFTER loading A with the string pointer's low byte,
    ;     which clobbered that register before FP_FROM_ASCII_SCI ever
    ;     ran - confirmed on hardware: it silently parsed garbage
    ;     memory instead of "1.9e+38", found no valid digit there,
    ;     and correctly returned exactly what its own contract
    ;     promises for that case (carry set, FP1 left at 0.0) - which
    ;     is exactly the "success: fp1=00 000000" result that run
    ;     produced. Not a mystery once traced, just an ordering bug
    ;     in THIS file. Fix: arm the guard FIRST, load A/Y fresh
    ;     immediately before the jsr, every time - same rule
    ;     diag_scale_dump.s already followed correctly (there,
    ;     FP_FMUL takes no register argument at all, so the same
    ;     ordering mistake would have been harmless - it's only a
    ;     problem for calls, like this one, that DO pass an argument
    ;     in A/Y). ---
    FP_ERROR_INIT_MACRO @trapped
    lda #<test_str
    ldy #>test_str
    jsr FP_FROM_ASCII_SCI
    FP_ERROR_CLEAR_MACRO            ; pla/pla - clobbers A again (see
                                    ; its own header) but NOT carry,
                                    ; so the carry check below still
                                    ; sees FP_FROM_ASCII_SCI's real
                                    ; result, not FP_ERROR_CLEAR_MACRO's

    ; --- [BUG FIX] also check carry, per FP_FROM_ASCII_SCI_PROC's
    ;     own documented Exit contract ("Carry clear if the MANTISSA
    ;     contained at least one digit; carry set... if it didn't") -
    ;     the earlier version of this file never checked this at all,
    ;     which is exactly how the register-clobber bug above went
    ;     unnoticed instead of being caught immediately. ---
    bcc @have_result
    BASIC_STROUT_MACRO msg_no_digits
    jmp @done
    
@have_result:

    ; --- [lesson learned from diag_scale_dump.s] snapshot BEFORE any
    ;     BASIC_STROUT call, even though this is a one-shot (not a
    ;     loop) - no reason to trust myself not to reorder this file
    ;     later and reintroduce the exact same bug. ---
    lda FP1_EXP
    sta snap_exp
    lda FP1_MANT
    sta snap_mant
    lda FP1_MANT+1
    sta snap_mant+1
    lda FP1_MANT+2
    sta snap_mant+2

    BASIC_STROUT_MACRO msg_success
    lda snap_exp
    jsr OUTPUT_BYTETOHEX
    lda #' '
    jsr KERNAL_CHROUT
    lda snap_mant
    jsr OUTPUT_BYTETOHEX
    lda snap_mant+1
    jsr OUTPUT_BYTETOHEX
    lda snap_mant+2
    jsr OUTPUT_BYTETOHEX
    KERNAL_CHROUT_MACRO $0d
    BASIC_STROUT_MACRO msg_want
    jmp @done

@trapped:
    ; FP1/FP2 not meaningful after a trap - see lib_fp_error.s's own
    ; documented contract, same reasoning as diag_scale_dump.s's
    ; @print_trap. Only the error code is trustworthy here.
    BASIC_STROUT_MACRO msg_trapped
    lda FP_ERROR_CODE
    jsr OUTPUT_BYTETOHEX
    KERNAL_CHROUT_MACRO $0d

@done:
    jsr FP_CLEANUP_FAC1FAC2
    rts

.segment "RODATA"
msg_header:     .asciiz "special: ascii full parse"
; --- lowercase source 'e' -> real PETSCII $45 - see
;     diag_exp_digit_parse.s's own header note for the full
;     .charmap reasoning. Functionally either case works here (the
;     real @check_exponent accepts both $45 and $65), but lowercase
;     is used deliberately, matching this project's own convention. ---
test_str:      .asciiz "1.9e+38"

msg_banner:    .asciiz "diag: full parse of 1.9e+38"
msg_success:   .asciiz "success: fp1="
msg_want:      .asciiz "(want: ff 48 00 00, per the two isolated pieces)"
msg_trapped:   .asciiz "trapped! error code=$"
msg_no_digits: .asciiz "carry set: no digits found (parse failed)"

snap_exp:      .byte 0
snap_mant:     .res 3,0
.endproc
