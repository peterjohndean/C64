.include "labels_rom_kernal.s"
.include "macros_rom_basic.s"
.include "labels_fp.s"
.include "../inc/values.h"

.macpack longbranch

.export recompute_decomp, draw_decomp
.export decomp_sign_ch, decomp_exp_byte
.export decomp_bias_str, decomp_mant_str
.export decomp_mant_int_str
.export decomp_ieee_sign_ch, decomp_ieee_exp_byte
.export decomp_ieee_bias_str, decomp_ieee_mant_str
.export decomp_basic_exp_byte
.export decomp_basic_bias_str

.import FP_TO_ASCII_SCI_V2, FP_NEGATE, FP_FROM_IEEE754
.import OUTPUT_BYTETOHEX

DECOMP_ROW_HEADER = 19
DECOMP_ROW_SIGN   = 20
DECOMP_ROW_MANT   = 21
DECOMP_ROW_FORM   = 22
DECOMP_ROW_CHECK  = 23

.segment "BSS"
decomp_sign_ch:         .byte 0     ; '+' or '-'
decomp_exp_byte:        .byte 0     ; raw byte
decomp_bias_str:        .res 5,0    ; "+2\0" or "-128\0" or "+0\0"
decomp_mant_str:        .res 16,0   ; "1.141592\0"
decomp_mant_int_str:    .res 10,0   ; NEW — "-8388608\0" worst case
decomp_check_str:       .res 16,0   ; reserved for future check-line feature
decomp_ieee_sign_ch:    .byte 0
decomp_ieee_exp_byte:   .byte 0
decomp_ieee_bias_str:   .res 5,0
decomp_ieee_mant_str:   .res 16,0
decomp_basic_exp_byte:  .byte 0
decomp_basic_bias_str:  .res 5,0
.segment "CODE"

; ============================================================
; PROCEDURE : build_mant_int_str
; Purpose : Convert current_value's 3 mantissa bytes
;           (interpreted as a signed 24-bit integer) to a
;           decimal string in decomp_mant_int_str.
;
; Used by the reverse Woz step 3 in the printed report, where the
; reader is shown the raw mantissa integer alongside its fraction.
;
; Algorithm : successive subtraction against a 7-entry table of
;             powers of ten (10^6 down to 10^0). For each power,
;             subtract repeatedly and count; the count is the
;             decimal digit. Leading zeros suppressed by a
;             "started" flag.
;
; Range : signed 24-bit, so [-8388608, +8388607]. Worst case is
;         8 chars ("-8388608") + null = 9 bytes.
; ============================================================
.proc build_mant_int_str
    lda #0
    sta @out_pos

    ; --- sign extraction and magnitude ---
    lda LayoutValues::current_value+1
    bpl @positive
    lda #'-'
    sta decomp_mant_int_str
    inc @out_pos
    sec
    lda #0
    sbc LayoutValues::current_value+3
    sta @m24_b2
    lda #0
    sbc LayoutValues::current_value+2
    sta @m24_b1
    lda #0
    sbc LayoutValues::current_value+1
    sta @m24_b0
    jmp @convert

@positive:
    lda LayoutValues::current_value+1
    sta @m24_b0
    lda LayoutValues::current_value+2
    sta @m24_b1
    lda LayoutValues::current_value+3
    sta @m24_b2

@convert:
    lda #0
    sta @started
    ldx #0
@digit_loop:
    cpx #21
    bcs @finish
    jsr @count_pow10
    lda @digit_count
    bne @emit_digit
    lda @started
    beq @next_pow10
    lda #'0'
    jmp @store
@emit_digit:
    lda #1
    sta @started
    lda @digit_count
    clc
    adc #'0'
@store:
    ldy @out_pos
    sta decomp_mant_int_str,y
    inc @out_pos
@next_pow10:
    txa
    clc
    adc #3
    tax
    jmp @digit_loop

@finish:
    ; If nothing was emitted (all-zero mantissa), emit "0"
    lda @started
    bne @terminate
    lda #'0'
    ldy @out_pos
    sta decomp_mant_int_str,y
    inc @out_pos
@terminate:
    ldy @out_pos
    lda #0
    sta decomp_mant_int_str,y
    rts

    ; --- @count_pow10: X = offset into pow10_24 table.
    ;     Subtracts pow10_24[X..X+2] from @m24_b0..2 repeatedly,
    ;     counting how many fit. Count left in @digit_count.
@count_pow10:
    lda #0
    sta @digit_count
@try_subtract:
    sec
    lda @m24_b2
    sbc pow10_24+2,x
    sta @tmp2
    lda @m24_b1
    sbc pow10_24+1,x
    sta @tmp1
    lda @m24_b0
    sbc pow10_24+0,x
    sta @tmp0
    bcc @no_more
    lda @tmp0
    sta @m24_b0
    lda @tmp1
    sta @m24_b1
    lda @tmp2
    sta @m24_b2
    inc @digit_count
    jmp @try_subtract
@no_more:
    rts

.segment "BSS"
@m24_b0:      .byte 0
@m24_b1:      .byte 0
@m24_b2:      .byte 0
@tmp0:        .byte 0
@tmp1:        .byte 0
@tmp2:        .byte 0
@digit_count: .byte 0
@started:     .byte 0
@out_pos:     .byte 0
.segment "CODE"
.endproc

.segment "RODATA"
pow10_24:
    .byte $0F, $42, $40    ; 1,000,000
    .byte $01, $86, $A0    ;   100,000
    .byte $00, $27, $10    ;    10,000
    .byte $00, $03, $E8    ;     1,000
    .byte $00, $00, $64    ;       100
    .byte $00, $00, $0A    ;        10
    .byte $00, $00, $01    ;         1
.segment "CODE"

; ============================================================
; PROCEDURE : recompute_basic_decomp
; Purpose : Extract BASIC's exponent byte and compute its bias
;           string. Sign and mantissa are the same as Woz's for
;           the same value, so they are reused directly.
;
; Bias shown = byte - 129, because the mantissa is displayed in
; [1.0, 2.0) form here but BASIC's native normalization is
; [0.5, 1.0). Equivalent to Woz's byte - 128 for the same value.
; ============================================================
.proc recompute_basic_decomp
    lda LayoutValues::basic_bytes+0
    sta decomp_basic_exp_byte

    cmp #0
    bne @nonzero

    ; zero: neutral bias string
    lda #'+'
    sta decomp_basic_bias_str
    lda #'0'
    sta decomp_basic_bias_str+1
    lda #0
    sta decomp_basic_bias_str+2
    rts

@nonzero:
    sec
    sbc #129
    bpl @bias_pos
    pha
    lda #'-'
    sta decomp_basic_bias_str
    pla
    eor #$FF
    clc
    adc #1
    jsr @format_digits
    rts
@bias_pos:
    pha
    lda #'+'
    sta decomp_basic_bias_str
    pla
    jsr @format_digits
    rts

@format_digits:
    ; A = 0..128 -> 1-3 digits at decomp_basic_bias_str+1 onwards
    ldx #0
@h:
    cmp #100
    bcc @hd
    sec
    sbc #100
    inx
    jmp @h
@hd:
    pha
    txa
    beq @nh
    clc
    adc #'0'
    sta decomp_basic_bias_str+1
    lda #1
    sta @idx
    jmp @tp
@nh:
    lda #0
    sta @idx
@tp:
    pla
    ldx #0
@t:
    cmp #10
    bcc @td
    sec
    sbc #10
    inx
    jmp @t
@td:
    pha
    txa
    beq @nt
    clc
    adc #'0'
    ldx @idx
    sta decomp_basic_bias_str+1,x
    inc @idx
    jmp @u
@nt:
    lda @idx
    beq @u
    lda #'0'
    ldx @idx
    sta decomp_basic_bias_str+1,x
    inc @idx
@u:
    pla
    clc
    adc #'0'
    ldx @idx
    sta decomp_basic_bias_str+1,x
    lda #0
    inx
    sta decomp_basic_bias_str+1,x
    rts

.segment "BSS"
@idx: .byte 0
.segment "CODE"
.endproc

; ============================================================
; PROCEDURE : recompute_ieee_decomp
; Purpose : Extract IEEE-754 sign / exponent / significand from
;           LayoutValues::ieee754_bytes into the decomp_ieee_*
;           fields.
;
; The significand decimal comes from converting the IEEE bytes
; back to Woz, forcing the result positive, and setting FP1_EXP
; to $80 so the value IS the significand (in [1, 2)).
; ============================================================
.proc recompute_ieee_decomp
    ; --- sign bit (byte 0, bit 7) ---
    lda LayoutValues::ieee754_bytes+0
    bpl @pos
    lda #'-'
    sta decomp_ieee_sign_ch
    jmp @exp
@pos:
    lda #'+'
    sta decomp_ieee_sign_ch

@exp:
    ; --- reconstruct the 8-bit exponent field ---
    ; = (byte0 & $7F) << 1 | (byte1 >> 7)
    lda LayoutValues::ieee754_bytes+0
    and #$7F
    asl                       ; A = (byte0 & $7F) << 1
    sta @exp_lo
    lda LayoutValues::ieee754_bytes+1
    and #$80
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr                       ; A = byte1 top bit -> bit 0

    ora @exp_lo
    sta decomp_ieee_exp_byte

    ; --- bias string = exp_field - 127 ---
    sec
    sbc #127
    bpl @bias_pos
    pha
    lda #'-'
    sta decomp_ieee_bias_str
    pla
    eor #$FF
    clc
    adc #1
    jsr @bias_digits
    jmp @mant
@bias_pos:
    pha
    lda #'+'
    sta decomp_ieee_bias_str
    pla
    jsr @bias_digits
@mant:

    ; --- significand decimal ---
    ; Zero check first: all four bytes zero -> "0.000000"
    lda LayoutValues::ieee754_bytes+0
    ora LayoutValues::ieee754_bytes+1
    ora LayoutValues::ieee754_bytes+2
    ora LayoutValues::ieee754_bytes+3
    bne @ieee_nonzero

    lda #'0'
    sta decomp_ieee_mant_str
    lda #'.'
    sta decomp_ieee_mant_str+1
    ldx #2
@ieee_zero_fill:
    lda #'0'
    sta decomp_ieee_mant_str,x
    inx
    cpx #8
    bne @ieee_zero_fill
    lda #0
    sta decomp_ieee_mant_str+8
    rts

@ieee_nonzero:
    ; --- exponent field of 0: distinguish zero / subnormal ---
    lda LayoutValues::ieee754_bytes+0
    and #$7F
    jne @ieee_do_convert          ; exp field != 0 -> normal
    lda LayoutValues::ieee754_bytes+1
;    jpl @ieee_do_convert          ; exp field != 0 -> normal
    jmi @ieee_do_convert

    ; exp field is 0. Fraction = (B1 & $7F):B2:B3.
    lda LayoutValues::ieee754_bytes+1
    and #$7F
    ora LayoutValues::ieee754_bytes+2
    ora LayoutValues::ieee754_bytes+3
    jeq @ieee_zero_mant           ; true zero -> "0.000000"

    ; subnormal: representable in Woz only if F >= 2^22
    lda LayoutValues::ieee754_bytes+1
    and #$40                      ; bit 22 of F
    jeq @ieee_zero_mant           ; below Woz floor -> "0.000000"

    ; --- representable subnormal: emit "0.dddddd" directly ---
    ; Digits of F / 2^23 are extracted one at a time by repeated
    ; multiply-by-10 on the 23-bit remainder.
    ;   F in [2^22, 2^23)  =>  F/2^23 in [0.5, 1.0)
    ;   T = F * 10 fits in 27 bits (4 bytes)
    ;   digit = ((T.byte3 & $07) << 1) | (T.byte2 >> 7)
    ;   F' = (T.byte2 & $7F):T.byte1:T.byte0

    lda LayoutValues::ieee754_bytes+1
    and #$7F
    sta @f2
    lda LayoutValues::ieee754_bytes+2
    sta @f1
    lda LayoutValues::ieee754_bytes+3
    sta @f0

    lda #'0'
    sta decomp_ieee_mant_str+0
    lda #'.'
    sta decomp_ieee_mant_str+1

    ldx #0
@sub_digit_loop:
    lda @f0
    asl
    sta @d0
    lda @f1
    rol
    sta @d1
    lda @f2
    rol
    sta @d2
    lda #0
    rol
    sta @d3

    lda @d0
    asl
    sta @e0
    lda @d1
    rol
    sta @e1
    lda @d2
    rol
    sta @e2
    lda @d3
    rol
    sta @e3
    asl @e0
    rol @e1
    rol @e2
    rol @e3

    clc
    lda @d0
    adc @e0
    sta @t0
    lda @d1
    adc @e1
    sta @t1
    lda @d2
    adc @e2
    sta @t2
    lda @d3
    adc @e3
    sta @t3

    lda @t2
    asl
    lda @t3
    and #$07
    rol
    clc
    adc #'0'
    sta decomp_ieee_mant_str+2,x

    lda @t0
    sta @f0
    lda @t1
    sta @f1
    lda @t2
    and #$7F
    sta @f2

    inx
    cpx #6
    jne @sub_digit_loop

    lda #0
    sta decomp_ieee_mant_str+8
    rts

@ieee_zero_mant:
    lda #'0'
    sta decomp_ieee_mant_str
    lda #'.'
    sta decomp_ieee_mant_str+1
    ldx #2
@ieee_zero_fill2:
    lda #'0'
    sta decomp_ieee_mant_str,x
    inx
    cpx #8
    bne @ieee_zero_fill2
    lda #0
    sta decomp_ieee_mant_str+8
    rts

@ieee_do_convert:
    ; --- save live FP1 ---
    lda FP1_EXP
    pha
    lda FP1_MANT
    pha
    lda FP1_MANT+1
    pha
    lda FP1_MANT+2
    pha

    ; --- load ieee754_bytes into FP1, convert to Woz ---
    lda LayoutValues::ieee754_bytes+0
    sta FP1_EXP
    lda LayoutValues::ieee754_bytes+1
    sta FP1_MANT
    lda LayoutValues::ieee754_bytes+2
    sta FP1_MANT+1
    lda LayoutValues::ieee754_bytes+3
    sta FP1_MANT+2
    jsr FP_FROM_IEEE754

    ; --- force positive ---
    lda FP1_MANT
    bpl @ieee_pos
    jsr FP_NEGATE
@ieee_pos:

    ; --- set exponent to $80 so the value IS the significand ---
    lda #$80
    sta FP1_EXP

    ; --- format ---
    lda #<decomp_ieee_mant_str
    ldy #>decomp_ieee_mant_str
    ldx #6
    jsr FP_TO_ASCII_SCI_V2

    ; --- strip "E±NN" suffix ---
    ldy #0
@ieee_strip:
    lda decomp_ieee_mant_str,y
    beq @ieee_strip_done
    cmp #$45
    beq @ieee_do_strip
    iny
    jmp @ieee_strip
@ieee_do_strip:
    lda #0
    sta decomp_ieee_mant_str,y
@ieee_strip_done:

    ; --- restore live FP1 ---
    pla
    sta FP1_MANT+2
    pla
    sta FP1_MANT+1
    pla
    sta FP1_MANT
    pla
    sta FP1_EXP
    rts

@bias_digits:
    ; A = 0..128 -> 1-3 digits into decomp_ieee_bias_str+1..
    ; (same logic as the woz bias formatter)
    ldx #0
@bd_h:
    cmp #100
    bcc @bd_hd
    sec
    sbc #100
    inx
    jmp @bd_h
@bd_hd:
    pha
    txa
    beq @bd_nh
    clc
    adc #'0'
    sta decomp_ieee_bias_str+1
    lda #1
    sta @bd_idx
    jmp @bd_tp
@bd_nh:
    lda #0
    sta @bd_idx
@bd_tp:
    pla
    ldx #0
@bd_t:
    cmp #10
    bcc @bd_td
    sec
    sbc #10
    inx
    jmp @bd_t
@bd_td:
    pha
    txa
    beq @bd_nt
    clc
    adc #'0'
    ldx @bd_idx
    sta decomp_ieee_bias_str+1,x
    inc @bd_idx
    jmp @bd_u
@bd_nt:
    lda @bd_idx
    beq @bd_u
    lda #'0'
    ldx @bd_idx
    sta decomp_ieee_bias_str+1,x
    inc @bd_idx
@bd_u:
    pla
    clc
    adc #'0'
    ldx @bd_idx
    sta decomp_ieee_bias_str+1,x
    lda #0
    inx
    sta decomp_ieee_bias_str+1,x
    rts

.segment "BSS"
@exp_lo: .byte 0
@bd_idx: .byte 0
@f0: .byte 0
@f1: .byte 0
@f2: .byte 0
@d0: .byte 0
@d1: .byte 0
@d2: .byte 0
@d3: .byte 0
@e0: .byte 0
@e1: .byte 0
@e2: .byte 0
@e3: .byte 0
@t0: .byte 0
@t1: .byte 0
@t2: .byte 0
@t3: .byte 0
.segment "CODE"
.endproc

; ============================================================
; PROCEDURE : recompute_decomp
; Purpose : Populate decomp_sign_ch / decomp_exp_byte /
;           decomp_bias_str / decomp_mant_str from current_value,
;           for draw_decomp to display.
;
; ZERO SPECIAL-CASE (see project conversation)
; ---------------------------------------------
; Both canonical zero (exp=$00, mant=$00,$00,$00) AND
; non-canonical zero (exp != $00, mant=$00,$00,$00) must be
; short-circuited HERE, before any FP work. Without this, the
; synthetic FP1 built for the mantissa decimal (exp=$80,
; mant=$00,$00,$00) reaches FP_TO_ASCII_SCI_V2's normalisation
; loop, which looks for a mantissa >= 1.0 -- but a zero mantissa
; can never satisfy that, and the loop's multiply-by-10 climbs the
; exponent until FP_FMUL traps on overflow. Observed hang at
; $17C2 during diag_decomp.py's zero-input case.
; ============================================================
.proc recompute_decomp
    ; --- Zero early-out: check mantissa bytes at +1, +2, +3.
    ;     If all zero, the value is zero regardless of exponent.
    lda LayoutValues::current_value+1
    ora LayoutValues::current_value+2
    ora LayoutValues::current_value+3
    bne @nonzero

    ; --- Zero path: neutral strings for every field ---
    lda #'+'
    sta decomp_sign_ch

    lda #0
    sta decomp_exp_byte

    lda #'+'
    sta decomp_bias_str
    lda #'0'
    sta decomp_bias_str+1
    lda #0
    sta decomp_bias_str+2

    lda #'0'
    sta decomp_mant_str
    lda #'.'
    sta decomp_mant_str+1
    ldx #2
@zero_fill:
    lda #'0'
    sta decomp_mant_str,x
    inx
    cpx #8
    bne @zero_fill
    lda #0
    sta decomp_mant_str+8

    ; NEW: mantissa integer is "0"
    lda #'0'
    sta decomp_mant_int_str
    lda #0
    sta decomp_mant_int_str+1

    jmp @finalize                    ; was: rts

@nonzero:
    ; --- 1. Sign (from mantissa MSB) ---
    lda LayoutValues::current_value+1
    bpl @sign_positive
    lda #'-'
    sta decomp_sign_ch
    jmp @exp
@sign_positive:
    lda #'+'
    sta decomp_sign_ch

@exp:
    lda LayoutValues::current_value
    sta decomp_exp_byte

    ; --- 2. Bias string (exp - 128, signed) ---
    sec
    sbc #128                   ; A = signed bias
    bpl @bias_positive
    pha
    lda #'-'
    sta decomp_bias_str
    pla
    eor #$FF
    clc
    adc #1                     ; A = |bias|
    jsr @format_bias_digits
    jmp @mant
@bias_positive:
    pha
    lda #'+'
    sta decomp_bias_str
    pla
    jsr @format_bias_digits
@mant:

    ; --- 3. Mantissa decimal (synthetic FP1 = 0x80, m0, m1, m2) ---
    ; Save live FP1
    lda FP1_EXP
    pha
    lda FP1_MANT
    pha
    lda FP1_MANT+1
    pha
    lda FP1_MANT+2
    pha

    lda #$80
    sta FP1_EXP
    lda LayoutValues::current_value+1
    sta FP1_MANT
    lda LayoutValues::current_value+2
    sta FP1_MANT+1
    lda LayoutValues::current_value+3
    sta FP1_MANT+2

    lda FP1_MANT
    bpl @format_mant
    jsr FP_NEGATE
@format_mant:
    lda #<decomp_mant_str
    ldy #>decomp_mant_str
    ldx #6
    jsr FP_TO_ASCII_SCI_V2

    ; Strip "E±NN" suffix
    ldy #0
@strip_e:
    lda decomp_mant_str,y
    beq @strip_done
    cmp #$45                   ; 'E' (raw PETSCII)
    beq @do_strip
    iny
    jmp @strip_e
@do_strip:
    lda #0
    sta decomp_mant_str,y
@strip_done:

    ; Restore live FP1
    pla
    sta FP1_MANT+2
    pla
    sta FP1_MANT+1
    pla
    sta FP1_MANT
    pla
    sta FP1_EXP

    ; NEW: build the mantissa integer string. Reads current_value
    ; directly, doesn't touch FP1, so it's safe to call here.
    jsr build_mant_int_str

    ; fall through to @finalize      ; was: rts

@finalize:
    jsr recompute_ieee_decomp
    jsr recompute_basic_decomp
    rts

@format_bias_digits:
    ; A = 0..128. Split into hundreds, tens, units.
    ldx #0
@hundreds_loop:
    cmp #100
    bcc @hundreds_done
    sec
    sbc #100
    inx
    jmp @hundreds_loop
@hundreds_done:
    pha
    txa
    beq @no_hundreds
    clc
    adc #'0'
    sta decomp_bias_str+1
    lda #1
    sta @tens_count
    jmp @tens_prep
@no_hundreds:
    lda #0
    sta @tens_count
@tens_prep:
    pla
    ldx #0
@tens_loop:
    cmp #10
    bcc @tens_done
    sec
    sbc #10
    inx
    jmp @tens_loop
@tens_done:
    pha
    txa
    beq @no_tens_digit
    clc
    adc #'0'
    ldx @tens_count
    sta decomp_bias_str+1,x
    inc @tens_count
    jmp @units
@no_tens_digit:
    lda @tens_count
    beq @units
    lda #'0'
    ldx @tens_count
    sta decomp_bias_str+1,x
    inc @tens_count
@units:
    pla
    clc
    adc #'0'
    ldx @tens_count
    sta decomp_bias_str+1,x
    lda #0
    inx
    sta decomp_bias_str+1,x
    rts

.segment "BSS"
@tens_count: .byte 0
.segment "CODE"
.endproc

.proc draw_decomp
    ; --- Header ---
    ldy #0
    ldx #DECOMP_ROW_HEADER
    clc
    jsr KERNAL_PLOT
    BASIC_STROUT_MACRO str_decomp_header

    ; --- Sign + exp + bias (one line) ---
    ldy #0
    ldx #DECOMP_ROW_SIGN
    clc
    jsr KERNAL_PLOT
    BASIC_STROUT_MACRO str_sign_lbl     ; "  sign: "
    lda decomp_sign_ch
    jsr KERNAL_CHROUT
    BASIC_STROUT_MACRO str_exp_lbl      ; "    exp: $"
    lda decomp_exp_byte
    jsr OUTPUT_BYTETOHEX
    BASIC_STROUT_MACRO str_bias_lbl     ; "  bias: "
    BASIC_STROUT_MACRO decomp_bias_str

    ; --- Mantissa line ---
    ldy #0
    ldx #DECOMP_ROW_MANT
    clc
    jsr KERNAL_PLOT
    BASIC_STROUT_MACRO str_mant_lbl     ; "  mantissa: $"
    lda LayoutValues::current_value+1
    jsr OUTPUT_BYTETOHEX
    lda #' '
    jsr KERNAL_CHROUT
    lda LayoutValues::current_value+2
    jsr OUTPUT_BYTETOHEX
    lda #' '
    jsr KERNAL_CHROUT
    lda LayoutValues::current_value+3
    jsr OUTPUT_BYTETOHEX
    BASIC_STROUT_MACRO str_mant_eq      ; "  =  "
    BASIC_STROUT_MACRO decomp_mant_str

    ; --- Formula (static) ---
    ldy #0
    ldx #DECOMP_ROW_FORM
    clc
    jsr KERNAL_PLOT
    BASIC_STROUT_MACRO str_formula

        ; --- Check line: mantissa x 2^bias = value ---
    ; The right-hand side reuses LayoutValues::decimal_str, which
    ; recompute_representations already produced (via
    ; FP_TO_ASCII_SCI_V2 at X=4). Reusing the cached string keeps
    ; the check line consistent with the decimal row at the top of
    ; the screen: if they ever disagree, that's a real bug worth
    ; seeing. Requires recompute_representations to have run before
    ; draw_decomp -- which refresh_display already guarantees.
    ldy #0
    ldx #DECOMP_ROW_CHECK
    clc
    jsr KERNAL_PLOT
    BASIC_STROUT_MACRO str_check_lbl    ; "  = "
    BASIC_STROUT_MACRO decomp_mant_str  ; e.g. "1.141592"
    BASIC_STROUT_MACRO str_times        ; " x 2^"
    BASIC_STROUT_MACRO decomp_bias_str  ; bias digits (skip sign)
    BASIC_STROUT_MACRO str_equals       ; " = "
    BASIC_STROUT_MACRO LayoutValues::decimal_str   ; e.g. "4.5664E+00"

    rts
.endproc

.segment "RODATA"
str_decomp_header:
    .byte $60,$60,$60,$60
    .asciiz " decomposition "
    .byte $60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$60
    .byte $60,$60,$60,$60
    .byte 0
str_sign_lbl:   .asciiz "  sign: "
str_exp_lbl:    .asciiz "    exp: $"
str_bias_lbl:   .asciiz "  bias: "
str_mant_lbl:   .asciiz "  mantissa: $"
str_mant_eq:    .asciiz "  = "
str_formula:    .asciiz "  formula: value = mantissa x 2^bias"
str_check_lbl:  .asciiz "  = "
str_times:      .asciiz " x 2^"
str_equals:     .asciiz " = "
.segment "CODE"
