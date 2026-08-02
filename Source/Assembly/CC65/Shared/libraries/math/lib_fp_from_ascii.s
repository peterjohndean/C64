.include "macros_fp.s"

.export FP_FROM_ASCII
.import FP_FADD, FP_FMUL, FP_FDIV
.import FP_NEGATE, FP_NORM, FP_FLOAT

FP_FROM_ASCII = FP_FROM_ASCII_PROC

.segment "CODE"
; ============================================================
; PROCEDURE : FP_FROM_ASCII_PROC
; Purpose : Parse a null-terminated decimal string into FP1 using
;           Horner's method (result = result*10 + digit for each
;           digit in turn; fractional digits are accumulated the
;           same way, then the whole thing is divided by 10 once
;           per fractional digit at the end).
; Entry   : A = string address low byte, Y = string address high byte
; Exit    : FP1 = parsed value. Carry clear if at least one digit
;           was found; carry set (FP1 left at 0.0) if the string
;           contained none.
; Destroys: A, X, Y; FP1, FP2
;
; A COMPANION ROUTINE EXISTS: FP_FROM_ASCII24_PROC
; ---------------------------------------------------
; This routine accumulates every digit - integer AND fractional -
; into one running Horner's-method total, then divides the whole
; total back down by 10 once per fractional digit at the end. That
; works fine as long as the TOTAL combined digit count (integer
; digits + fractional digits together) stays within about 7 - past
; that, the unscaled intermediate needs more bits than this format's
; ~23-bit mantissa can hold, and it silently rounds before the
; divide-back-down step ever runs (confirmed on real hardware: this
; routine turned "1234567.25" into "1234566.50" - wrong in both the
; integer part and the fraction). If the string being parsed can
; have a decimal point AND a large integer part (see
; lib_fp_from_ascii24.s's own header for the exact guidance and a
; precision-budget-by-magnitude table), use FP_FROM_ASCII24_PROC
; instead - it keeps the integer and fractional digits in separate
; accumulators, which avoids this specific failure mode. This
; routine is left completely unchanged for existing call sites that
; already work correctly with it.
; ============================================================
.proc FP_FROM_ASCII_PROC
    sta FP_STRPTR
    sty FP_STRPTR+1
    lda #0
    sta FP1_EXP
    sta FP1_MANT
    sta FP1_MANT+1
    sta FP1_MANT+2                  ; FP1 = 0.0
    sta is_negative
    sta point_seen
    sta frac_digits
    sta saw_digit
    sta scan_pos                    ; [BUG FIX] string position now lives in
                                    ; memory, not Y - see the note below
    ldy #0
    lda (FP_STRPTR),y
    cmp #'-'
    bne @check_plus
    inc is_negative
    inc scan_pos
    jmp @scan_loop
@check_plus:
    cmp #'+'
    bne @scan_loop
    inc scan_pos
@scan_loop:
    ; [BUG FIX] Y must be reloaded from scan_pos on EVERY pass through this
    ; loop, not just carried forward via iny. accumulate_digit below calls
    ; FP_FMUL/FP_FADD (and, via the fractional path, FP_FDIV) - all three
    ; are documented in library_fp.s as destroying Y (FMUL/FDIV use it as
    ; their 24-bit iteration counter). The original version kept the
    ; string-scan position live in Y across that call, so after the very
    ; first digit, Y no longer pointed anywhere near the string - it held
    ; FMUL's leftover loop-counter value instead, and the parse silently
    ; truncated after one digit (verified: "-42" parsed as -4.0). Loading
    ; Y fresh from scan_pos here, and writing it back immediately after
    ; each indirect access, is the same safe pattern FP_TO_ASCII_PROC
    ; already uses for its own out_pos - Y is only ever "borrowed" for the
    ; instant of the (FP_STRPTR),y access itself.
    ldy scan_pos
    lda (FP_STRPTR),y
    cmp #'.'
    beq @got_point
    cmp #'0'
    bcc @scan_done                  ; below '0': not a digit, end of number
    cmp #'9'+1
    bcs @scan_done                  ; above '9': not a digit, end of number
    inc saw_digit
    sec
    sbc #'0'                        ; A = digit value 0-9
    jsr @accumulate_digit
    lda point_seen
    beq @no_frac_count
    inc frac_digits
@no_frac_count:
    inc scan_pos
    jmp @scan_loop
@got_point:
    lda point_seen
    bne @scan_done                  ; a second '.': malformed, stop here
    inc point_seen
    inc scan_pos
    jmp @scan_loop
@scan_done:
    lda frac_digits                 ; undo the fractional scale: divide
    beq @apply_sign                 ; by 10 once per fractional digit seen
@divide_loop:
    pha
    FP_COPY1TO2_MACRO               ; FP2 = running total
    FP_LOAD1_MACRO ten_const        ; FP1 = 10.0
    jsr FP_FDIV                     ; FP1 = FP2 / FP1 = total / 10
    pla
    sec
    sbc #1
    bne @divide_loop
@apply_sign:
    lda is_negative
    beq @done
    jsr FP_NEGATE
@done:
    lda saw_digit
    beq @no_digits
    clc
    rts
@no_digits:
    sec
    rts

; --- accumulate_digit: FP1 = FP1*10 + A  (A = digit value 0-9) ---
@accumulate_digit:
    sta digit_tmp
    FP_LOAD2_MACRO ten_const        ; FP2 = 10.0
    jsr FP_FMUL                     ; FP1 = total * 10
    FP_STORE1_MACRO accum           ; stash total*10 - building the
                                    ; digit float needs FP1
    lda digit_tmp
    sta FP1_MANT+1                  ; digit as a 16-bit integer
    lda #0
    sta FP1_MANT
    jsr FP_FLOAT                    ; FP1 = float(digit)
    FP_COPY1TO2_MACRO               ; FP2 = float(digit)
    FP_LOAD1_MACRO accum            ; FP1 = total*10 (restored)
    jsr FP_FADD                     ; FP1 = total*10 + digit
    rts

.segment "RODATA"
ten_const:      .byte $83,$50,$00,$00   ; 10.0 - see library_fp_convert.s's
                                        ; header for how these bytes are
                                        ; derived (mantissa_int/2^22 *
                                        ; 2^(exp-128))
.segment "BSS"
accum:          .res 4,0
digit_tmp:      .byte 0
is_negative:    .byte 0
point_seen:     .byte 0
frac_digits:    .byte 0
saw_digit:      .byte 0
scan_pos:       .byte 0

.endproc
