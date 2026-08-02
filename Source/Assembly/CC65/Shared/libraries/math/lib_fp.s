.include "labels_fp.s"

.export FP_FADD, FP_FSUB, FP_FMUL, FP_FDIV
.export FP_FLOAT, FP_FIX, FP_SWAP, FP_NORM
.export FP_RTAR, FP_NEGATE

.import FP_ERROR

.segment "CODE"

; ============================================================
; FILE    : lib_fp.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; A ca65/cc65-tools port of the classic Rankin/Wozniak 6502 floating point
; package, "Floating Point Routines for the 6502", Dr. Dobb's
; Journal, August 1976 (https://6502.org/source/floats/wozfp1.txt).
; This is a SYNTAX AND ADDRESSING port, not a redesign: every
; routine below is the same algorithm, same instruction sequence,
; same fall-through/branch structure as the original 1976 listing.
; Only the assembler dialect (ca65 vs. the original's
; "=" immediate syntax and BSS directives) and the zero page
; addresses have changed.
;
; PROVENANCE / ERRATA
; ---------------------
; Roy Rankin published an errata for this package in the
; November/December 1976 issue of Dr. Dobb's Journal
; (https://6502.org/source/floats/wozfp2.txt). It corrects exactly
; one bug: FP_LOG_PROC's argument-range-reduction step always
; zero-extended the extracted power-of-2 exponent to 16 bits
; before calling FP_FLOAT, which is only correct when that
; exponent is positive (argument >= 1.0). For an argument < 1.0
; the exponent is negative and needs SIGN-extension ($FF in the
; high byte, not $00), or FP_FLOAT computes a wildly wrong huge
; positive "n" instead of the intended small negative one. This
; port includes Rankin's fix (see the `cont` label below, marked
; [ERRATA FIX]) - LOG/LOG10 of arguments below 1.0 will be wrong
; without it. No other routine in this package needed correction.
; wozfp3.txt (the Apple II ROM variant of this same package,
; https://6502.org/source/floats/wozfp3.txt) independently confirms
; the double-entry and alignment-trampoline mechanisms described
; below and was cross-checked against this port while applying the
; fix - it also has a materially different, rounding-aware FIX
; that the integer conversion helpers borrow from for FP_TO_INT8/16/24.
;
; DEPENDENCIES
; ------------
; Requires labels_fp.s to be included BEFORE this file. That file
; defines the zero page footprint (FP1_EXP/FP1_MANT/FP_EXT,
; FP2_EXP/FP2_MANT, FP_SIGN, FP_ERROR_SP/FP_ERROR_CODE) and
; explains WHY it reuses BASIC's FAC1/FAC2 addresses - read it
; first, especially the note that this is address reuse only, not
; FAC-format compatibility with BASIC's own floating point ROM
; routines (FP_CLEANUP_FAC1FAC2 below exists precisely because of
; that sharing).
;
; Also requires library_fp_error.s to be included BEFORE this file
; - the overflow/domain-error trap sites here call FP_ERROR by
; name, and macros_rom_basic.s/macros_rom_kernal.s for
; BASIC_STROUT_MACRO/KERNAL_CHROUT_MACRO, which FP_ERROR uses.
;
; NUMBER FORMAT
; --------------
; 4 bytes: 1 exponent byte (excess-128) + 3 mantissa bytes (2's
; complement, normalized to 1.0-2.0, binary point after bit 6 of
; the first mantissa byte). See labels_fp.s for the full layout
; diagram. This is a 24-bit mantissa (~7 significant decimal
; digits), one byte narrower than BASIC's own 32-bit FAC mantissa.
;
; A CAUTION ABOUT wozfp3.txt's WORKED EXAMPLES
; ------------------------------------------------
; wozfp3.txt's prose "Example:" sections for FSUB and FDIV appear
; to contain transcription errors - if you hand-check this port
; against those examples and the sign or a byte looks wrong, trust
; the derivation here over that prose. Specifically: its FSUB
; example's stated result (+12 from minuend +7 minus subtrahend -5)
; doesn't match what the actual instruction sequence computes
; (FCOMPL negates FP1 then falls into FADD's own code, giving
; FP2_entry - FP1_entry, i.e. -5-7=-12, not the documented +12);
; and its FDIV example's byte dump for -60 ($85 80 00 00) doesn't
; decode to -60 under this format (it decodes to -64), while its
; OWN separate FMUL example's byte dump for the same value -60
; ($85 88 00 00) decodes correctly. test_fp.s's expected values
; were derived directly from the disassembly and cross-checked
; against wozfp3's internally-consistent FADD/FMUL examples, not
; copied from its FSUB/FDIV prose.
;
; ROUTINE INVENTORY
; -------------------
;   FP_CORE_PROC (one indivisible .proc - see note below)
;     FP_FADD   - FP1 = FP1 + FP2
;     FP_FSUB   - FP1 = FP2 - FP1
;     FP_FMUL   - FP1 = FP1 * FP2
;     FP_FDIV   - FP1 = FP2 / FP1
;     FP_FLOAT  - FP1 = float(16-bit integer currently in FP1_MANT/+1)
;     FP_FIX    - FP1 = integer part of FP1 (result in FP1_MANT/+1)
;     FP_SWAP   - exchange FP1 and FP2 in place
;   FP_LOG_PROC   - FP1 = natural log(FP1), FP1 must be > 0
;   FP_LOG10_PROC - FP1 = log base 10(FP1), FP1 must be > 0
;   FP_EXP_PROC   - FP1 = e^FP1
;   FP_CLEANUP_FAC1FAC2 - zero the shared BASIC FAC1/FAC2 workspace;
;                          call before returning to BASIC
;
; WHY IS FP_CORE_PROC ONE GIANT .proc INSTEAD OF SEVEN .procs?
; ----------------------------------------------------------
; The project convention is one routine = one .proc for clean
; dead code elimination. That convention breaks down here: Woz's
; FADD/FSUB/FMUL/FDIV/FCOMPL/SWAP/NORM are not independent
; subroutines that happen to call each other with JSR/RTS - they
; are ONE interleaved block of code that shares tails via plain
; branches (BEQ/BNE/BCC/BCS/BPL/BMI) as well as calls, and in two
; places (see the "TRAMPOLINE" and "DOUBLE-ENTRY" notes below) a
; JSR is deliberately used to create a return address that lands
; back inside a DIFFERENT routine's fall-through path. Splitting
; these into separate .proc blocks would either break branch
; range (a .proc boundary is not a physical barrier in ca65,
; but reordering to make each piece independently droppable would
; force real gaps) or force duplicating the shared tail code,
; doubling the size of what is famously some of the tightest
; floating point code ever written for the 6502. So the whole
; "basic page" is kept as one block, exactly as it was one
; physical page ($1F00) in the original.
;
; It's declared with .block rather than .proc specifically
; because .proc's dead-code-elimination bookkeeping combined with
; this many interlinked branches (some near the +/-127 byte short-
; branch limit) and would obscure the deliberate fall-throughs.
; Keeping the core in one contiguous .proc mirrors the original
; page layout and avoids presenting tightly interdependent entry
; points as independent routines. FP_LOG_PROC, FP_LOG10_PROC and
; FP_EXP_PROC ARE independent of each other and of one another's
; private scratch space - each is only reached via JSR from
; outside and only reaches FP_CORE_PROC via JSR, so each stays a
; real .proc, at the cost of a few bytes of duplicated constant
; tables (documented at each duplication).
;
; TWO DELIBERATE CLEVER TRICKS WORTH UNDERSTANDING BEFORE YOU
; TOUCH THIS CODE
; ----------------------------------------------------------------
; 1. THE DOUBLE-ENTRY TRICK (md1/abswap/swap):
;    FP_FMUL and FP_FDIV both need the ABSOLUTE VALUE of BOTH
;    mantissas before they multiply/divide unsigned. Rather than
;    write that logic twice, `md1` calls `abswap` with a genuine
;    JSR, and `abswap` (after conditionally negating FP1's
;    mantissa) falls straight through into `swap` with NO RTS in
;    between. `swap`'s own RTS therefore returns to the address
;    JSR pushed - which is `abswap`'s OWN entry point - so the
;    same code runs a second time, this time examining what is
;    now sitting in FP1's slot (originally FP2's mantissa, moved
;    there by the first swap). The second pass's `swap` call
;    swaps the operands back into their original slots and its
;    RTS finally pops the frame `md1`'s caller (FP_FMUL/FP_FDIV)
;    is expecting. Net effect: one JSR md1 call processes BOTH
;    operands' signs and leaves both mantissas positive, for the
;    cost of a single extra JSR/RTS pair (12 cycles) instead of
;    writing the abs-and-swap logic out twice (see FP_SIGN in
;    labels_fp.s for where the running sign parity is kept).
;
; 2. THE ALIGNMENT TRAMPOLINE (fadd/swpalg/algnsw/rtar/rtlog):
;    Adding two floats with different exponents requires shifting
;    the smaller-exponent mantissa right, ONE BIT AT A TIME, until
;    the exponents match - and that shift can take up to 24
;    iterations. Rather than a dedicated loop counter, `fadd`
;    re-enters ITSELF: when exponents differ it branches to
;    `swpalg`, which does a genuine `jsr algnsw`; `algnsw` shifts
;    one bit (via `rtar`/`rtlog`/`rtlog1`) and its eventual `rts`
;    pops the address `jsr algnsw` pushed - which is `fadd`'s own
;    entry point - so `fadd` re-compares the (now closer) exponents
;    and loops back through `swpalg` again if they still differ.
;    Only when they finally match does execution fall through past
;    the exponent compare into the real addition. This costs a
;    JSR/RTS pair (12 cycles) per bit of alignment shift, in
;    exchange for not needing a separate iteration counter or a
;    second labelled loop - a real example of the "cycles vs. code
;    size vs. clarity" trade-off this project cares about. A
;    modernised version could replace the `jsr algnsw` / implicit
;    loop-back with a plain `jmp` back to the exponent compare,
;    saving the JSR/RTS overhead per shift at the cost of needing
;    an explicit loop label - noted here rather than done, to keep
;    this port behaviourally identical to the published original.
;
; ERROR / OVERFLOW HANDLING
; ---------------------------
; The original package has three trap points that were each just a
; bare BRK, on the assumption the caller had installed a BRK
; handler (this predates any notion of a portable error-return
; convention). This port replaces all three with calls into
; FP_ERROR (library_fp_error.s), which prints what went wrong
; and unwinds to a recovery point the caller establishes up front
; with FP_ERROR_INIT_MACRO (macros_fp.s) - see library_fp_error.s's
; header for the full setjmp/longjmp-style contract, the error code
; list, and why a single shared recovery point (rather than trying
; to unwind exactly one call level) is the right model here. The
; three trap sites are:
;   FP_CORE_PROC's fdiv/rtlog/ovchk - overflow in FADD/FSUB/FMUL/
;     FDIV/FIX, or division by zero (detected distinctly - see
;     library_fp_error.s)
;   FP_LOG_PROC's error_trap - LOG/LOG10 argument <= 0 (no real log)
;   FP_EXP_PROC's ovflw_trap - EXP argument too large, e^x overflows
; There is no trap for underflow - results that underflow are
; silently set to 0.0, exactly as documented in the original.
; REQUIRES library_fp_error.s TO BE ASSEMBLED BEFORE THIS FILE -
; see the dependency note below.
; ============================================================

; ============================================================
; FP_CORE_PROC
; Purpose : FP_FADD, FP_FSUB, FP_FMUL, FP_FDIV, FP_FLOAT, FP_FIX,
;           FP_SWAP - see the file header for why these seven
;           entry points live in one .proc instead of seven.
; ============================================================
.proc FP_CORE_PROC

; ------------------------------------------------------------
; add - FP1_MANT += FP2_MANT (3-byte mantissa add, LSB first)
; Entry : FP1_MANT, FP2_MANT hold the two mantissas to add
; Exit  : FP1_MANT = FP1_MANT + FP2_MANT, carry/overflow set
;         normally by the final ADC
; Destroys: A, X
; ------------------------------------------------------------
add:
    clc
    ldx #$02                ; index for 3-byte add, LSB first
add1:
    lda FP1_MANT,x
    adc FP2_MANT,x
    sta FP1_MANT,x
    dex                     ; advance to next more significant byte
    bpl add1
    rts

; ------------------------------------------------------------
; md1 / abswap / abswp1 - take the absolute value of BOTH
; mantissas and swap FP1<->FP2. See the file header's "DOUBLE-
; ENTRY TRICK" note - md1 has no RTS of its own; it relies on
; abswap being run twice via the JSR/fall-through/RTS pattern
; below, once for each operand.
; Entry : FP1/FP2 loaded with the two operands
; Exit  : both mantissas made non-negative, FP_SIGN's low bit
;         toggled once per negation (tracks overall sign parity
;         for FP_FMUL/FP_FDIV), FP1/FP2 restored to their
;         original slots, carry set
; Destroys: A, X, Y (Y is clobbered by the swap loop)
; ------------------------------------------------------------
md1:
    asl FP_SIGN             ; clear LSB of running sign flag
    jsr abswap              ; first pass: process FP1's mantissa
                            ; (falls through to swap, whose rts
                            ; re-enters abswap - see file header)
abswap:
    bit FP1_MANT            ; is FP1's mantissa negative?
    bpl abswp1              ; no: just fall through to swap
    jsr fcompl              ; yes: 2's-complement it
    inc FP_SIGN             ; and flip the running sign parity
abswp1:
    sec                     ; carry set for return to mul/div
    ; falls through into swap

; ------------------------------------------------------------
; swap - exchange FP1 (exponent + 3-byte mantissa) with FP2,
;        4 bytes total. Also used standalone (FP_SWAP) and as
;        the second half of the abswap double-entry trick above.
; Entry : FP1, FP2 loaded
; Exit  : FP1 and FP2 contents exchanged
; Destroys: A, X, Y
; ------------------------------------------------------------
swap:
    ldx #$04                ; index for 4-byte swap
swap1:
    sty FP_EXT-1,x          ; stash previous Y into scratch
    lda FP1_EXP-1,x
    ldy FP2_EXP-1,x
    sty FP1_EXP-1,x
    sta FP2_EXP-1,x
    dex                     ; advance index to next byte
    bne swap1               ; loop until done
    rts

; ------------------------------------------------------------
; float_conv (FP_FLOAT) - convert the 16-bit integer currently
; sitting in FP1_MANT/FP1_MANT+1 (high byte first) into a
; normalized float, left in FP1.
; Entry : FP1_MANT = integer high byte, FP1_MANT+1 = low byte
; Exit  : FP1 = normalized float equal to that integer
; Destroys: A
; ------------------------------------------------------------
float_conv:
    lda #$8e                ; provisional exponent = 2^14
    sta FP1_EXP
    lda #0
    sta FP1_MANT+2          ; clear the (unused-by-integer) LSB
    beq norm                ; always taken; enter shared normalizer
norm1:
    dec FP1_EXP             ; decrement exponent to compensate
    asl FP1_MANT+2
    rol FP1_MANT+1          ; shift the 3-byte mantissa left...
    rol FP1_MANT            ; ...one bit, carry cascades up
norm:
    lda FP1_MANT            ; high-order mantissa byte
    asl                     ; are the top two bits unequal?
    eor FP1_MANT
    bmi rts1                ; yes: mantissa is normalized, done
    lda FP1_EXP             ; exponent reached zero (underflow)?
    bne norm1               ; no: keep normalizing
rts1:
    rts

; ------------------------------------------------------------
; fsub (FP_FSUB) - FP1 = FP2 - FP1
; Entry : FP1, FP2 loaded with minuend/subtrahend per above
; Exit  : FP1 = FP2 - FP1, normalized
; Destroys: A, X, Y; FP2 left holding the addend of greater
;           magnitude (a side effect of sharing fadd's tail)
; ------------------------------------------------------------
fsub:
    jsr fcompl              ; negate FP1's mantissa (2's complement)
                            ; clears carry unless the result is zero
swpalg:
    jsr algnsw              ; align mantissas or swap - see below;
                            ; also the re-entry target of fadd's
                            ; alignment trampoline (file header)

; ------------------------------------------------------------
; fadd (FP_FADD) - FP1 = FP1 + FP2
; Entry : FP1, FP2 loaded with the two addends
; Exit  : FP1 = FP1 + FP2, normalized
; Destroys: A, X, Y
; Caution: per the original documentation, overflow can occur if
;          the sum is outside roughly +/-2^128; on overflow this
;          calls FP_ERROR (see the ERROR / OVERFLOW HANDLING
;          note in the file header).
; ------------------------------------------------------------
fadd:
    lda FP2_EXP
    cmp FP1_EXP             ; compare the two exponents
    bne swpalg              ; unequal: align mantissas (loops back
                            ; here via the trampoline until equal -
                            ; see file header)
    jsr add                 ; exponents equal: add aligned mantissas
addend:
    bvc norm                ; no overflow: normalize the result
    bvs rtlog               ; overflow: shift right one bit first
algnsw:
    bcc swap                ; carry clear (from fcompl): just swap
                            ; the operands rather than shift
rtar:
    lda FP1_MANT            ; sign of FP1's mantissa into carry...
    asl                     ; ...for a right ARITHMETIC shift
rtlog:
    inc FP1_EXP             ; bump exponent to compensate for the
                            ; one-bit right shift about to happen
    bne rtlog_ok            ; exponent didn't wrap: no overflow
    lda #0                  ; [ERROR HANDLING] exponent wrapped
    jmp FP_ERROR            ; past $FF: overflow (code 0) - see
                            ; lib_fp_error.s. Inlined here
                            ; rather than branching to a shared
                            ; distant label: this exact branch
                            ; sat at the very edge of the 8-bit
                            ; branch range even before this file
                            ; had an error handler (see the
                            ; FP_CORE_PROC .block note above) -
                            ; inlining removes the distance
                            ; concern rather than growing it
rtlog_ok:
rtlog1:
    ldx #$fa                ; index for a 6-byte right shift,
                            ; spanning FP1_MANT (3B) + FP_EXT (3B)
                            ; - see labels_fp.s for why FP_EXT
                            ; must physically follow FP1_MANT
ror1:
    lda #$80
    bcs ror2
    asl
ror2:
    lsr FP_EXT+3,x          ; simulate ROR via LSR+ORA (this byte
    ora FP_EXT+3,x          ; hasn't been shifted by this pass
    sta FP_EXT+3,x          ; yet, so LSR/ORA/STA == ROR here)
    inx                     ; next byte of the shift
    bne ror1                ; loop until all 6 bytes done
    rts

; ------------------------------------------------------------
; fmul (FP_FMUL) - FP1 = FP1 * FP2 (24-bit x 24-bit -> 24-bit,
; truncated, via 24 iterations of shift-and-conditionally-add)
; Entry : FP1, FP2 loaded with the two factors
; Exit  : FP1 = FP1 * FP2, normalized
; Destroys: A, X, Y
; ------------------------------------------------------------
fmul:
    jsr md1                 ; abs value of both mantissas (see
                            ; the DOUBLE-ENTRY TRICK note above)
    adc FP1_EXP             ; add exponents for the product exponent
    jsr md2                 ; range-check the exponent, zero FP1's
                            ; mantissa, load Y with the iteration count
    clc
mul1:
    jsr rtlog1              ; shift FP1_MANT/FP_EXT right one bit
                            ; (product accumulator and multiplier
                            ; share this one 6-byte shift register)
    bcc mul2                ; multiplier bit was 0: no partial product
    jsr add                 ; multiplier bit was 1: add multiplicand
mul2:
    dey                     ; next multiply iteration
    bpl mul1                ; loop for all 24 bits
mdend:
    lsr FP_SIGN             ; test running sign (even/odd negations)
normx:
    bcc norm                ; even: normalize product as-is
                            ; odd: fall through and complement
fcompl:
    sec                     ; set carry for subtract
    ldx #$03                ; index for 3-byte 2's complement
compl1:
    lda #$00
    sbc FP1_EXP,x           ; subtract a byte of FP1's mantissa
    sta FP1_EXP,x           ; ...from zero, restoring it negated
    dex                     ; next more significant byte
    bne compl1              ; loop until done
    beq addend              ; normalize (or shift right on overflow)

; ------------------------------------------------------------
; fdiv (FP_FDIV) - FP1 = FP2 / FP1 (restoring binary division,
; 23 quotient bits via repeated subtract-and-shift)
; Entry : FP1 = divisor, FP2 = dividend
; Exit  : FP1 = FP2 / FP1, normalized
; Destroys: A, X, Y
; ------------------------------------------------------------
fdiv:
    lda FP1_EXP             ; [ERROR HANDLING] divisor exactly
    bne fdiv_go             ; 0.0 (canonical zero is always
                            ; exponent $00 in this format -
                            ; see labels_fp.s)? Check BEFORE
                            ; any of the exponent arithmetic
                            ; below runs - verified (not
                            ; assumed) that a zero divisor
                            ; otherwise lands in the exact
                            ; same branch a generic magnitude
                            ; overflow does, so this needs to
                            ; be caught up front to report it
                            ; distinctly (see
                            ; library_fp_error.s's note on
                            ; this)
    lda #1                  ; error code 1: division by zero
    jmp FP_ERROR
fdiv_go:
    jsr md1                 ; abs value of both mantissas
    sbc FP1_EXP             ; subtract exponents for quotient exponent
    jsr md2                 ; range-check exponent, zero FP1, Y = 23
div1:
    sec                     ; set carry for subtract
    ldx #$02                ; index for 3-byte instruction
div2:
    lda FP2_MANT,x
    sbc FP_EXT,x            ; subtract a byte of FP_EXT (the
                            ; shifted divisor) from the remainder
    pha                     ; save partial difference on stack
    dex                     ; next more significant byte
    bpl div2                ; loop until done
    ldx #$fd                ; index for 3-byte conditional move
div3:
    pla                     ; pull a byte of the difference back
    bcc div4                ; remainder < divisor: don't keep it
    sta FP2_MANT+3,x        ; remainder >= divisor: commit the
                            ; subtraction result
div4:
    inx                     ; next less significant byte
    bne div3                ; loop until done
    rol FP1_MANT+2
    rol FP1_MANT+1          ; roll the quotient left, new
    rol FP1_MANT            ; quotient bit comes in via carry
    asl FP2_MANT+2
    rol FP2_MANT+1          ; shift the remainder (dividend)
    rol FP2_MANT            ; left, ready for the next iteration
    bcc div_ok              ; no overflow: continue normally
    lda #0                  ; [ERROR HANDLING] overflow: the
    jmp FP_ERROR            ; divisor was not normalized
                            ; (>= 1.0 assumed) - code 0
div_ok:
    dey                     ; next divide iteration
    bne div1                ; loop for all 23 bits
    beq mdend               ; normalize quotient, fix sign

; ------------------------------------------------------------
; md2 / md3 / ovchk - shared exponent bookkeeping for
; FP_FMUL and FP_FDIV: range-checks the freshly computed product/
; quotient exponent, zeroes FP1's mantissa ready for the
; multiply/divide loop, and loads Y with the iteration count.
; Entry : A = new exponent (sum for mul, difference for div),
;          carry reflects whether that add/sub overflowed, X = 0
;          (left over from fcompl/swap's loop, reused here to
;          zero 3 bytes without a fresh LDA #0)
; Exit  : FP1_MANT zeroed, FP1_EXP = corrected exponent,
;          Y = $17 (23, shared 24-mul/23-div iteration count),
;          OR an early return to the caller if the result rounds
;          to exactly zero (underflow - see MD3's "clear X1 and
;          return" path)
; ------------------------------------------------------------
md2:
    stx FP1_MANT+2
    stx FP1_MANT+1          ; clear FP1's mantissa (3 bytes) ready
    stx FP1_MANT            ; for the multiply/divide loop (X = 0)
    bcs ovchk               ; exponent add/sub set carry: check overflow
    bmi md3                 ; exponent negative: no underflow, proceed
    pla                     ; underflow: pop one return address level
    pla                     ; (unwinds past FP_FMUL/FP_FDIV's own
                            ; call frame - see file note on the
                            ; original's use of this shortcut)
    bcc normx               ; FP1 already zeroed above: done
md3:
    eor #$80                ; complement sign bit of the exponent
    sta FP1_EXP             ; (excess-128 <-> 2's complement)
    ldy #$17                ; 23: iteration count for 24-bit mul
    rts                     ; or 23-bit div
ovchk:
    bpl md3                 ; positive exponent: no overflow
    lda #0                  ; [ERROR HANDLING] error code 0:
    jmp FP_ERROR            ; generic overflow (see lib_fp_error.s)

; ------------------------------------------------------------
; fix_shift / fix_conv (FP_FIX) - truncate FP1 to an integer,
; left in FP1_MANT/FP1_MANT+1 (high byte first). Loops by
; repeatedly shifting right one bit (via rtar) until the
; exponent reaches $8E (2^14), matching FP_FLOAT's provisional
; exponent so the two are exact inverses of one another.
; Entry : FP1 loaded with the value to truncate
; Exit  : FP1_MANT = high byte of integer, FP1_MANT+1 = low byte
; Destroys: A
; ------------------------------------------------------------
fix_shift:
    jsr rtar                    ; shift FP1's mantissa right one bit
                                ; and increment the exponent
fix_conv:
    lda FP1_EXP                 ; check exponent
    cmp #$8e                    ; is it 2^14 yet?
    bne fix_shift               ; no: shift again
    rts                         ; yes: FP1_MANT/+1 hold the integer

; ------------------------------------------------------------
; Map the internal cheap locals to the globally exported symbols.
; The :: prefix forces ca65 to place these in the global namespace.
; ------------------------------------------------------------
::FP_FADD   = fadd
::FP_FSUB   = fsub
::FP_FMUL   = fmul
::FP_FDIV   = fdiv
::FP_FLOAT  = float_conv
::FP_FIX    = fix_conv
::FP_SWAP   = swap
::FP_NORM   = norm          ; normalize FP1 in place, entry documented
                            ; by wozfp3.txt as a standalone routine -
                            ; used by library_fp_convert.s to float
                            ; 8-bit and 24-bit integers without going
                            ; through FP_FLOAT's 16-bit-only entry
::FP_RTAR   = rtar          ; shift FP1's 6-byte mantissa+extension
                            ; right one bit, incrementing FP1_EXP
::FP_NEGATE = fcompl        ; FP1 = -FP1 (2's complement the mantissa,
                            ; then normalize) - also documented as a
                            ; standalone entry in wozfp3.txt
.endproc
