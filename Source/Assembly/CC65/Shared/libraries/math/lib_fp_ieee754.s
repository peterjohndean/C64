.include "labels_fp.s"

.export FP_TO_IEEE754
.export FP_FROM_IEEE754

.import FP_NEGATE
.import FP_ERROR

.segment "CODE"
; ============================================================
; FILE    : lib_fp_ieee754.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; Converts FP1 between this library's native Woz/Rankin format and
; IEEE-754 single precision, for data interchange with modern
; systems (writing/reading a file another machine will read as a
; C `float`, exchanging values over a serial link, etc.) - NOT a
; change to the core format itself. All arithmetic (FADD, FMUL, LOG,
; EXP...) still operates on Woz format, which is a better fit for a
; 6502 with no hardware multiply: its 2's-complement mantissa lets
; FADD/FSUB use plain ADC/SBC with no separate sign-magnitude
; handling, unlike IEEE's format, which would need that on every
; operation. Converting only at the boundary, when you actually
; need to hand a value to something IEEE-754-shaped, gets the
; interchange benefit without paying that cost throughout the
; library or re-deriving (and re-testing) every routine already
; built and proven against Woz format.
;
; BOTH FORMATS ARE 4 BYTES, WITH SIMILAR (NOT IDENTICAL) PRECISION
; --------------------------------------------------------------------
; Woz: 1 exponent byte (excess-128) + 3 mantissa bytes, 2's
; complement, 22 explicit fraction bits (the sign bit and one
; "boundary" bit account for the rest).
; IEEE-754 single: 1 sign bit + 8 exponent bits (bias 127) + 23
; fraction bits, with an implicit (unstored) leading 1 for
; normalized values.
; IEEE has ONE MORE explicit fraction bit than Woz (23 vs 22), so
; Woz -> IEEE is always exact (the extra bit is simply zero-padded);
; IEEE -> Woz can lose IEEE's least significant fraction bit,
; which the format's own precision (~7 significant decimal digits)
; already doesn't guarantee past anyway.
;
; WHAT ISN'T HANDLED
; ---------------------
; This is a data-interchange convenience, not a certified
; converter - IEEE-754 has corners this doesn't attempt:
;   - Subnormal IEEE values (exponent field 0, nonzero mantissa) -
;     these represent magnitudes far below anything this format's
;     exponent range needs to distinguish for practical purposes;
;     FP_FROM_IEEE754_PROC treats them as (signed) zero rather than
;     attempt a lossy reconstruction nobody asked for.
;   - IEEE Infinity and NaN (exponent field all 1s) have no Woz
;     representation at all. FP_FROM_IEEE754_PROC traps via
;     FP_ERROR (error code 4 - see library_fp_error.s) rather
;     than silently invent a finite value or corrupt FP1.
;   - Values at the very edge of either format's exponent range may
;     not round-trip exactly (Woz's usable range is roughly
;     2^-128..2^127; IEEE-754 normalized range is roughly
;     2^-126..(just under 2^128)) - close enough that this rarely
;     matters, but not identical.
;
; BYTE ORDER
; ----------
; Output is big-endian (byte 0 = sign + high exponent bits, byte 3
; = mantissa LSB) - the natural order for describing IEEE-754 bit
; layout, and it matches Woz's own byte order (most significant
; byte first) rather than introducing a second convention. Systems
; that expect little-endian IEEE floats (most x86 tooling reading a
; raw four-byte block, for instance) need the 4 bytes reversed -
; trivial for the caller to do when moving the bytes elsewhere,
; not built in here.
;
; THE -1.0-STYLE BOUNDARY CASE (WHY THIS USES FP_NEGATE, NOT A
; HAND-ROLLED 2'S COMPLEMENT)
; -----------------------------------------------------------------
; Negating a Woz mantissa that sits exactly at the positive
; boundary (magnitude an exact power of 2, like 1.0, 2.0, 0.5...)
; produces a bit pattern that isn't itself normalized and needs an
; extra shift-and-decrement-exponent step to become valid again -
; discovered and verified against the real NORM algorithm while
; building this file (see the conversation this was built in for
; the full derivation). FP_NEGATE (library_fp.s, backed by
; FP_CORE_PROC's already-tested fcompl/norm logic) already handles
; this correctly, so both conversions call it instead of
; re-implementing 2's complement negation from scratch here.
;
; DEPENDENCIES
; ------------
; Requires labels_fp.s, library_fp_error.s, library_fp.s (for
; FP_NEGATE) before this file.
;
; ROUTINE INVENTORY
; -------------------
;   FP_TO_IEEE754_PROC   - FP1 (Woz) -> FP1 (IEEE-754 single), in place
;   FP_FROM_IEEE754_PROC - FP1 (IEEE-754 single) -> FP1 (Woz), in place
; ============================================================

; ============================================================
; PROCEDURE : FP_TO_IEEE754_PROC
; Purpose : Convert FP1 from Woz format to IEEE-754 single
;           precision, in place.
; Entry   : FP1 holds a Woz-format value
; Exit    : FP1_EXP/FP1_MANT/FP1_MANT+1/FP1_MANT+2 now hold the
;           4 bytes of the equivalent IEEE-754 bit pattern,
;           big-endian (see file header)
; Destroys: A, X; FP2 is untouched
; ============================================================
.proc FP_TO_IEEE754_PROC
    lda FP1_EXP
    bne @nonzero
    lda FP1_MANT
    ora FP1_MANT+1
    ora FP1_MANT+2
    beq @done               ; canonical Woz zero -> already the
                            ; correct all-zero IEEE representation
@nonzero:
    lda #0
    sta ieee_sign
    lda FP1_MANT
    bpl @compute            ; already non-negative: use as-is
    inc ieee_sign
    jsr FP_NEGATE           ; get a properly normalized absolute
                            ; value - see the file header on why
                            ; this, not a hand-rolled negation
@compute:
    ; --- exponent: E_ieee = FP1_EXP - 1 (rebias 128 -> 127) ---
    lda FP1_EXP
    sec
    sbc #1
    lsr                            ; carry = E_ieee's bit 0 (spills into
                                     ; byte 1's top bit below); A =
                                     ; E_ieee >> 1 (byte 0's low 7 bits)
    sta ieee_exp_hi7
    lda #0
    adc #0                          ; capture that carry as a plain 0/1
    sta exp_lsb_flag

    ; --- shift the 3 mantissa bytes left by 1: discards the implicit
    ;     leading bit (always 1 after the sign handling above), makes
    ;     room for IEEE's 23-bit fraction field ---
    clc
    lda FP1_MANT+2
    asl
    sta shifted+2
    lda FP1_MANT+1
    rol
    sta shifted+1
    lda FP1_MANT
    rol
    sta shifted

    ; --- byte 0: sign | exponent's top 7 bits ---
    lda ieee_sign
    beq @sign_clear
    lda #$80
    ora ieee_exp_hi7
    jmp @store_byte0
@sign_clear:
    lda ieee_exp_hi7
@store_byte0:
    sta FP1_EXP

    ; --- byte 1: exponent's LSB | mantissa's top 7 bits (masking off
    ;     the discarded implicit bit) ---
    lda shifted
    and #$7f
    ldx exp_lsb_flag
    beq @store_byte1
    ora #$80
@store_byte1:
    sta FP1_MANT

    lda shifted+1
    sta FP1_MANT+1
    lda shifted+2
    sta FP1_MANT+2
@done:
    rts

ieee_sign:      .byte 0
ieee_exp_hi7:   .byte 0
exp_lsb_flag:   .byte 0
shifted:        .res 3,0
.endproc

; ============================================================
; PROCEDURE : FP_FROM_IEEE754_PROC
; Purpose : Convert FP1 from IEEE-754 single precision to Woz
;           format, in place.
; Entry   : FP1_EXP/FP1_MANT/FP1_MANT+1/FP1_MANT+2 hold 4 bytes of
;           an IEEE-754 bit pattern, big-endian (see file header)
; Exit    : FP1 holds the equivalent Woz-format value
; Destroys: A, X; FP2 is untouched
; Traps   : calls FP_ERROR with code 4 if the input's exponent
;           field is all 1s (Infinity or NaN - no Woz equivalent)
; ============================================================
.proc FP_FROM_IEEE754_PROC
    lda FP1_EXP
    and #$80
    sta ieee_sign                 ; keep as $80/$00, convenient below

    ; --- reconstruct the 8-bit IEEE exponent from byte 0's low 7 bits
    ;     and byte 1's top bit ---
    lda FP1_EXP
    and #$7f
    asl                             ; positions the 7 bits correctly;
                                      ; bit 0 starts at 0
    sta ieee_exp
    lda FP1_MANT
    bpl @exp_bit0_clear
    inc ieee_exp
@exp_bit0_clear:

    lda ieee_exp
    bne @exp_nonzero
    ; exponent field is 0: true zero, or a subnormal we don't
    ; reconstruct (see the file header) - both become Woz zero
    lda #0
    sta FP1_EXP
    sta FP1_MANT
    sta FP1_MANT+1
    sta FP1_MANT+2
    rts
@exp_nonzero:
    cmp #$ff
    bne @exp_normal

    ; --- Exponent is $FF. Differentiate Infinity vs NaN ---
    ; In IEEE format, the mantissa spans the low 7 bits of byte 1 (FP1_MANT),
    ; plus all 8 bits of byte 2 (FP1_MANT+1) and byte 3 (FP1_MANT+2).
    ; We mask off the implicit bit/sign bit in byte 1 and check if any bits are set.

    lda FP1_MANT
    and #$7f
    ora FP1_MANT+1
    ora FP1_MANT+2
    bne @is_nan                     ; If any mantissa bits are 1, it is NaN

@is_inf:
    lda #4                          ; Infinity (Code 4)
    jmp FP_ERROR

@is_nan:
    lda #5                          ; NaN (Code 5)
    jmp FP_ERROR

@exp_normal:
    ; --- Woz exponent: E_woz = E_ieee + 1 ---
    lda ieee_exp
    clc
    adc #1
    sta FP1_EXP

    ; --- reconstruct the mantissa: shift IEEE's 23-bit fraction
    ;     (byte1 low 7 bits : byte2 : byte3) right by 1, then set
    ;     bit 22 - restoring the leading 1 IEEE leaves implicit but
    ;     Woz stores explicitly ---
    lda FP1_MANT
    and #$7f
    lsr
    sta tmp0
    lda FP1_MANT+1
    ror
    sta tmp1
    lda FP1_MANT+2
    ror
    sta tmp2

    lda tmp0
    ora #$40                          ; restore the implicit leading 1
    sta FP1_MANT
    lda tmp1
    sta FP1_MANT+1
    lda tmp2
    sta FP1_MANT+2

    lda ieee_sign
    beq @done
    jsr FP_NEGATE                       ; see the file header on why
                                          ; this, not a hand-rolled
                                          ; negation
@done:
    rts

ieee_sign:  .byte 0
ieee_exp:   .byte 0
tmp0:       .byte 0
tmp1:       .byte 0
tmp2:       .byte 0
.endproc

; ------------------------------------------------------------
; Short public aliases, matching the rest of the library's
; FP_FADD-style naming (no _PROC suffix).
; ------------------------------------------------------------
FP_TO_IEEE754   = FP_TO_IEEE754_PROC
FP_FROM_IEEE754 = FP_FROM_IEEE754_PROC
