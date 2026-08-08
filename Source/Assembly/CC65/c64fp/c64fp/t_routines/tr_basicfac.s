
.include "tr.inc"

.export tr_basicfac

.import FP_TO_BASIC, FP_FROM_BASIC
.import FP_CLEANUP_FAC1FAC2
.import TEST_PASSED, TEST_FAILED, TEST_FP1CMP, TEST_STRCMP

.segment "CODE"
; ============================================================
; PROCEDURE : tr_basicfac
; Purpose : Test group for FP_TO_BASIC_PROC/FP_FROM_BASIC_PROC
;           (lib_fp_basic.s) - the Woz <-> C64 BASIC ROM FAC
;           (5-byte packed format) converter.
; ============================================================
; WHY A LOCAL BYTE-COMPARE HELPER (@bytecmp5) INSTEAD OF AN
; EXISTING TEST MACRO
; -----------------------------------------------------------------
; TEST_FP1CMP_MACRO compares FP1 (4 bytes, Woz format) against a
; known-good constant - perfect for the FP_FROM_BASIC_PROC tests
; below, since that routine's OUTPUT is FP1. FP_TO_BASIC_PROC's
; output, though, is a 5-byte packed BASIC buffer - not FP1 at all -
; and there's no existing "compare N raw bytes at this address
; against N raw bytes at that address" macro in fp_test_macros.s.
; Rather than add one to the shared macro file for what only THIS
; test group currently needs, @bytecmp5 stays local to this .proc,
; the same way lib_fp_sin.s keeps its own Horner coefficients
; private rather than promoting them to a shared constant table.
;
; WHY THESE SPECIFIC TEST VALUES (1.0 / 100.0 / -5.0 / 0.0)
; -----------------------------------------------------------------
; All four already exist in fp_test_variables.s (val_1, val_100,
; val_neg5, val_0) - reusing them means this file adds zero new
; entries to that shared constant table, and each was independently
; hand-derived against the expected BASIC bytes in
; lib_fp_basic.s's own WORKED EXAMPLE / this file's header before
; being trusted here (see the comment above each expected_* constant
; below for the arithmetic).
;
; TEST INVENTORY (matches the five priorities lib_fp_basic.s's own
; header lists, in the same order)
; -----------------------------------------------------------------
;   T00-T02  FP_TO_BASIC_PROC: 1.0, 100.0, -5.0 against hand-
;            verified expected byte patterns (not just self-
;            consistency - see the file header note on why this
;            matters more than a bare round-trip check)
;   T03      FP_TO_BASIC_PROC: 0.0 -> all-zero 5-byte buffer
;   T04-T06  FP_FROM_BASIC_PROC: the SAME three known-good byte
;            patterns from T00-T02, decoded back and compared
;            against FP1 via TEST_FP1CMP_MACRO
;   T07      FP_FROM_BASIC_PROC: BASIC exponent = 1 (the Eb=0/Eb=1
;            underflow-collision case - see lib_fp_basic.s's ERROR
;            HANDLING note) -> must decode to exactly 0.0, with a
;            deliberately non-zero mantissa in the input to prove
;            the mantissa bytes are correctly ignored
;   T08      FP_FROM_BASIC_PROC: BASIC exponent = 0 (BASIC's own
;            canonical zero) -> same expectation, same mantissa-
;            ignored proof
;   T09      FP_TO_BASIC_PROC: Woz exponent = $FF -> must trap with
;            generic overflow (error code 0), per the setjmp/
;            longjmp pattern lib_fp_error.s documents
;   T10      A REAL round trip through BASIC's own ROM (not just
;            this library's two routines talking to each other):
;            FP_TO_BASIC -> FP_CLEANUP_FAC1FAC2 -> BASIC_MOVMF ->
;            BASIC_FOUT, string-compared against BASIC's own actual
;            output. This is the test that caught the
;            FP_CLEANUP_FAC1FAC2 class of bug - see
;            lib_fp_basic.s's VERIFICATION STATUS note for the
;            "-5.00921102 instead of -5" failure this test now
;            guards against.
;   T11      Same real-ROM round trip as T10, but with a POSITIVE
;            FRACTIONAL value (0.5) - T10's -5.0 has an all-zero
;            fraction and so cannot exercise FOUT's own fractional-
;            digit formatting at all.
;
; VERIFICATION STATUS: all twelve tests (T00-T11) pass, confirmed
; against real BASIC ROM output for T10/T11 specifically - see
; lib_fp_basic.s's own header for the full account, including what
; is genuinely still untested (a large-magnitude value through the
; real ROM path).
; ============================================================
.proc tr_basicfac

    ; --- T00: FP_TO_BASIC_PROC(1.0) == $81,$00,$00,$00,$00 ---
    ; hand check: Eb = Ew+1 = $80+1 = $81. Woz mantissa $400000
    ; shifted left 9 = $80000000; masked+signed(+) = $00.
    FP_LOAD1_MACRO TestValue::val_1
    lda #<work_buf
    ldy #>work_buf
    jsr FP_TO_BASIC
    lda #<expected_1
    ldy #>expected_1
    jsr @bytecmp5
    beq @t00_pass
    TEST_FAILED_MACRO_V2 0, msg_t00
    jmp @t01
@t00_pass:
    TEST_PASSED_MACRO_V2 0, msg_t00

    ; --- T01: FP_TO_BASIC_PROC(100.0) == $87,$48,$00,$00,$00 ---
    ; hand check: Eb = $86+1 = $87. Woz mantissa $640000 shifted
    ; left 9 = $C8000000; masked+signed(+) = $48.
@t01:
    FP_LOAD1_MACRO TestValue::val_100
    lda #<work_buf
    ldy #>work_buf
    jsr FP_TO_BASIC
    lda #<expected_100
    ldy #>expected_100
    jsr @bytecmp5
    beq @t01_pass
    TEST_FAILED_MACRO_V2 1, msg_t01
    jmp @t02
@t01_pass:
    TEST_PASSED_MACRO_V2 1, msg_t01

    ; --- T02: FP_TO_BASIC_PROC(-5.0) == $83,$a0,$00,$00,$00 ---
    ; hand check: Ew=$82 for the +5.0 magnitude FP_NEGATE produces
    ; internally, Eb=$82+1=$83. Positive magnitude mantissa $500000
    ; shifted left 9 = $A0000000; masked+signed(NEGATIVE) = $A0.
@t02:
    FP_LOAD1_MACRO TestValue::val_neg5
    lda #<work_buf
    ldy #>work_buf
    jsr FP_TO_BASIC
    lda #<expected_neg5
    ldy #>expected_neg5
    jsr @bytecmp5
    beq @t02_pass
    TEST_FAILED_MACRO_V2 2, msg_t02
    jmp @t03
@t02_pass:
    TEST_PASSED_MACRO_V2 2, msg_t02

    ; --- T03: FP_TO_BASIC_PROC(0.0) == $00,$00,$00,$00,$00 ---
@t03:
    FP_LOAD1_MACRO TestValue::val_0
    lda #<work_buf
    ldy #>work_buf
    jsr FP_TO_BASIC
    lda #<expected_zero
    ldy #>expected_zero
    jsr @bytecmp5
    beq @t03_pass
    TEST_FAILED_MACRO_V2 3, msg_t03
    jmp @t04
@t03_pass:
    TEST_PASSED_MACRO_V2 3, msg_t03

    ; --- T04-T06: FP_FROM_BASIC_PROC round-trips the SAME three
    ;     known-good byte patterns back into FP1, checked against
    ;     the library's own Woz constants via TEST_FP1CMP_MACRO ---
@t04:
    lda #<expected_1
    ldy #>expected_1
    jsr FP_FROM_BASIC
    TEST_FP1CMP_MACRO 4, msg_t04, TestValue::val_1

@t05:
    lda #<expected_100
    ldy #>expected_100
    jsr FP_FROM_BASIC
    TEST_FP1CMP_MACRO 5, msg_t05, TestValue::val_100

@t06:
    lda #<expected_neg5
    ldy #>expected_neg5
    jsr FP_FROM_BASIC
    TEST_FP1CMP_MACRO 6, msg_t06, TestValue::val_neg5

    ; --- T07: FP_FROM_BASIC_PROC, Eb=1 (the underflow-collision
    ;     case) -> must decode to exactly 0.0. The mantissa bytes
    ;     here are deliberately all $FF (as far from a "helpfully
    ;     already zero" mantissa as possible) to prove the
    ;     underflow path ignores the mantissa entirely rather than
    ;     happening to pass because the test data was too easy ---
@t07:
    lda #<underflow_eb1
    ldy #>underflow_eb1
    jsr FP_FROM_BASIC
    TEST_FP1CMP_MACRO 7, msg_t07, TestValue::val_0

    ; --- T08: FP_FROM_BASIC_PROC, Eb=0 (BASIC's own canonical
    ;     zero) -> same expectation, same mantissa-ignored proof,
    ;     different (non-$FF) arbitrary mantissa bytes just to
    ;     avoid the two tests being suspiciously identical inputs ---
@t08:
    lda #<zero_eb0
    ldy #>zero_eb0
    jsr FP_FROM_BASIC
    TEST_FP1CMP_MACRO 8, msg_t08, TestValue::val_0

    ; --- T09: FP_TO_BASIC_PROC traps generic overflow (error code
    ;     0) when the Woz exponent is already $FF - see
    ;     lib_fp_error.s's setjmp/longjmp contract: arm the guard
    ;     immediately before the one risky call, nothing risky in
    ;     between ---
@t09:
    FP_LOAD1_MACRO exp_ff_const
    FP_ERROR_INIT_MACRO @t09_recovery
    lda #<work_buf
    ldy #>work_buf
    jsr FP_TO_BASIC
    ; reached only if FP_TO_BASIC did NOT trap - that is itself a
    ; failure, since this input was specifically chosen to overflow
    FP_ERROR_CLEAR_MACRO
    TEST_FAILED_MACRO_V2 9, msg_t09
    jmp @t10
@t09_recovery:
    ; reached only via FP_ERROR_PROC's unwind - confirm it trapped
    ; with the RIGHT code, not just any code
    lda FP_ERROR_CODE
    cmp #0
    beq @t09_pass
    TEST_FAILED_MACRO_V2 9, msg_t09
    jmp @t10
@t09_pass:
    TEST_PASSED_MACRO_V2 9, msg_t09

    ; --- T10: a REAL round trip through BASIC's own ROM, not just
    ;     this file's two routines talking to each other -
    ;     FP_TO_BASIC(-5.0) -> FP_CLEANUP_FAC1FAC2 -> BASIC_MOVMF
    ;     -> BASIC_FOUT, string-compared against BASIC's own
    ;     expected output. This is the exact sequence that, missing
    ;     the FP_CLEANUP_FAC1FAC2 call, printed "-5.00921102"
    ;     instead of "-5" the first time this was tried by hand -
    ;     see lib_fp_basic.s's VERIFICATION STATUS note. This test
    ;     exists specifically so that regression can never come
    ;     back silently.
@t10:
    FP_LOAD1_MACRO TestValue::val_neg5
    lda #<work_buf
    ldy #>work_buf
    jsr FP_TO_BASIC
    jsr FP_CLEANUP_FAC1FAC2      ; the step that was missing before -
                                 ; see lib_fp_basic.s's IMPORTANT note
    lda #<work_buf
    ldy #>work_buf
    jsr BASIC_MOVMF              ; work_buf -> FAC1
    jsr BASIC_FOUT                ; FAC1 -> ASCII, pointer in A/Y

    ; --- copy FOUT's returned string into TestData::out_buffer,
    ;     since TEST_STRCMP_MACRO_V2 always compares against THAT
    ;     fixed buffer, not an arbitrary pointer FOUT happens to
    ;     hand back ---
    sta FP_STRPTR
    sty FP_STRPTR+1
    ldy #0
@t10_copy:
    lda (FP_STRPTR),y
    sta TestData::out_buffer,y
    beq @t10_copied
    iny
    jmp @t10_copy
@t10_copied:
    TEST_STRCMP_MACRO_V2 10, msg_t10, expected_t10_str

    ; --- T11: same real-ROM round trip as T10, but with a POSITIVE
    ;     FRACTIONAL value (0.5) instead of a negative integer -
    ;     T10's -5.0 has an all-zero fraction, so it can't exercise
    ;     FOUT's own fractional-digit formatting at all; this test
    ;     closes that gap. hand check: Woz 0.5 = exp $7f, mantissa
    ;     $400000; Eb=$7f+1=$80; $400000<<9=$80000000; masked+
    ;     signed(+)=$00 -> expected BASIC bytes $80,$00,$00,$00,$00
    ;     (independently confirmed: (1+0/2^31)*2^(0x80-129)=2^-1=0.5)
    ;
    ;     " .5" (leading space for positive sign, no leading "0"
    ;     before the decimal point) is now CONFIRMED against real
    ;     BASIC ROM output, not just derived - this was the one
    ;     value in this file that wasn't, until it actually ran.
@t11:
    FP_LOAD1_MACRO TestValue::val_0_5
    lda #<work_buf
    ldy #>work_buf
    jsr FP_TO_BASIC
    jsr FP_CLEANUP_FAC1FAC2
    lda #<work_buf
    ldy #>work_buf
    jsr BASIC_MOVMF
    jsr BASIC_FOUT
    sta FP_STRPTR
    sty FP_STRPTR+1
    ldy #0
@t11_copy:
    lda (FP_STRPTR),y
    sta TestData::out_buffer,y
    beq @t11_copied
    iny
    jmp @t11_copy
@t11_copied:
    TEST_STRCMP_MACRO_V2 11, msg_t11, expected_t11_str
    rts

; ------------------------------------------------------------
; @bytecmp5: compare work_buf (this proc's own 5-byte scratch,
; below) against a 5-byte constant elsewhere in memory.
; Entry   : A = expected-data address low byte
;           Y = expected-data address high byte
; Exit    : Z flag set   if all 5 bytes match
;           Z flag clear if any byte differs
; Destroys: A, Y; FP_STRPTR ($FB/$FC - transient, same reuse
;           convention as the rest of this library, see
;           labels_fp.s and lib_fp_basic.s's own header)
; Why Y for BOTH indices: (FP_STRPTR),y is the 6510's only
; indirect-INDEXED addressing mode (indirect-indexed always uses Y,
; never X) - but work_buf,y is an ordinary absolute,Y access, which
; is just as happy to share the same index register. Using Y for
; both means one loop counter drives both sides of the comparison,
; no second register needed.
; ------------------------------------------------------------
@bytecmp5:
    sta FP_STRPTR
    sty FP_STRPTR+1
    ldy #0
@cmp_loop:
    lda work_buf,y
    cmp (FP_STRPTR),y
    bne @cmp_done            ; mismatch: Z is clear here, done
    iny
    cpy #5
    bne @cmp_loop            ; not all 5 compared yet: keep going
@cmp_done:
    rts                      ; Z set (from cpy #5 matching) means
                              ; all 5 bytes were equal; Z clear
                              ; (from the failed cmp) means one
                              ; wasn't - RTS itself doesn't touch
                              ; flags, so this is safe to test with
                              ; a plain BEQ/BNE at the call site

work_buf: .res 5,0            ; FP_TO_BASIC_PROC's scratch output
                              ; target for every T00-T03 test above

.segment "RODATA"
; --- expected BASIC-format byte patterns, each hand-derived in
;     lib_fp_basic.s's own WORKED EXAMPLE section or this file's
;     per-test comments above before being trusted here ---
expected_1:      .byte $81,$00,$00,$00,$00   ; 1.0
expected_100:    .byte $87,$48,$00,$00,$00   ; 100.0
expected_neg5:   .byte $83,$a0,$00,$00,$00   ; -5.0
expected_zero:   .byte $00,$00,$00,$00,$00   ; 0.0

; --- inputs for the FP_FROM_BASIC_PROC edge cases (T07/T08) - the
;     mantissa bytes are deliberately non-trivial (not all-zero) to
;     prove they're genuinely being ignored, not just coincidentally
;     already producing the right answer ---
underflow_eb1:   .byte $01,$ff,$ff,$ff,$ff   ; Eb=1 underflow case
zero_eb0:        .byte $00,$12,$34,$56,$78   ; Eb=0 canonical zero

; --- input for the FP_TO_BASIC_PROC overflow trap (T09): a legal,
;     if enormous, Woz value (2^127-ish) whose exponent is already
;     at the top of its own byte range, so Ew+1 must wrap ---
exp_ff_const:    .byte $ff,$40,$00,$00

; --- expected output of BASIC's own FOUT for -5.0, hand-confirmed
;     against real BASIC ROM output before being trusted here (see
;     lib_fp_basic.s's VERIFICATION STATUS note) - BASIC's FOUT
;     omits a trailing ".0" for whole-number results ---
expected_t10_str: .asciiz "-5"

; --- expected output of BASIC's own FOUT for 0.5 - CONFIRMED
;     against real BASIC ROM output (leading space for the sign
;     slot, no leading "0" before the decimal point) ---
expected_t11_str: .asciiz " .5"

msg_t00: .asciiz "fp->bfp (1.0)"
msg_t01: .asciiz "fp->bfp (100.0)"
msg_t02: .asciiz "fp->bfp (-5.0)"
msg_t03: .asciiz "fp->bfp (0.0)"
msg_t04: .asciiz "bfp->fp (1.0)"
msg_t05: .asciiz "bfp->fp (100.0)"
msg_t06: .asciiz "bfp->fp (-5.0)"
msg_t07: .asciiz "bfp->fp (underflow)"
msg_t08: .asciiz "bfp->fp (zero)"
msg_t09: .asciiz "fp->bfp (trap overflow)"
msg_t10: .asciiz "bfp rt (-5.0)"
msg_t11: .asciiz "bfp rt ( 0.5)"
.endproc
