.include "macros_fp.s"
.macpack longbranch

.export FP_TO_ASCII
.import FP_FSUB, FP_FMUL
.import FP_NEGATE, FP_FLOAT
.import FP_TO_INT16
.import FP_FROM_INT8, FP_TO_INT8

FP_TO_ASCII = FP_TO_ASCII_PROC

.segment "CODE"
; ============================================================
; PROCEDURE : FP_TO_ASCII_PROC
; Purpose : Format FP1 as a fixed-point (never scientific notation)
;           decimal string. See the file header SCOPE note - the
;           integer part must fit in an unsigned 16-bit value
;           (0-65535).
; Entry   : A = output buffer address low byte
;           Y = output buffer address high byte
;           X = number of fractional digits to produce (0 for
;               integer-only output)
; Exit    : null-terminated decimal string written to the buffer
; Destroys: A, X, Y; FP1, FP2
;
; A COMPANION ROUTINE EXISTS: FP_TO_ASCII24_PROC
; ---------------------------------------------------
; This routine's integer-part ceiling comes from whichever integer-
; extraction routine it calls internally. If the value being printed
; can have an integer part larger than this routine supports, use
; FP_TO_ASCII24_PROC instead - see that file's own header for the
; exact ceiling, a precision-budget-by-magnitude table for the
; fractional part, and when to prefer one over the other. This
; routine is left completely unchanged for existing call sites.
; ============================================================
.proc FP_TO_ASCII_PROC
    sta FP_STRPTR
    sty FP_STRPTR+1
    stx frac_count
    lda #0
    sta out_pos
    lda FP1_MANT
    bpl @is_positive
    ldy out_pos
    lda #'-'
    sta (FP_STRPTR),y
    inc out_pos
    jsr FP_NEGATE
@is_positive:
    FP_STORE1_MACRO backup          ; back up the absolute value -
                                    ; needed again below for the
                                    ; fractional part
    jsr FP_TO_INT16                 ; NOTE: values >= 65536 are out of
                                    ; scope for this formatter - see the
                                    ; file header
    lda FP1_MANT
    sta int_hi
    sta work_hi                     ; [BUG FIX] print_integer's digit
    lda FP1_MANT+1                  ; extraction destroys its input in
    sta int_lo                      ; place (that's how repeated-
    sta work_lo                     ; subtraction digit extraction works)
                                    ; - it now consumes work_hi/work_lo
                                    ; instead, so int_hi/int_lo survive
                                    ; intact for the reconstruction
                                    ; below. Previously print_integer
                                    ; left int_hi/int_lo at 0 after
                                    ; printing, so "float(integer part)"
                                    ; below came out as float(0), and
                                    ; FP2-FP1 produced the WHOLE
                                    ; original value instead of just
                                    ; its fraction - verified: "42.25"
                                    ; fed 42.25 (not 0.25) into the
                                    ; fractional digit loop, corrupting
                                    ; the first fractional digit.
    jsr @print_integer
    lda frac_count
    jeq @terminate
    ldy out_pos
    lda #'.'
    sta (FP_STRPTR),y
    inc out_pos
    lda int_hi
    sta FP1_MANT
    lda int_lo
    sta FP1_MANT+1
    jsr FP_FLOAT                    ; FP1 = float(integer part)
    FP_LOAD2_MACRO backup           ; FP2 = original absolute value
    jsr FP_FSUB                     ; FP1 = FP2-FP1 = fractional part
@frac_loop:
    FP_LOAD2_MACRO ten_const        ; FP2 = 10.0
    jsr FP_FMUL                     ; FP1 = fraction * 10
    FP_STORE1_MACRO backup
    jsr FP_TO_INT8                  ; A = digit 0-9 (fraction*10 is
                                    ; always in this range here)
    clc
    adc #'0'
    ldy out_pos
    sta (FP_STRPTR),y
    inc out_pos
    sec
    sbc #'0'                        ; recover the raw digit value
    jsr FP_FROM_INT8                ; FP1 = float(digit)
    FP_LOAD2_MACRO backup           ; FP2 = fraction*10 (backup)
    jsr FP_FSUB                     ; FP1 = FP2-FP1 = next
                                    ; fractional remainder
    dec frac_count
    bne @frac_loop
@terminate:
    ldy out_pos
    lda #0
    sta (FP_STRPTR),y
    rts

; --- print_integer: writes int_hi:int_lo (16-bit unsigned) as
;     decimal digits to (FP_STRPTR),out_pos, no leading zeros
;     (except the value 0 itself, which prints as a single "0") ---
@print_integer:
    ldx #0
    lda #0
    sta suppress_zero
@pow_loop:
    lda pow10_hi,x
    sta divisor_hi
    lda pow10_lo,x
    sta divisor_lo
    lda #$ff
    sta digit_count
@sub_loop:
    inc digit_count
    lda work_lo
    sec
    sbc divisor_lo
    sta cand_lo
    lda work_hi
    sbc divisor_hi
    bcc @sub_done                   ; borrow: divisor > remainder, stop
    sta work_hi
    lda cand_lo
    sta work_lo
    jmp @sub_loop
@sub_done:
    lda digit_count
    bne @have_digit
    lda suppress_zero
    bne @have_digit
    cpx #4
    beq @have_digit                 ; ones place: always print, even if 0
    jmp @skip_digit
@have_digit:
    lda digit_count
    clc
    adc #'0'
    ldy out_pos
    sta (FP_STRPTR),y
    inc out_pos
    lda #1
    sta suppress_zero
@skip_digit:
    inx
    cpx #5
    bne @pow_loop
    rts

.segment "RODATA"
pow10_hi:       .byte >10000,>1000,>100,>10,>1
pow10_lo:       .byte <10000,<1000,<100,<10,<1
ten_const:      .byte $83,$50,$00,$00   ; 10.0 - own copy, kept separate from
                                        ; FP_FROM_ASCII_PROC's (matches this
                                        ; file's per-proc scratch convention)
.segment "BSS"
backup:         .res 4,0
frac_count:     .byte 0
int_hi:         .byte 0
int_lo:         .byte 0
work_hi:        .byte 0             ; print_integer's own disposable copy of
work_lo:        .byte 0             ; int_hi/int_lo - see the [BUG FIX] note
divisor_hi:     .byte 0
divisor_lo:     .byte 0
digit_count:    .byte 0
suppress_zero:  .byte 0
out_pos:        .byte 0
cand_lo:        .byte 0
.endproc
