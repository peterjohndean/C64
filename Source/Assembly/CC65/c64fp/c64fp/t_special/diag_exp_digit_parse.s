
.include "../t_routines/tr.inc"

.import FP_CLEANUP_FAC1FAC2
.export DIAG_EXP_DIGIT_PARSE

; ============================================================
; FILE    : diag_exp_digit_parse.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; ONE-OFF DIAGNOSTIC, NOT PERMANENT REGRESSION COVERAGE - same status
; as diag_scale_dump.s, not wired into fp_tests.s.
;
; diag_scale_dump.s already proved (on real hardware, after its own
; earlier BASIC_STROUT/FAC1 bug was fixed) that FP_FROM_ASCII_SCI_
; PROC's @scale_multiply_loop is CORRECT when driven directly with
; the real parsed mantissa (1.9) and a hand-set scale_count=38 - it
; matched a mathematically exact reference trajectory on all 38
; steps and reached FP1_EXP=$FF with no trap. Combined with
; tr_exp_boundary.s's earlier proof that FP_CORE_PROC's own overflow
; check is correct, this rules out BOTH of the two arithmetic pieces
; as the source of the "1.9E+38 traps" bug.
;
; That diagnostic hardcoded scale_count=38 directly, though -
; deliberately, to isolate the multiply chain from everything else.
; It never verified that the REAL routine, parsing the literal
; characters "38" out of the exponent suffix, actually produces
; exp_value=38 in the first place. If it doesn't - if the digit-
; accumulation loop is off by even one, or reads a stray extra
; digit, or mishandles the two-digit case somehow - that alone
; would explain a spurious trap with NO arithmetic bug required at
; all, given the two arithmetic pieces are now both independently
; proven clean. This file isolates exactly that one remaining
; unverified piece: @check_exponent through @exp_digits_done in
; lib_fp_from_ascii_sci.s, copied verbatim, with no FP1/FP2 or FAC1
; involvement at all (see below for why that means no snapshot
; dance is needed this time, unlike diag_scale_dump.s).
;
; WHY THIS TEST STRING IS WRITTEN "e+38" (LOWERCASE e), NOT "E+38"
; -----------------------------------------------------------------
; lib_fp_from_ascii_sci.s's own header documents, at length, that
; ca65 runs character literals AND .asciiz string text through the
; same .charmap case-swap table this project's whole codebase
; depends on for readable lowercase source: source 'a'-'z' becomes
; the PETSCII bytes that DISPLAY as uppercase ($41-$5A, i.e. real
; 'A'-'Z'), and source 'A'-'Z' becomes the $61-$7A range instead
; (graphic symbols in the default charset, not real uppercase
; letters). The real @check_exponent code checks for BOTH real
; PETSCII $45 ('E') and real PETSCII $65 ('e') via raw hex literals,
; specifically to sidestep this ambiguity - see that file's own RAW
; HEX header note. For THIS diagnostic's test string, following the
; SAME lowercase-source convention every other string in this
; codebase already uses (msg_banner, msg_done, etc. - and this
; file's own messages below) keeps things consistent and produces
; real PETSCII $45 for the 'e', matching @check_exponent's first
; comparison. (Note: because @check_exponent accepts EITHER $45 or
; $65, getting this backwards wouldn't have actually broken THIS
; specific test - both routes reach @has_exponent - but getting it
; right on purpose, rather than by accident, is the whole point
; after already being bitten by exactly this gotcha once this
; session, in diag_scale_dump.s's BASIC_STROUT/FAC1 mixup.)
;
; WHY NO SNAPSHOT DANCE IS NEEDED HERE (unlike diag_scale_dump.s)
; -----------------------------------------------------------------
; diag_scale_dump.s needed to snapshot FP1 before any BASIC_STROUT
; call because it carried FP1 as a running accumulator ACROSS
; BASIC_STROUT calls. This file's own scratch (scan_pos, exp_value,
; exp_is_negative, exp_digit_tmp, exp_tmp2) is ordinary RAM, not
; FAC-aliased zero page, and FP1/FP2 are never touched by this code
; at all (the real @check_exponent-through-@exp_digits_done block
; doesn't reference them either) - so BASIC_STROUT_MACRO can be
; called freely here with no corruption risk. Worth stating
; explicitly rather than silently relying on it, given how easy this
; exact class of mistake turned out to be to make once already.
;
; HOW TO READ THE OUTPUT
; --------------------------
; Prints "exp_value=NN  exp_is_negative=N" then, on the line below,
; the expected values for comparison. For "e+38": exp_value should
; be 38 (decimal), exp_is_negative should be 0. Any other exp_value
; is the smoking gun - e.g. 39 would mean an extra digit is being
; read somewhere, and its exact wrong value is usually enough on its
; own to work out where in @exp_digit_loop the miscount happens
; (39 = one extra pass through the loop; 3 or 8 alone would suggest
; the two-digit accumulation math itself, not the loop bounds).
;
; HOW TO INVOKE
; ----------------
; JSR DIAG_EXP_DIGIT_PARSE from the same throwaway entry point used
; for diag_scale_dump.s. Remove both diagnostic files once the real
; bug is found and fixed.
; ============================================================
.segment "CODE"
.proc DIAG_EXP_DIGIT_PARSE
    TEST_ROUTINE_HEADER_MACRO msg_header

    lda #<test_str
    sta FP_STRPTR
    lda #>test_str
    sta FP_STRPTR+1
    lda #0
    sta scan_pos

    ; --- this IS lib_fp_from_ascii_sci.s's own @check_exponent
    ;     through @exp_digits_done, copied verbatim - no logic
    ;     changed, only the entry/exit differ (a fixed test string
    ;     instead of wherever a real mantissa scan left scan_pos,
    ;     and reporting exp_value/exp_is_negative afterward instead
    ;     of falling into the scale loop) ---
@check_exponent:
    ldy scan_pos
    lda (FP_STRPTR),y
    cmp #$45                    ; real PETSCII 'E'
    beq @has_exponent
    cmp #$65                    ; real PETSCII 'e'
    beq @has_exponent
    BASIC_STROUT_MACRO msg_no_e
    jmp @done

@has_exponent:
    inc scan_pos
    lda #0
    sta exp_is_negative
    sta exp_value
    ldy scan_pos
    lda (FP_STRPTR),y
    cmp #'-'
    bne @exp_check_plus
    inc exp_is_negative
    inc scan_pos
    jmp @exp_digit_loop
@exp_check_plus:
    cmp #'+'
    bne @exp_digit_loop
    inc scan_pos
@exp_digit_loop:
    ldy scan_pos
    lda (FP_STRPTR),y
    cmp #'0'
    bcc @exp_digits_done
    cmp #'9'+1
    bcs @exp_digits_done
    sec
    sbc #'0'
    sta exp_digit_tmp
    ; exp_value = exp_value*10 + digit, via (v<<1)+(v<<3) = v*10,
    ; exactly as in the real routine
    lda exp_value
    asl
    sta exp_tmp2
    asl
    asl
    clc
    adc exp_tmp2
    clc                          ; fresh clc, not the adc's carry -
                                ; see the real file's own [BUG-
                                ; AVOIDANCE] comment for why
    adc exp_digit_tmp
    sta exp_value
    inc scan_pos
    jmp @exp_digit_loop

@exp_digits_done:

    ; --- report - see the file header for why no snapshot is needed
    ;     for these particular bytes ---
    BASIC_STROUT_MACRO msg_result
    lda exp_value
    ldx #$20
    jsr OUTPUT_BYTETODEC
    BASIC_STROUT_MACRO msg_neg
    lda exp_is_negative
    ldx #$20
    jsr OUTPUT_BYTETODEC
    KERNAL_CHROUT_MACRO $0d
    BASIC_STROUT_MACRO msg_want
    KERNAL_CHROUT_MACRO $0d

@done:
    jsr FP_CLEANUP_FAC1FAC2
    rts

.segment "RODATA"
msg_header:     .asciiz "special: ascii exp parse"

; --- lowercase source 'e' -> real PETSCII $45 ('E') - see the file
;     header's WHY THIS TEST STRING note ---
test_str:         .asciiz "e+38"

msg_no_e:         .asciiz "no e/e found at scan pos - stopping"
msg_result:       .asciiz "exp value="
msg_neg:          .asciiz "  exp is negative="
msg_want:         .asciiz "(want: exp -> value=38, negative=0)"

scan_pos:         .byte 0
exp_value:        .byte 0
exp_is_negative:  .byte 0
exp_digit_tmp:    .byte 0
exp_tmp2:         .byte 0
.endproc
