.include "macros_fp.s"
.macpack longbranch

.export FP_TO_ASCII24
.import FP_FSUB, FP_FMUL
.import FP_NEGATE, FP_NORM
.import FP_TO_INT24
.import FP_FROM_INT8, FP_TO_INT8

FP_TO_ASCII24 = FP_TO_ASCII24_PROC

.segment "CODE"
; ============================================================
; PROCEDURE : FP_TO_ASCII24_PROC
; Purpose : Same job as FP_TO_ASCII_PROC (format FP1 as a fixed-
;           point decimal string), but with the integer part
;           extracted via FP_TO_INT24_PROC instead of
;           FP_TO_INT16_PROC, raising the integer-part ceiling from
;           65,535 to 8,388,607. FP_TO_ASCII_PROC is left
;           completely unchanged (still capped at 65,535) rather
;           than modified in place - the two coexist so existing
;           call sites keep their exact previous behaviour, and
;           this one is available where the wider range is needed.
; SCOPE (signed, not unsigned)
; -----------------------------
; FP_TO_INT24_PROC is a SIGNED 24-bit conversion - it traps with a
; generic overflow (FP_ERROR_CODE = 0) once the magnitude reaches
; 2^23 = 8,388,608 (see T53 in fp_tests.s, which verifies exactly
; this boundary). This formatter inherits that ceiling as-is; it
; does NOT attempt to reach the full unsigned 24-bit range
; (16,777,215) the way FP_FROM_UINT24_PROC does on the opposite
; conversion direction. Reaching the full unsigned range here would
; need a companion FP_TO_UINT24_PROC that skips the signed check -
; deliberately out of scope for now.
; Exactly like FP_TO_ASCII_PROC, this proc installs no
; FP_ERROR_INIT_MACRO guard of its own around the risky call - an
; out-of-range value traps upward to whatever guard the CALLER
; armed. Callers passing a value that might exceed 8,388,607 must
; arm their own guard first, same contract as the 16-bit version.
; Entry   : A = output buffer address low byte
;           Y = output buffer address high byte
;           X = number of fractional digits to produce (0 for
;               integer-only output)
; Exit    : null-terminated decimal string written to the buffer
; Destroys: A, X, Y; FP1, FP2
;
; WHEN TO USE THIS VS FP_TO_ASCII_PROC
; -----------------------------------------
; Use FP_TO_ASCII24_PROC when the integer part of the value being
; printed can exceed 65,535. Use plain FP_TO_ASCII_PROC when you
; already know it can't, for this specific call site - the two
; behave identically for any value the 16-bit routine could already
; handle, so there's no reason to switch an existing, already-tested
; call site. For NEW call sites where you're not sure, prefer
; FP_TO_ASCII24_PROC - the only cost is a slightly larger integer-
; part ceiling check (still just as fast for small values), and it
; has no downside relative to FP_TO_ASCII_PROC once the value is in
; range.
;
; PRECISION BUDGET BY MAGNITUDE
; --------------------------------
; However many digits are asked for via X, the format itself can
; only ever supply as many fractional bits as are left over after
; the integer part's own bits are accounted for (23 total mantissa
; bits - see FP_TO_INT24_PROC's SCOPE note above for where the 23
; comes from). This table is the same fact fp_tests.s's T59-T63
; discovered by hand, generalised - use it to predict, for a given
; integer part, how finely a fraction can actually be held:
;
;   integer part range      bits used   frac bits left   granularity
;   -----------------------------------------------------------------
;       4,096 -     8,191      13            10            1/1024
;       8,192 -    16,383      14             9             1/512
;      16,384 -    32,767      15             8             1/256
;      32,768 -    65,535      16             7             1/128
;      65,536 -   131,071      17             6              1/64
;     131,072 -   262,143      18             5              1/32
;     262,144 -   524,287      19             4              1/16
;     524,288 - 1,048,575      20             3               1/8
;   1,048,576 - 2,097,151      21             2               1/4
;   2,097,152 - 4,194,303      22             1               1/2
;   4,194,304 - 8,388,607      23             0        (integer only)
;
; Below 4,096 there's enough room for finer fractions still (more
; than 10 bits); this table stops there because it's already more
; precision than a few decimal digits need. A fraction that isn't an
; exact multiple of its row's granularity FLOORS to the nearest one
; during FP_FROM_ASCII24_PROC's parse-time FP_FADD combine (FP_FADD
; truncates rather than rounds - confirmed on real hardware, not
; just derived) - it does not fail, error out, or produce garbage,
; it just silently loses precision below that row's granularity.
; This is a property of the 4-byte float format at that magnitude,
; not a bug in either ASCII routine, and no parsing strategy can
; avoid it - see lib_fp_from_ascii24.s's WHEN TO USE note for the
; parser side of this same fact.
;
; What changed from FP_TO_ASCII_PROC, and what didn't
; --------------------------------------------------------
; The integer-part extraction/printing engine is genuinely
; different (FP_TO_INT24_PROC instead of FP_TO_INT16_PROC, a 3-byte
; subtract-and-print loop instead of 2-byte, an 8-entry power-of-
; ten table instead of 5-entry, using CC65's carot operator
; for the 24-bit table's third byte - the same technique
; macros_reu.s already uses for REU bank addressing). The
; fractional-digit loop (the per-digit @frac_loop below) is
; IDENTICAL to FP_TO_ASCII_PROC's and is reused unchanged, along
; with the same print_integer-destroys-its-input fix (separate
; int_*/work_* copies) applied here from the start.
;
; FRACTIONAL EXTRACTION: DIRECT BIT MASK, NOT FP_FSUB
; -----------------------------------------------------
; Recovering the fractional remainder (original value minus the
; integer part) used to be done the "obvious" way: reconstruct the
; integer part as a float via FP_NORM, then jsr FP_FSUB against the
; backed-up original. Real-hardware testing (T59 in fp_tests.s,
; input 1234567.25) found this loses the ENTIRE fractional part -
; FP_FSUB returned exactly 0.0 - specifically when subtracting a
; large, precision-maxed value from another of nearly the same
; magnitude. The exact internal mechanism was traced as far as
; disassembly-level verification allows without conclusively
; explaining it (see the project's debugging notes); rather than
; risk a partial fix to FP_FSUB itself - a small, heavily shared
; routine used throughout this whole library - this proc instead
; sidesteps it ENTIRELY for this one extraction, computing the
; fraction directly from the original mantissa's bits. FP_FSUB is
; NOT modified anywhere, and is still used unchanged by the
; per-digit @frac_loop below, where it has never shown this problem
; (that loop always subtracts a single 0-9 digit from a value of
; similar small magnitude, not a huge-vs-tiny pair).
;
; THE MATH
; --------
; This format stores value = mantissa * 2^(exp-150) (mantissa is
; the 24-bit signed integer, exp the exponent byte). Given
; int_part = floor(value) (already computed above via
; FP_TO_INT24_PROC), int_part's own contribution to the ORIGINAL
; mantissa is exactly int_part << (150-exp) - and critically, the
; low (150-exp) bits of THAT product are, by construction, always
; zero (multiplying by a power of 2 that large can't set them).
; That means the original mantissa's low (150-exp) bits already ARE
; the fractional part's raw contribution, completely unmixed with
; any integer-part bits - recovering them is a MASK, not a
; subtraction. Zeroing the mantissa's high bits down to that many
; low bits (via a shift-left/shift-right pair, rather than
; constructing an explicit runtime bitmask value), then handing the
; ORIGINAL exponent to FP_NORM as a seed, reproduces exactly the
; same normalize-and-decrement technique FP_NORM already performs
; elsewhere in this file for the integer part - just seeded with
; different starting bits. Verified by hand against T59's own
; values: masking 1234567.25's mantissa this way and normalizing
; produces exactly 0.25, matching what FP_FADD in
; lib_fp_from_ascii24.s independently proved is the exact correct
; answer for this same value.
; ============================================================
.proc FP_TO_ASCII24_PROC
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
    FP_STORE1_MACRO backup     ; back up the absolute value -
                                ; needed again below for the  fractional part
    jsr FP_TO_INT24            ; NOTE: values > 8,388,607 are out of scope for this
                                ; formatter - FP_TO_INT24 is a signed 24-bit
                                ; conversion and traps (code 0, generic overflow)
                                ; above that boundary. Uncaught here on purpose -
                                ; see the file header SCOPE note
    lda FP1_MANT
    sta work_hi
    lda FP1_MANT+1
    sta work_mid
    lda FP1_MANT+2
    sta work_lo                 ; work_hi/mid/lo: @print_integer24's own
                                ; disposable copy (it destroys its input) -
                                ; int_hi/mid/lo no longer needed as a
                                ; separate backup since the fraction is
                                ; now derived straight from `backup`'s
                                ; original mantissa, not by reloading the
                                ; truncated integer (see FRACTIONAL
                                ; EXTRACTION note above)
    jsr @print_integer24
    lda frac_count
    jeq @terminate
    ldy out_pos
    lda #'.'
    sta (FP_STRPTR),y
    inc out_pos

    ; --- recover the fractional remainder by masking the ORIGINAL
    ;     mantissa's low bits directly - see the file header's
    ;     FRACTIONAL EXTRACTION note for why this replaced an
    ;     FP_NORM+FP_FSUB reconstruction ---
    lda #150
    sec
    sbc backup                  ; A = 150 - original exponent = how many
                                ; low mantissa bits are fractional
    bpl @frac_bits_ok           ; shouldn't go negative given int_part is
                                ; already known <= 8,388,607, but guard
                                ; rather than trust it
    lda #0
@frac_bits_ok:
    cmp #24
    bcc @frac_bits_clamped
    lda #24                     ; clamp: whole mantissa is fractional
                                ; (int_part = 0's case, e.g. a bare
                                ; ".25" - see T63)
@frac_bits_clamped:
    sta frac_bits
    lda #24
    sec
    sbc frac_bits
    sta mask_shift               ; mask_shift = how many high (integer)
                                ; bits to zero out

    lda backup+1
    sta FP1_MANT
    lda backup+2
    sta FP1_MANT+1
    lda backup+3
    sta FP1_MANT+2               ; FP1_MANT = a copy of the ORIGINAL
                                ; mantissa (not the reconstructed
                                ; integer part) - this copy is what
                                ; gets masked in place below

    ldx mask_shift
    beq @masked                  ; nothing to mask off (frac_bits was
                                ; already 24 - the whole mantissa)
@mask_left:
    asl FP1_MANT+2
    rol FP1_MANT+1
    rol FP1_MANT                 ; shift the 24-bit mantissa left 1 bit,
                                ; discarding whatever falls off the top -
                                ; exactly the integer-part bits we want
                                ; gone
    dex
    bne @mask_left
    ldx mask_shift
@mask_right:
    lsr FP1_MANT
    ror FP1_MANT+1
    ror FP1_MANT+2               ; shift back right the same distance,
                                ; refilling with zeros from the top - the
                                ; left+right pair together is a pure
                                ; mask, no subtraction anywhere
    dex
    bne @mask_right
@masked:
    lda backup
    sta FP1_EXP                  ; the masked bits are still at their
                                ; ORIGINAL scale, so FP_NORM only needs
                                ; the original exponent as a seed
    jsr FP_NORM                  ; FP1 = exact fractional value, derived
                                ; entirely from shifts and FP_NORM - no
                                ; FP_FSUB call anywhere in this path
@frac_loop:
    FP_LOAD2_MACRO ten_const   ; FP2 = 10.0
    jsr FP_FMUL                 ; FP1 = fraction * 10
    FP_STORE1_MACRO backup
    jsr FP_TO_INT8              ; A = digit 0-9
    clc
    adc #'0'
    ldy out_pos
    sta (FP_STRPTR),y
    inc out_pos
    sec
    sbc #'0'                    ; recover raw digit
    jsr FP_FROM_INT8            ; FP1 = float(digit)
    FP_LOAD2_MACRO backup      ; FP2 = fraction*10
    jsr FP_FSUB                 ; FP1 = FP2-FP1 = next fractional remainder
    dec frac_count
    bne @frac_loop
@terminate:
    ldy out_pos
    lda #0
    sta (FP_STRPTR),y
    rts

; --- @print_integer24: writes work_hi:work_mid:work_lo (24-bit
;     unsigned) as decimal digits to (FP_STRPTR),out_pos, no
;     leading zeros (except the value 0 itself). Destroys its
;     input (work_*) - callers needing the value afterward must
;     keep their own copy, same contract as before ---
@print_integer24:
    ldx #0
    lda #0
    sta suppress_zero
@pow_loop:
    lda pow10_hi,x
    sta divisor_hi
    lda pow10_mid,x
    sta divisor_mid
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
    lda work_mid
    sbc divisor_mid
    sta cand_mid
    lda work_hi
    sbc divisor_hi
    bcc @sub_done               ; borrow: divisor > remainder, stop
    sta work_hi
    lda cand_mid
    sta work_mid
    lda cand_lo
    sta work_lo
    jmp @sub_loop
@sub_done:
    lda digit_count
    bne @have_digit
    lda suppress_zero
    bne @have_digit
    cpx #7
    beq @have_digit             ; ones place: always print, even if 0
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
    cpx #8
    bne @pow_loop
    rts

pow10_hi:       .byte ^10000000,^1000000,^100000,^10000,^1000,^100,^10,^1
pow10_mid:      .byte >10000000,>1000000,>100000,>10000,>1000,>100,>10,>1
pow10_lo:       .byte <10000000,<1000000,<100000,<10000,<1000,<100,<10,<1
backup:         .res 4,0
ten_const:      .byte $83,$50,$00,$00   ; 10.0 - own copy, same rationale
                                        ; as FP_TO_ASCII_PROC's
frac_count:     .byte 0
frac_bits:      .byte 0         ; how many low mantissa bits are
                                ; fractional (see FRACTIONAL EXTRACTION)
mask_shift:     .byte 0         ; 24 - frac_bits: how many high
                                ; (integer) bits to mask off
work_hi:        .byte 0         ; @print_integer24's own disposable
work_mid:       .byte 0         ; copy of the truncated integer -
work_lo:        .byte 0         ; see the file header's [BUG FIX] cross-reference
divisor_hi:     .byte 0
divisor_mid:    .byte 0
divisor_lo:     .byte 0
digit_count:    .byte 0
suppress_zero:  .byte 0
out_pos:        .byte 0
cand_lo:        .byte 0
cand_mid:       .byte 0
.endproc
