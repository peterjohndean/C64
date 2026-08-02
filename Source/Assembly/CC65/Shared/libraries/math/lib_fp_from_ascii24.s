.include "macros_fp.s"

.export FP_FROM_ASCII24
.import FP_FADD, FP_FMUL, FP_FDIV
.import FP_NEGATE, FP_NORM, FP_FLOAT

FP_FROM_ASCII24 = FP_FROM_ASCII24_PROC

.segment "CODE"
; ============================================================
; PROCEDURE : FP_FROM_ASCII24_PROC
; Purpose : Same job as FP_FROM_ASCII_PROC (parse a null-terminated
;           decimal string into FP1 via Horner's method), but
;           avoids a precision trap FP_FROM_ASCII_PROC has for
;           inputs with a large combined digit count (integer
;           digits + fractional digits together).
; Entry   : A = string address low byte, Y = string address high byte
; Exit    : FP1 = parsed value. Carry clear if at least one digit
;           was found; carry set (FP1 left at 0.0) if the string
;           contained none.
; Destroys: A, X, Y; FP1, FP2
;
; WHEN TO USE THIS VS FP_FROM_ASCII_PROC
; -----------------------------------------
; Use FP_FROM_ASCII24_PROC when the string being parsed can have a
; decimal point AND the integer part can run past about 5-6 digits.
; Use plain FP_FROM_ASCII_PROC when the input is integer-only (no
; decimal point at all - this case never hits the bug either
; routine cares about), or when you already know, for this specific
; call site, that integer digits + fractional digits together will
; always stay small (roughly 7 or fewer combined). In that small-
; combined-digit regime the two routines behave identically, so
; there's no reason to change an existing, already-tested call site.
; For NEW call sites where you're not sure, prefer
; FP_FROM_ASCII24_PROC - it has no known downside relative to
; FP_FROM_ASCII_PROC (same result whenever the old one was already
; correct) and fixes a real, confirmed-on-hardware bug whenever the
; old one wasn't. See T59/T60 in fp_tests.s for the confirmed
; failure case (FP_FROM_ASCII_PROC turned "1234567.25" into
; "1234566.50" - wrong in BOTH the integer part and the fraction).
;
; NEITHER ROUTINE INCREASES THE FORMAT'S PRECISION
; ---------------------------------------------------
; This is the part that's easy to misread as "still buggy": once
; the integer part alone uses close to all 23 of the format's
; mantissa bits, there are only a couple of bits left for the
; fraction, REGARDLESS of which parser is used. At 1234567's
; magnitude (21 of 23 bits), only 2 fractional bits remain - just
; enough for .00/.25/.50/.75 exactly; anything else silently floors
; to the nearest one of those four during the parse-time FP_FADD
; combine (FP_FADD truncates rather than rounds - see WHAT THIS
; DOES NOT FIX below). That's a hard limit of a 4-byte float at that
; magnitude, not something either ASCII routine can work around.
; What FP_FROM_ASCII24_PROC actually fixes is a DIFFERENT, much
; larger problem: FP_FROM_ASCII_PROC's old bug could corrupt the
; INTEGER part too (see the confirmed example above), and by an
; unpredictable amount, not a small bounded one. FP_FROM_ASCII24_PROC
; guarantees the integer part is always exact and any fractional
; loss is bounded and predictable (always floors to the nearest
; representable increment for that magnitude) - see the worked
; precision-budget table in lib_fp_to_ascii24.s's WHEN TO USE note.
;
; WHY A SEPARATE ROUTINE INSTEAD OF FIXING FP_FROM_ASCII_PROC IN PLACE
; ----------------------------------------------------------------------
; FP_FROM_ASCII_PROC accumulates every digit - integer AND fractional
; - into ONE running Horner's-method total, then divides that whole
; total back down by 10 once per fractional digit at the end. For
; "1234567.25" that means the UNSCALED intermediate is 123456725 -
; and that value must itself fit exactly in this format's ~23-bit
; mantissa (1 implicit + 22 explicit fraction bits - see T56's header
; comment in fp_tests.s for how that ceiling was established), even
; though the FINAL value (1234567.25) only needs 23 bits and would
; fit on its own just fine. 123456725 needs 27 bits - so it silently
; rounds to the nearest representable float BEFORE the divide-back-
; down step ever runs, corrupting both the integer and fractional
; digits of the result. Confirmed against real hardware/VICE output:
; parsing "1234567.25" this way produced 1234566.50, not 1234567.25.
;
; FP_FROM_ASCII24_PROC fixes this by keeping the integer part and the
; fractional part as two SEPARATE accumulations from the start:
;   1. Integer digits accumulate via Horner's method exactly as
;      FP_FROM_ASCII_PROC already does, but stop at the decimal
;      point instead of continuing through it. The result is stashed
;      in int_part the moment the point (or the end of the number)
;      is reached.
;   2. Fractional digits accumulate via their OWN, independent
;      Horner's-method total, starting fresh from 0.0. In practice
;      this total is usually only 1-3 digits, so its own unscaled
;      intermediate stays small and safely in range even when the
;      integer part is large. That small total is then divided by 10
;      once per fractional digit - exactly the technique
;      FP_FROM_ASCII_PROC already uses, just scoped to the fraction
;      alone instead of the whole number.
;   3. The two parts are FADDed together at the end (int_part is
;      skipped entirely, via FP_LOAD1_MACRO instead of an FADD, when
;      there were no fractional digits at all - adding a redundant
;      0.0 would be harmless, but this avoids it directly).
; This lets a value like 1234567.25 - whose own FINAL 23-bit form is
; exactly representable - parse exactly, because neither accumulator
; is ever asked to briefly hold more precision than the format has.
;
; WHAT THIS DOES NOT FIX
; -----------------------
; This does NOT raise the format's precision ceiling - a value whose
; own final form needs more than ~23 mantissa bits will still round,
; exactly as it would with any single-precision-class float. What
; this section used to claim - that FP_FADD's alignment shift loses
; a fractional addend once the integer part leaves it no spare bit -
; turned out to be WRONG on real-hardware testing: for T59's own
; case (1234567.0 + 0.25, zero bits of theoretical spare room),
; FP_FADD was independently verified, via VICE breakpoints on the
; actual register contents, to produce exactly 1234567.25 - no loss
; at all. The precision loss T59 originally exposed was real, but it
; happens downstream, in FP_TO_ASCII24_PROC's OWN fractional-
; remainder extraction (previously an FP_NORM+FP_FSUB reconstruction,
; now replaced with a direct bit-mask - see that file's FRACTIONAL
; EXTRACTION note), not in this routine's FP_FADD combine step. This
; routine's split-accumulator design is fully exact wherever
; FP_FADD itself is exact, which real-hardware testing now confirms
; includes cases this note previously - incorrectly - ruled out.
;
; FP_FROM_ASCII_PROC is left completely unchanged - existing call
; sites keep their exact previous behaviour (including whatever
; precision characteristics they already depend on) - this routine
; coexists as the precision-safe alternative for callers parsing
; values with large integer parts, mirroring how FP_TO_ASCII24_PROC
; already coexists alongside FP_TO_ASCII_PROC on the output side.
; ============================================================
.proc FP_FROM_ASCII24_PROC
    sta FP_STRPTR
    sty FP_STRPTR+1
    lda #0
    sta FP1_EXP
    sta FP1_MANT
    sta FP1_MANT+1
    sta FP1_MANT+2                  ; FP1 = 0.0 (integer-part accumulator)
    sta is_negative
    sta point_seen
    sta frac_digits
    sta saw_digit
    sta scan_pos                    ; string position lives in memory, not Y -
                                    ; same reason as FP_FROM_ASCII_PROC: Y is
                                    ; clobbered by FMUL/FADD/FDIV inside
                                    ; @accumulate_digit, so it can't be trusted
                                    ; to survive across that call

    ldy #0
    lda (FP_STRPTR),y
    cmp #'-'
    bne @check_plus
    inc is_negative
    inc scan_pos
    jmp @int_loop
@check_plus:
    cmp #'+'
    bne @int_loop
    inc scan_pos

    ; ── PASS 1: integer digits ──────────────────────────────────
    ; Identical technique to FP_FROM_ASCII_PROC's own scan loop, but
    ; stops (rather than continuing through) the decimal point -
    ; this loop's total is the integer part ONLY.
@int_loop:
    ldy scan_pos
    lda (FP_STRPTR),y
    cmp #'.'
    beq @got_point
    cmp #'0'
    bcc @int_done                   ; below '0': not a digit, number's over
    cmp #'9'+1
    bcs @int_done                   ; above '9': not a digit, number's over
    inc saw_digit
    sec
    sbc #'0'                        ; A = digit value 0-9
    jsr @accumulate_digit
    inc scan_pos
    jmp @int_loop
@got_point:
    inc point_seen
    inc scan_pos
    ; falls through: integer part is done either way once we reach
    ; a point, a non-digit, or the end of the string
@int_done:
    FP_STORE1_MACRO int_part        ; stash the integer total - FP1 is about
                                    ; to be reused as a completely fresh,
                                    ; independent accumulator for the
                                    ; fraction digits. THIS split is the
                                    ; whole fix: the fraction's Horner total
                                    ; never sees the integer digits, so it
                                    ; never needs more precision than the
                                    ; fraction alone requires.

    lda point_seen
    bne @frac_reset
    jmp @no_fraction                ; no decimal point anywhere in the
                                    ; string: nothing left to parse

    ; ── PASS 2: fraction digits, own independent accumulator ────
@frac_reset:
    lda #0
    sta FP1_EXP
    sta FP1_MANT
    sta FP1_MANT+1
    sta FP1_MANT+2                  ; FP1 = 0.0 (fraction-only accumulator)
@frac_loop:
    ldy scan_pos
    lda (FP_STRPTR),y
    cmp #'0'
    bcc @frac_done
    cmp #'9'+1
    bcs @frac_done
    inc saw_digit
    sec
    sbc #'0'
    jsr @accumulate_digit
    inc frac_digits
    inc scan_pos
    jmp @frac_loop
@frac_done:
    lda frac_digits
    beq @no_fraction                 ; a bare trailing '.' with nothing
                                    ; after it (e.g. "42.") - int_part alone
                                    ; is the answer, same as FP_FROM_ASCII_PROC

    ; undo the fraction's own scale: divide ITS total by 10 once per
    ; fractional digit. Because this total only ever accumulated the
    ; fraction digits (never the integer digits too), it stayed small
    ; the whole time - this is the same technique FP_FROM_ASCII_PROC
    ; uses, just no longer asked to undo an oversized combined total.
@divide_loop:
    pha
    FP_COPY1TO2_MACRO                ; FP2 = running fraction total
    FP_LOAD1_MACRO ten_const         ; FP1 = 10.0
    jsr FP_FDIV                      ; FP1 = FP2 / FP1 = total / 10
    pla
    sec
    sbc #1
    bne @divide_loop
    ; FP1 now holds the fractional VALUE alone (e.g. 0.25)

    FP_LOAD2_MACRO int_part          ; FP2 = integer part
    jsr FP_FADD                      ; FP1 = integer part + fraction -
                                    ; verified exact on real hardware for
                                    ; T59's own value (1234567.25); that
                                    ; test's remaining failure happens
                                    ; later, in FP_TO_ASCII24_PROC's own
                                    ; printing path, not here
    jmp @apply_sign

@no_fraction:
    FP_LOAD1_MACRO int_part          ; FP1 = int_part exactly - no FADD
                                    ; needed (and none attempted: adding
                                    ; int_part to itself here would double
                                    ; it, since FP1 still held the integer
                                    ; total, not 0.0, at this point)

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
; Identical technique to FP_FROM_ASCII_PROC's own @accumulate_digit,
; reused here for BOTH passes. Safe because each pass's accumulator
; lives in FP1 only while ITS loop runs, and the two loops never
; overlap - pass 1 finishes completely (int_part is stashed away)
; before pass 2 ever begins.
@accumulate_digit:
    sta digit_tmp
    FP_LOAD2_MACRO ten_const         ; FP2 = 10.0
    jsr FP_FMUL                      ; FP1 = total * 10
    FP_STORE1_MACRO accum            ; stash total*10 - building the
                                    ; digit float needs FP1
    lda digit_tmp
    sta FP1_MANT+1                   ; digit as a 16-bit integer
    lda #0
    sta FP1_MANT
    jsr FP_FLOAT                     ; FP1 = float(digit)
    FP_COPY1TO2_MACRO                ; FP2 = float(digit)
    FP_LOAD1_MACRO accum             ; FP1 = total*10 (restored)
    jsr FP_FADD                      ; FP1 = total*10 + digit
    rts

accum:          .res 4,0
int_part:       .res 4,0
digit_tmp:      .byte 0
is_negative:    .byte 0
point_seen:     .byte 0
frac_digits:    .byte 0
saw_digit:      .byte 0
scan_pos:       .byte 0
ten_const:      .byte $83,$50,$00,$00   ; 10.0 - same constant bytes
                                        ; FP_FROM_ASCII_PROC uses; see
                                        ; library_fp_convert.s's header for
                                        ; how they're derived
.endproc
