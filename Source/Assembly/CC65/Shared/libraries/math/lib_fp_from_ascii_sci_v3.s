.macpack longbranch

.include "macros_fp.s"
.include "lib_fp_error.h"

.export FP_FROM_ASCII_SCI_V3
.import FP_FADD, FP_FMUL, FP_FDIV
.import FP_NEGATE, FP_FLOAT
.import FP_ERROR

.scope LIBFP_CONSTANTS
    .import ten_const
.endscope

FP_FROM_ASCII_SCI_V3 = FP_FROM_ASCII_SCI_V3_PROC

; How many significant decimal digits get accumulated into the
; mantissa Horner total (same as V2).
SIG_DIGIT_BUDGET = 9

.segment "CODE"
; ============================================================
; FILE    : lib_fp_from_ascii_sci_v3.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; Third-generation scientific‑notation parser.  Identical digit‑scan
; logic to V2 (significant digits + decimal exponent adjustment), but
; the final power‑of‑ten scaling is performed as 5^N × 2^N.
; The 2^N part is applied directly to the exponent byte, bypassing
; FP_FMUL entirely and thus avoiding the pre‑normalisation overflow
; trap that still affected values near 2.1E+38 to match V2's own documented boundary.
;
; WHY THIS FILE EXISTS
; --------------------
; This file implements a different scaling strategy — 5^N × 2^N with
; the 2^N part applied directly to the exponent byte — as an ALTERNATIVE
; to V2's 10^N binary-exponentiation approach. It was originally written
; on the belief that V2 still trapped on values from ~2.1E38 upward
; under FP_FMUL's pre-normalisation overflow check. Empirical testing
; (tr_ascii_sci_v2.s's T15-T19 boundary sweep) shows that belief was
; WRONG: V2 handles every value up to the format's true ~3.403E38
; ceiling without trapping.
;
; Both routines are therefore functionally equivalent at the boundary:
; both succeed through 3.4028E38 and trap correctly at 3.403E38.
;
; This file is kept as an alternative implementation for the following
; possible reasons (verify which, if any, actually apply before relying
; on it):
;   - Slightly different code path for the final scaling step (direct
;     exponent-byte adjustment vs. accumulating a table-driven product)
;   - If a future change to FP_CORE_PROC's pre-normalisation check is
;     ever needed, the 5^N × 2^N split keeps the FMUL chain further
;     from the boundary, providing headroom
;
; If neither of those is relevant to your use case, prefer V2 — it has
; more extensive regression coverage and a simpler overall structure.
;
; WHY 5^N + EXPONENT BYTE
; -----------------------
; Multiplying by 2^N as a float still hits FP_FMUL's provisional
; overflow check when the raw exponent sum reaches 126/127.
; By splitting 10^N = 5^N × 2^N and applying the power of two
; as a simple exponent‑byte adjustment, the final magnitude can be
; reached without any FP_FMUL that would spuriously trap.
;
; The 5^N table is derived from the 10^N table by subtracting N
; from the exponent byte (mantissa unchanged), because
; 5^N = 10^N / 2^N.
;
; All other aspects (significant‑digit scanning, exponent suffix
; parsing, error handling) are identical to V2.  See that file's
; header for the full rationale.
;
; VERIFICATION STATUS
; --------------------
; The 5^N + exponent‑byte method has been verified by hand and with
; a small Python simulation of the FP format.  Hardware confirmation
; is still pending.
;
; Entry   : A = string address low byte, Y = string address high byte
; Exit    : FP1 = parsed value.  Carry clear if mantissa had digits;
;           carry set (FP1=0.0) otherwise.
; Destroys: A, X, Y; FP1, FP2
; ============================================================
.proc FP_FROM_ASCII_SCI_V3_PROC
    sta FP_STRPTR
    sty FP_STRPTR+1
    lda #0
    sta FP1_EXP
    sta FP1_MANT
    sta FP1_MANT+1
    sta FP1_MANT+2                  ; FP1 = 0.0
    sta is_negative
    sta point_seen
    sta sig_count
    sta seen_significant
    sta saw_digit
    sta scan_pos
    sta k_value

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
    ldy scan_pos
    lda (FP_STRPTR),y
    cmp #'.'
    beq @got_point
    cmp #'0'
    bcc @scan_done
    cmp #'9'+1
    bcs @scan_done
    inc saw_digit
    sec
    sbc #'0'
    jsr @process_digit
    inc scan_pos
    jmp @scan_loop
@got_point:
    lda point_seen
    bne @scan_done
    inc point_seen
    inc scan_pos
    jmp @scan_loop
@scan_done:

    lda is_negative
    beq @check_exponent
    jsr FP_NEGATE

@check_exponent:
    ldy scan_pos
    lda (FP_STRPTR),y
    cmp #$45                        ; 'E'
    beq @has_exponent
    cmp #$65                        ; 'e'
    beq @has_exponent
    jmp @combine_exponent

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
    lda exp_value
    asl
    sta exp_tmp2
    asl
    asl
    clc
    adc exp_tmp2
    clc
    adc exp_digit_tmp
    sta exp_value
    inc scan_pos
    jmp @exp_digit_loop
@exp_digits_done:

    lda exp_value
    beq @combine_exponent
    lda exp_is_negative
    bne @exp_subtract
    lda k_value
    clc
    adc exp_value
    sta k_value
    jmp @combine_exponent
@exp_subtract:
    lda k_value
    sec
    sbc exp_value
    sta k_value

@combine_exponent:
    lda k_value
    jeq @no_scale
    bpl @k_positive
    lda #1
    sta scale_is_negative
    lda k_value
    eor #$ff
    clc
    adc #1
    jmp @have_magnitude
@k_positive:
    lda #0
    sta scale_is_negative
    lda k_value
@have_magnitude:
    sta exp_adjust_magnitude        ; save for later exponent byte adjust
    sta scale_magnitude

    ; --- bulk loop with 5^32 ---
@scale_bulk_loop:
    lda scale_magnitude
    cmp #32
    bcc @scale_bulk_done
    lda scale_is_negative
    bne @scale_bulk_divide
    FP_LOAD2_MACRO pow5_32
    jsr FP_FMUL
    jmp @scale_bulk_next
@scale_bulk_divide:
    FP_COPY1TO2_MACRO
    FP_LOAD1_MACRO pow5_32
    jsr FP_FDIV
@scale_bulk_next:
    lda scale_magnitude
    sec
    sbc #32
    sta scale_magnitude
    jmp @scale_bulk_loop
@scale_bulk_done:

    ; --- bit‑scan for remainder 0..31 using 5^1..5^16 ---
    lda #0
    sta scale_bit_idx
@scale_loop:
    lda scale_bit_idx
    cmp #5
    bcs @scale_done
    lsr scale_magnitude
    bcc @scale_next
    lda scale_bit_idx
    asl
    asl
    tay         ; Y = idx*4 (byte offset into table)
                ; NOTE: FP_LOAD2_INDEXED_MACRO below will
                ; destroy Y (+3) - nothing here relies on Y
                ; surviving past the macro
    lda scale_is_negative
    bne @scale_divide
    FP_LOAD2_INDEXED_MACRO pow5_table
    jsr FP_FMUL
    jmp @scale_next
@scale_divide:
    FP_COPY1TO2_MACRO
    FP_LOAD1_INDEXED_MACRO pow5_table
    jsr FP_FDIV
@scale_next:
    inc scale_bit_idx
    jmp @scale_loop
@scale_done:

    ; --- apply 2^N part directly to exponent byte ---
    ; First check if FP1 became zero (e.g., division underflow).
    lda FP1_MANT
    ora FP1_MANT+1
    ora FP1_MANT+2
    bne @do_exp_adjust               ; not zero
    lda FP1_EXP
    beq @no_scale                    ; already zero: nothing to adjust
@do_exp_adjust:
    lda scale_is_negative
    bne @exp_subtract_adjust
    ; positive: add magnitude
    lda FP1_EXP
    clc
    adc exp_adjust_magnitude
    sta FP1_EXP
    bcc @exp_adjust_done             ; no carry => no overflow
    ; overflow
    lda #FP_ERROR_CODE_GENERIC_OVERFLOW
    jmp FP_ERROR
@exp_subtract_adjust:
    ; negative: subtract magnitude
    lda FP1_EXP
    sec
    sbc exp_adjust_magnitude
    sta FP1_EXP
    bcc @exp_underflow               ; borrow => exponent negative
    lda FP1_EXP
    bne @exp_adjust_done             ; exponent not zero => ok
@exp_underflow:
    ; underflow to zero
    lda #0
    sta FP1_EXP
    sta FP1_MANT
    sta FP1_MANT+1
    sta FP1_MANT+2
@exp_adjust_done:

@no_scale:
    lda saw_digit
    beq @no_digits
    clc
    rts
@no_digits:
    sec
    rts

    ; ------------------------------------------------------------
    ; @process_digit: identical to V2 – see that file's header.
    ; ------------------------------------------------------------
@process_digit:
    sta digit_tmp
    lda seen_significant
    bne @have_significant
    lda digit_tmp
    bne @first_significant
    lda point_seen
    beq @leading_zero_done
    dec k_value
@leading_zero_done:
    rts
@first_significant:
    inc seen_significant
@have_significant:
    lda sig_count
    cmp #SIG_DIGIT_BUDGET
    bcs @budget_full
    lda digit_tmp
    jsr @accumulate_sig_digit
    inc sig_count
    lda point_seen
    beq @within_budget_done
    dec k_value
@within_budget_done:
    rts
@budget_full:
    lda point_seen
    bne @budget_full_done
    inc k_value
@budget_full_done:
    rts

    ; ------------------------------------------------------------
    ; @accumulate_sig_digit: FP1 = FP1*10 + digit (same as V2)
    ; ------------------------------------------------------------
@accumulate_sig_digit:
    sta digit_tmp2
    FP_LOAD2_MACRO LIBFP_CONSTANTS::ten_const
    jsr FP_FMUL
    FP_STORE1_MACRO accum
    lda digit_tmp2
    sta FP1_MANT+1
    lda #0
    sta FP1_MANT
    jsr FP_FLOAT
    FP_COPY1TO2_MACRO
    FP_LOAD1_MACRO accum
    jsr FP_FADD
    rts

.segment "RODATA"
; --- POWER‑OF‑5 TABLE ---
; Derived from the power‑of‑10 table by subtracting the index from
; the exponent byte.  Index i = 5^(2^i).
pow5_table:
pow5_1:   .byte $82,$50,$00,$00   ; 5^1  = 5
pow5_2:   .byte $84,$64,$00,$00   ; 5^2  = 25
pow5_4:   .byte $89,$4e,$20,$00   ; 5^4  = 625        (10^4 = $8d minus 4)
pow5_8:   .byte $92,$5f,$5e,$10   ; 5^8  = 390625     (10^8 = $9a minus 8)
pow5_16:  .byte $a5,$47,$0d,$e5   ; 5^16 = 152587890625
pow5_32:  .byte $ca,$4e,$e2,$d7   ; 5^32 = 2.3283e+22

.segment "BSS"
accum:              .res 4,0
digit_tmp:          .byte 0
digit_tmp2:         .byte 0
is_negative:        .byte 0
point_seen:         .byte 0
sig_count:          .byte 0
seen_significant:   .byte 0
saw_digit:          .byte 0
scan_pos:           .byte 0
k_value:            .byte 0
exp_is_negative:    .byte 0
exp_value:          .byte 0
exp_digit_tmp:      .byte 0
exp_tmp2:           .byte 0
scale_is_negative:  .byte 0
scale_magnitude:    .byte 0
scale_bit_idx:       .byte 0
exp_adjust_magnitude: .byte 0    ; new: saved original magnitude for exponent byte adjust
.endproc
