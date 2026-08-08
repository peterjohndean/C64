.include "labels_fp.s"

.export FP_TO_BASIC
.export FP_FROM_BASIC

.import FP_NEGATE
.import FP_ERROR

.segment "CODE"
; ============================================================
; FILE    : lib_fp_basic.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; Converts FP1 between this library's native Woz/Rankin format and
; the C64's own BASIC ROM floating point accumulator format (FAC) -
; a data-interchange boundary conversion, exactly like
; lib_fp_ieee754.s, but for a THIRD format instead of a second one.
; This lets a value this library computed (fast, Woz-format
; arithmetic) be handed to BASIC's own MOVFM/FOUT/PRINT machinery,
; or a BASIC variable's stored value be read back in - WITHOUT
; running any of THIS library's own arithmetic through BASIC's own
; (slower) FP routines, and without needing to understand BASIC's
; internal FAC1 zero-page bookkeeping to do it.
;
; MINIMAL MENTAL MODEL FIRST
; -------------------------------
; Both formats are "1 exponent byte + a normalized mantissa",
; excess-128 biased, and - this is the useful part - they overlap
; almost perfectly in what they represent. The whole conversion
; boils down to two small mechanical differences:
;   1. WHERE is the mantissa normalized to? Woz uses [1.0, 2.0);
;      BASIC's FAC uses [0.5, 1.0). That's exactly a factor of 2,
;      so the two exponents are always exactly 1 apart.
;   2. HOW is the sign stored? Woz keeps the mantissa in real 2's
;      complement (sign is baked into the bits, same trick as
;      integer arithmetic). BASIC's FAC instead stores the mantissa
;      as an UNSIGNED, normalized fraction with an always-1 leading
;      bit that is never actually written to memory (it doesn't
;      need to be - it's always 1) - and reuses that now-spare bit
;      POSITION to hold the sign instead. This is the exact same
;      "hidden bit" trick IEEE-754 uses (see lib_fp_ieee754.s's own
;      header) - BASIC's FAC and IEEE-754 both hide their leading
;      1; Woz is the odd one out here, storing it explicitly.
; Once those two facts are pinned down, converting is "shift the
; mantissa by a fixed number of bits and adjust the exponent by 1"
; - no polynomial, no iteration - the same flavour as
; lib_fp_deg_rad.s being "deliberately the simplest file in its
; family".
;
; WHICH BASIC FORMAT, EXACTLY - THE 5-BYTE PACKED FORM
; -----------------------------------------------------------------
; BASIC's live accumulator, FAC1, occupies 6 zero-page bytes
; ($61-$66: exponent, 4 mantissa bytes, then a SEPARATE FACSGN sign
; byte - see labels_fp.s's own ZERO PAGE MAP note on why THIS
; library's FP1 deliberately reuses that same $61-$65 span). This
; file does NOT target that 6-byte live layout, on purpose: the
; exact relationship between FACSGN and the "live" mantissa's own
; top bit while a value is actually sitting in FAC1 is BASIC-ROM-
; internal bookkeeping this project hasn't independently verified
; against hardware. Instead, this file targets the plain 5-byte
; PACKED format - exponent + 4 mantissa bytes, sign folded directly
; into mantissa byte 1's top bit, no separate sign byte at all -
; because that packed format is EXACTLY what two already-documented
; BASIC ROM routines read and write directly (see labels_rom_basic.s):
;
;   $BBA2  MOVFM  "Load FAC#1 From Memory"   (packed 5 bytes -> FAC1)
;   $BBC7  MOV2F  "Store FAC#1 in Memory"    (FAC1 -> packed 5 bytes)
;
; So a buffer built by FP_TO_BASIC_PROC can be hunt straight at
; MOVFM (see the USAGE EXAMPLE below) with zero further translation,
; and a buffer built by MOV2F can be fed straight into
; FP_FROM_BASIC_PROC the same way. This also happens to be the
; format BASIC uses for a numeric constant embedded in a tokenised
; program line, and for a simple variable's stored value - i.e. the
; format you'd actually find if you PEEKed one.
;
; THE MATH (derivation once, in decimal, before any code)
; -------------------------------------------------------------
; Woz (positive case): value = (1 + f_w/2^22) * 2^(Ew-128), where
;   f_w is the 22-bit EXPLICIT fraction stored below Woz's own
;   explicit leading-1 bit (see labels_fp.s's bit diagram).
; BASIC FAC (positive case): value = (1 + F_b/2^31) * 2^(Eb-129),
;   where F_b is the 31-bit explicit fraction stored below BASIC's
;   HIDDEN leading-1 bit (see the MINIMAL MENTAL MODEL note above).
; Equating the two for the same value and matching the "(1+.../2^n)"
; parts against each other term by term (this only works because
; both formats normalize their mantissa to represent the SAME
; family of values, 1.xxxx times a power of 2 - just with a
; different explicit/hidden split for that leading 1):
;   Eb - 129 = Ew - 128        =>   Eb = Ew + 1
;   F_b / 2^31 = f_w / 2^22    =>   F_b = f_w << 9
; Both routines below are just these two lines, expressed as 6510
; instructions - an exponent +/-1 and a 9-bit mantissa shift.
;
; WHY SHIFT BY EXACTLY 9, AND WHERE THE "HIDDEN BIT" FITS IN
; -----------------------------------------------------------------
; f_w (22 bits) shifted left 9 gives 31 bits - filling BASIC's
; ENTIRE explicit fraction field exactly, with the low 9 bits
; always zero going Woz->Basic (this direction never loses
; precision - there's nothing in those low 9 bits to lose). Going
; Basic->Woz, those same low 9 bits (whatever BASIC actually had in
; them) are simply dropped - BASIC's mantissa is genuinely finer-
; grained (31 explicit bits) than Woz's (22 explicit bits), the
; same one-way-lossy relationship lib_fp_ieee754.s documents for
; IEEE-754 (which has ONE more explicit bit than Woz); here the gap
; is nine bits instead of one, but the shape of the problem, and
; the decision to just document it rather than treat it as an
; error, is identical.
;
; The cleanest implementation turns out to be: shift Woz's FULL
; 24-bit mantissa BYTE PATTERN (including Woz's own explicit
; leading-1 bit, not just f_w alone) left by 9 as one unit. Doing
; it this way conveniently lands the leading-1 bit exactly where
; BASIC's hidden bit would be (bit 31 of a 32-bit scratch buffer) -
; so the SAME shift produces "F_b in the low 31 bits, redundant
; leading-1 in bit 31" in one pass. Converting to BASIC's actual
; on-disk format is then just: mask that redundant bit 31 off (it's
; not stored) and OR the real sign into its place instead - this
; IS the hidden-bit trick, applied at the exact point of writing to
; memory. Going the other direction reverses this precisely:
; restore a 1 into that bit position (undoing the mask), then shift
; right by 9.
;
; WORKED EXAMPLE: 1.0, HAND-VERIFIED AGAINST A KNOWN BASIC CONSTANT
; -----------------------------------------------------------------
; Woz 1.0 = exponent $80, mantissa $40,$00,$00 (this exact byte
; pattern is independently confirmed elsewhere in this codebase -
; see lib_fp_ceil.s's neg_one_const comment).
; BASIC 1.0 is a widely published constant: $81,$00,$00,$00,$00
; (exponent, then 4 packed mantissa bytes) - used here as a known-
; correct check on this file's derivation rather than trusted
; blindly:
;   exponent: Ew+1 = $80+1 = $81                              match
;   mantissa: Woz's 24-bit pattern $400000, shifted left 9 bits
;             = $80000000. Bit 31 (the redundant leading-1) masked
;             off and OR'd with sign=$00 gives byte1 = $00, and the
;             remaining 3 bytes are $00,$00,$00                match
; Both fields check out exactly. -1.0 was also hand-checked (Woz
; -1.0 = exponent $7F, mantissa $80,$00,$00 - see lib_fp_ceil.s's
; own note on why this ISN'T the naive 2's complement of +1.0's
; bytes) and correctly round-trips through FP_NEGATE's boundary-
; case renormalization to produce BASIC $81,$80,$00,$00,$00.
;
; ERROR HANDLING
; -----------------
; FP_TO_BASIC_PROC: BASIC's exponent is Woz's plus 1, which can
; overflow a byte if Woz's own exponent is already $FF (the top of
; its own range) - that traps via FP_ERROR, generic overflow (code
; 0), exactly like every other exponent overflow in this library.
; FP_FROM_BASIC_PROC: never traps. A BASIC exponent of $00 always
; means "the value is zero" in BASIC's own convention (same
; convention this library uses for Woz - see lib_fp_compare.s's
; note on canonical zero); a BASIC exponent of $01 would decode to
; a Woz exponent of $00, which THIS library's own zero convention
; would then misread as "zero" even though the true value is a
; genuine (if minuscule) nonzero number. Rather than let that
; collision silently corrupt a real value into an incorrect zero,
; both cases (Eb=0 and Eb=1) are treated the same way: a clean,
; deliberate underflow to Woz 0.0 - the same "silently return 0.0
; rather than trap" convention this library already uses for
; FP_EXP_PROC's own underflow case (see lib_fp_exp.s).
;
; ZERO PAGE: REUSES FP_STRPTR ($FB/$FC)
; -------------------------------------------
; Both routines below need a zero-page pointer for (ptr),y indirect-
; indexed addressing against the caller's buffer - the SAME
; constraint FP_TO_ASCII_PROC/FP_FROM_ASCII_PROC already have (see
; labels_fp.s). Rather than reserve yet another zero-page pair,
; this file reuses FP_STRPTR, under the exact same transient-use
; caveat labels_fp.s already documents for it: don't call either of
; these routines from the middle of an in-flight
; FP_TO_ASCII_PROC/FP_FROM_ASCII_PROC/FP_TO_ASCII24_PROC/
; FP_FROM_ASCII24_PROC call, or an in-flight
; REU_ALIASING_DETECT_PROC/REU_DETECT_SIZE_PROC call - all of these
; borrow the same two bytes only for the instant of an indirect
; access, never held across a JSR out to other code, so none of
; them collide in practice as long as they aren't literally nested
; inside one another.
;
; USAGE EXAMPLE: HANDING A VALUE TO BASIC'S OWN MOVMF - AND THE
; FP_CLEANUP_FAC1FAC2 STEP THAT'S EASY TO FORGET
; -----------------------------------------------------------------
; This project's own labels_rom_basic.s already names the routine
; you want here as BASIC_MOVMF ($BBA2 - "Unpack Memory (Y/A) ->
; FAC1"), and BASIC_FOUT ($BDDD - "FAC1 -> ASCII string at Y/A,
; ready for STROUT"):
;
;     ; FP1 already holds a Woz value this library computed...
;     lda #<scratch5
;     ldy #>scratch5
;     jsr FP_TO_BASIC          ; scratch5 = packed 5-byte BASIC form
;     jsr FP_CLEANUP_FAC1FAC2  ; MUST come before any BASIC ROM FP
;                              ; call - see the caution below, this
;                              ; step is NOT optional
;     lda #<scratch5
;     ldy #>scratch5
;     jsr BASIC_MOVMF          ; FAC1 now holds the same value,
;                              ; BASIC-native
;     jsr BASIC_FOUT           ; convert FAC1 -> ASCII, ready for...
;     jsr BASIC_STROUT         ; ...printing it
;     ...
;     scratch5: .res 5,0
;
; IMPORTANT - THIS IS NOT OPTIONAL, AND GETTING IT WRONG PRODUCES A
; SUBTLY WRONG NUMBER, NOT A CRASH
; -----------------------------------------------------------------
; The FP_CLEANUP_FAC1FAC2 call above is required, and skipping it
; was a real bug caught while first exercising this file against
; actual BASIC ROM output (FP_TO_BASIC(-5.0) round-tripped through
; BASIC_MOVMF/BASIC_FOUT printed "-5.00921102" instead of "-5"
; without it). The mechanism: BASIC_MOVMF only rewrites $61-$66
; (FACEXP, FACHO's 4 mantissa bytes, and FACSGN) from the 5 packed
; bytes you hand it - it does NOT touch $67 (SGNFLG) or $68 (BITS),
; and this library's OWN FP_EXT scratch ($65-$68, used internally
; by FP_FADD/FP_FSUB's alignment-shift trampoline - see
; labels_fp.s's FP_EXT note) overlaps EXACTLY those bytes. Run
; enough of this library's own arithmetic before converting a value
; (which, in any real program, you will have) and $67/$68 can be
; left holding genuine leftover garbage from a completely unrelated
; earlier FADD/FSUB call - garbage that BASIC's own FOUT then reads
; as if it were meaningful FAC1 state, producing a plausible-looking
; but WRONG result rather than a crash or an obviously-broken one.
; This is exactly the failure mode lib_fp_cleanupfac1fac2.s's own
; header already warns about in general terms ("Leaving stale bytes
; there... can make BASIC commands run immediately afterward behave
; oddly") - this file just supplies a concrete, hardware-confirmed
; example of it actually happening. FP_CLEANUP_FAC1FAC2 zeroes the
; complete $61-$70 span BASIC's own FAC1 uses (not just the 6 bytes
; MOVMF itself touches), which is why it - and not a narrower fix -
; is the correct call here.
;
; VERIFICATION STATUS
; -----------------------
; All twelve tests in tr_basicfac.s (T00-T11) now pass, including
; both real-ROM round trips (T10: -5.0 through BASIC_MOVMF ->
; BASIC_FOUT -> "-5"; T11: 0.5 through the same path -> " .5",
; confirming both the leading-space-for-sign and no-leading-zero-
; below-1.0 formatting conventions this file had only guessed at
; until they were actually run). That real-ROM path is what caught
; the FP_CLEANUP_FAC1FAC2 omission in the first place: the very
; first attempt at T10, missing that call, printed "-5.00921102"
; instead of "-5" - a small, plausible-looking, WRONG value, not an
; obvious crash - see the IMPORTANT paragraph above for the exact
; mechanism. The lesson generalises and is worth restating plainly:
; this file's own conversion math checks out and always did, but it
; produces raw bytes only - it says nothing about what state the
; rest of BASIC's FAC1 workspace is in when those bytes get
; consumed by a real ROM call, and that state is controlled by
; whatever this library did BEFORE this file ever runs, not by this
; file itself. FP_CLEANUP_FAC1FAC2 before any BASIC ROM FP call is
; not a defensive nicety here - it is load-bearing, demonstrated.
;
; What's still open, now genuinely narrow:
;   1. T10/T11 between them cover an integer and a fraction, one
;      negative and one positive, through the real ROM path - a
;      LARGE magnitude (near the 8,388,607-ish ceiling this
;      library's own FP_TO_ASCII24_PROC documents) hasn't been
;      exercised that way yet, and is the most likely remaining
;      spot for a real-ROM-specific surprise given how much of this
;      file's derivation assumes "well-behaved, mid-range" values.
;   2. Everything else - the exponent math, the 9-bit shift, the
;      hidden-bit mask/restore, the Eb=0/Eb=1 underflow collision,
;      the Ew=$FF overflow trap - is now confirmed, not just hand-
;      derived. See tr_basicfac.s's own header for the full T00-T11
;      inventory.
;
; DEPENDENCIES
; ------------
; Requires labels_fp.s, library_fp_error.s, library_fp.s (for
; FP_NEGATE) before this file.
;
; ROUTINE INVENTORY
; -------------------
;   FP_TO_BASIC_PROC   - FP1 (Woz) -> 5-byte packed BASIC FAC buffer
;   FP_FROM_BASIC_PROC - 5-byte packed BASIC FAC buffer -> FP1 (Woz)
; ============================================================

; ============================================================
; PROCEDURE : FP_TO_BASIC_PROC
; Purpose : Convert FP1 from Woz format to a 5-byte packed BASIC
;           FAC buffer (see file header for the exact layout, and
;           why 5 bytes and not FAC1's own 6-byte zero-page shape).
; Entry   : FP1 holds a Woz-format value
;           A = destination buffer address low byte
;           Y = destination buffer address high byte
; Exit    : buffer+0     = BASIC exponent
;           buffer+1..+4 = BASIC mantissa, MSB first, sign folded
;                          into buffer+1's top bit (see file header)
; Destroys: A, X, Y; FP1 (used as working storage - back it up
;           first with FP_STORE1_MACRO if you still need it after);
;           FP_STRPTR ($FB/$FC, transient - see file header)
; Traps   : generic overflow (code 0) if FP1's own exponent is
;           already $FF - see file header ERROR HANDLING note
; ============================================================
.proc FP_TO_BASIC_PROC
    sta FP_STRPTR
    sty FP_STRPTR+1

    lda FP1_EXP
    bne @nonzero
    ; canonical Woz zero -> canonical BASIC zero. BASIC treats
    ; exponent 0 as "value is zero" regardless of what the mantissa
    ; bytes hold, so zeroing the whole 5-byte buffer is the
    ; simplest unambiguous choice (matches FP_TO_IEEE754_PROC's own
    ; handling of the equivalent case).
    ldy #4
    lda #0
@zero_loop:
    sta (FP_STRPTR),y
    dey
    bpl @zero_loop
    rts

@nonzero:
    lda #0
    sta basic_sign
    lda FP1_MANT
    bpl @compute
    lda #$80
    sta basic_sign
    jsr FP_NEGATE        ; get a properly normalized POSITIVE
                          ; magnitude before doing any of the bit
                          ; arithmetic below - see lib_fp_ieee754.s's
                          ; own header for why this, and not a
                          ; hand-rolled 2's complement, is used (the
                          ; exact-power-of-2 boundary case needs
                          ; FP_NORM's renormalization, which
                          ; FP_NEGATE already includes - this is
                          ; exactly the -1.0 case hand-checked in
                          ; the file header's WORKED EXAMPLE)
@compute:
    ; --- exponent: Eb = Ew + 1 - read Ew AFTER FP_NEGATE above,
    ;     since a boundary-case renormalization can itself change
    ;     FP1_EXP (see the note just above) ---
    lda FP1_EXP
    cmp #$ff
    bne @exp_ok
    lda #0                   ; [ERROR HANDLING] Ew=$FF -> Ew+1 would
    jmp FP_ERROR              ; wrap a byte to $00, which BASIC would
                               ; then misread as "value is zero" -
                               ; genuine overflow, error code 0
@exp_ok:
    clc
    adc #1
    ldy #0
    sta (FP_STRPTR),y          ; buffer+0 = BASIC exponent

    ; --- mantissa: shift Woz's 24-bit mantissa (INCLUDING its own
    ;     explicit leading-1 bit) left by 9 bits into a 32-bit
    ;     scratch buffer - see the file header's WHY SHIFT BY 9
    ;     note for why this single shift also happens to land the
    ;     leading-1 bit exactly where it needs to be masked off ---
    lda FP1_MANT
    sta shiftbuf
    lda FP1_MANT+1
    sta shiftbuf+1
    lda FP1_MANT+2
    sta shiftbuf+2
    lda #0
    sta shiftbuf+3            ; shiftbuf = woz_mantissa, byte-
                              ; aligned one position up (equivalent
                              ; to <<8 - just placement, no
                              ; shifting yet)

    clc                        ; one more bit of shift needed to
                              ; reach <<9 total - a plain 4-byte
                              ; left shift, LSB byte FIRST so carry
                              ; propagates correctly up through the
                              ; more significant bytes
    rol shiftbuf+3
    rol shiftbuf+2
    rol shiftbuf+1
    rol shiftbuf               ; the bit that rolls OUT of shiftbuf
                              ; here is Woz's own sign bit - always
                              ; 0 at this point (FP1 was forced
                              ; positive above) - so discarding it
                              ; is safe

    ; --- write the mantissa out, masking off the redundant
    ;     leading-1 bit (shiftbuf's bit 7) and OR-ing in the real
    ;     sign in its place - this IS the "hidden bit" trick,
    ;     applied at the point of writing to memory ---
    ldy #1
    lda shiftbuf
    and #$7f
    ora basic_sign
    sta (FP_STRPTR),y
    iny
    lda shiftbuf+1
    sta (FP_STRPTR),y
    iny
    lda shiftbuf+2
    sta (FP_STRPTR),y
    iny
    lda shiftbuf+3
    sta (FP_STRPTR),y          ; buffer+1..+4 = BASIC mantissa
    rts

basic_sign:  .byte 0
shiftbuf:    .res 4,0
.endproc

; ============================================================
; PROCEDURE : FP_FROM_BASIC_PROC
; Purpose : Convert a 5-byte packed BASIC FAC buffer (see file
;           header for the exact layout) into FP1, Woz format.
; Entry   : A = source buffer address low byte
;           Y = source buffer address high byte
; Exit    : FP1 = the equivalent Woz-format value
; Destroys: A, X, Y; FP2 is untouched; FP_STRPTR ($FB/$FC,
;           transient - see file header)
; Traps   : none - see file header ERROR HANDLING note for how the
;           Eb=0 and Eb=1 cases are both handled as a clean
;           underflow to 0.0 instead
; ============================================================
.proc FP_FROM_BASIC_PROC
    sta FP_STRPTR
    sty FP_STRPTR+1

    ldy #0
    lda (FP_STRPTR),y          ; buffer+0 = BASIC exponent
    cmp #2
    bcs @nonzero               ; Eb >= 2: a genuine, safely-
                               ; decodable nonzero value - see below
    ; Eb = 0 (BASIC's own canonical zero) OR Eb = 1 (would decode to
    ; a Woz exponent of 0, which collides with WOZ's OWN canonical-
    ; zero encoding) - both handled identically: a clean underflow
    ; to Woz 0.0, exactly the convention FP_EXP_PROC already uses
    ; for its own underflow case (see the file header ERROR
    ; HANDLING note for the full reasoning)
    lda #0
    sta FP1_EXP
    sta FP1_MANT
    sta FP1_MANT+1
    sta FP1_MANT+2
    rts

@nonzero:
    sec
    sbc #1
    sta FP1_EXP                 ; Ew = Eb - 1

    ; --- mantissa: restore the hidden leading-1 bit BASIC never
    ;     actually stores, then shift right by 9 to undo the <<9
    ;     from FP_TO_BASIC_PROC - see the file header for why this
    ;     necessarily drops BASIC's low 9 fraction bits (a real,
    ;     documented precision loss, not a bug) ---
    ldy #1
    lda (FP_STRPTR),y
    sta sign_byte                ; keep an UNMODIFIED copy to read
                                 ; the sign from below - the next
                                 ; three lines are about to mask
                                 ; this same bit for a different
                                 ; purpose (restoring the hidden
                                 ; magnitude bit), so the sign has
                                 ; to be captured first
    and #$7f
    ora #$80                     ; restore the implicit leading-1
                                 ; bit BASIC never actually stores
    sta shiftbuf
    iny
    lda (FP_STRPTR),y
    sta shiftbuf+1
    iny
    lda (FP_STRPTR),y
    sta shiftbuf+2                ; buffer+4 (the mantissa's LSB
                                 ; byte) is deliberately never read
                                 ; here - see the file header: it
                                 ; falls entirely within the low 9
                                 ; bits this direction discards

    lsr shiftbuf                  ; logical right shift, MSB byte
    ror shiftbuf+1                ; FIRST so the carry chain flows
    ror shiftbuf+2                ; correctly down through the less
                                 ; significant bytes - one more bit
                                 ; than the byte-aligned >>8 that
                                 ; "starting one byte late" already
                                 ; gave us, for >>9 total

    lda shiftbuf
    sta FP1_MANT
    lda shiftbuf+1
    sta FP1_MANT+1
    lda shiftbuf+2
    sta FP1_MANT+2                ; FP1 now holds the correctly
                                 ; normalized POSITIVE magnitude -
                                 ; see the file header WORKED
                                 ; EXAMPLE for a hand-checked
                                 ; confirmation of this exact bit
                                 ; arithmetic

    lda sign_byte
    bpl @done                     ; positive: nothing further to do
    jsr FP_NEGATE                  ; negative: negate the positive
                                  ; magnitude just constructed -
                                  ; same "don't hand-roll 2's
                                  ; complement" reasoning as
                                  ; FP_TO_BASIC_PROC above
@done:
    rts

sign_byte: .byte 0
shiftbuf:  .res 4,0
.endproc

; ------------------------------------------------------------
; Short public aliases, matching the rest of the library's
; FP_FADD-style naming (no _PROC suffix).
; ------------------------------------------------------------
FP_TO_BASIC   = FP_TO_BASIC_PROC
FP_FROM_BASIC = FP_FROM_BASIC_PROC
