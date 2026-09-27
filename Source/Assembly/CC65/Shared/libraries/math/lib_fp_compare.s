.include "labels_fp.s"

.export FP_COMPARE
.import FP_FSUB

.segment "CODE"
; ============================================================
; FILE    : lib_fp_compare.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; Compares FP1 against FP2 without destroying either.
;
; HOW COMPARISON WORKS: FAST-PATH SIGN/EXPONENT LOGIC, WITH FP_FSUB
; AS A NARROW FALLBACK, NOT THE PRIMARY MECHANISM
; ------------------------------------------------------------
; An earlier version of this routine always computed FP2-FP1 via
; the already-proven FP_FSUB and read the sign of the result -
; deliberately avoiding hand-rolled sign/magnitude comparison
; logic, which is easy to get wrong for this format (2's
; complement mantissa means a negative number's raw bytes look
; "larger" than a positive one's; equal-sign comparisons need the
; exponent AND the sign of the mantissa read together).
;
; The current version instead resolves most cases directly,
; without ever calling FP_FSUB:
;   1. Canonical zero (exponent 0) on either or both operands is
;      handled by direct comparison.
;   2. Operands with different signs are resolved immediately -
;      positive is always greater than negative.
;   3. Same-sign operands whose exponents differ by 25 or more are
;      resolved by exponent/sign alone: with a 24-bit mantissa,
;      a difference this large means the smaller-magnitude operand
;      cannot affect an FSUB's outcome, so the winner is decided by
;      which one has the larger exponent (for positive operands) or
;      smaller exponent (for negative ones, since magnitude and
;      value move in opposite directions when both are negative).
; FP_FSUB is only actually called (@do_fsub) for same-sign operands
; whose exponents are close enough (diff < 25) that the comparison
; genuinely needs a real subtraction to resolve. This still avoids
; reimplementing sign/magnitude logic for the one case that's hard
; to get right by inspection - it just no longer does so for every
; case, only the one where a real subtraction is unavoidable.
;
; WHY 25, NOT 24: with a 24-bit (3-byte) mantissa, an exponent gap
; of exactly 24 already shifts the smaller operand's every mantissa
; bit past the end during alignment, but FP_FADD/FP_FSUB's own
; alignment shift register extends one byte further via FP_EXT (see
; labels_fp.s's FP_EXT note), giving a small amount of guard-bit
; headroom. 25 is used as a one-bit-of-margin cutoff above the bare
; 24-bit threshold, rather than cutting it exactly at the
; theoretical edge - not independently re-derived bit-for-bit here,
; and worth confirming against FP_FSUB's actual alignment-shift
; width if this threshold is ever changed.
;
; DEPENDENCIES
; ------------
; Requires labels_fp.s and lib_fp.s to be included before this
; file (uses FP_FSUB and the FP1/FP2 zero page layout).
;
; ROUTINE INVENTORY
; -------------------
;   FP_COMPARE_PROC - compare FP1 against FP2
; See macros_fp.s for FP_COMPARE_TO_MACRO, a convenience wrapper
; that loads FP2 from a memory-resident constant first.
; ============================================================

; ============================================================
; PROCEDURE : FP_COMPARE_PROC
; Purpose : Compare FP1 against FP2.
; Entry   : FP1, FP2 loaded
; Exit    : A = 0   if FP1 == FP2
;           A = 1   if FP1 >  FP2
;           A = $FF if FP1 <  FP2
;           N/Z flags set to match A, so the caller can go straight
;           to beq/bmi/bpl without an extra compare
; Destroys: A, X, Y; FP1 and FP2 are used as scratch internally
;           (via FP_FSUB) but are restored to their original values
;           before this returns - neither is visibly altered
; Cycles  : varies by path - canonical-zero, opposite-sign, and
;           large-exponent-difference cases resolve in well under
;           50 cycles with no FP_FSUB call at all; same-sign,
;           close-exponent cases fall through to @do_fsub and are
;           dominated by one FP_FSUB call plus ~50 cycles of
;           backup/restore overhead
; Example : #FP_COMPARE_TO_MACRO some_constant
;           bmi too_small
;           beq exact_match
;           ; else FP1 > some_constant
; ============================================================
.proc FP_COMPARE_PROC
    ldx #3
@backup_loop:
    lda FP1_EXP,x
    sta cmp_backup1,x
    lda FP2_EXP,x
    sta cmp_backup2,x
    dex
    bpl @backup_loop

    ; --- canonical-zero check (exp=0 means zero, mant ignored) ---
    lda FP1_EXP
    ora FP2_EXP
    beq @both_zero

    lda FP1_EXP
    bne @fp1_nonzero
    ; FP1 = 0, FP2 != 0  =>  FP1 < FP2
    lda #$FF
    jmp @set_result

@fp1_nonzero:
    lda FP2_EXP
    bne @both_nonzero
    ; FP2 = 0, FP1 != 0  =>  FP1 > FP2
    lda #1
    jmp @set_result

@both_nonzero:
    ; --- SIGN CHECK FIRST (avoids FSUB overflow on opposite signs) ---
    lda FP1_MANT
    eor FP2_MANT
    bpl @same_sign          ; bit7 clear in XOR => same sign

    ; signs differ: positive > negative
    lda FP1_MANT
    bmi @fp1_is_neg
    lda #1                  ; FP1 + , FP2 -  =>  FP1 > FP2
    jmp @set_result
@fp1_is_neg:
    lda #$FF                ; FP1 - , FP2 +  =>  FP1 < FP2
    jmp @set_result

@same_sign:
    ; --- exponent-difference check ---
    lda FP1_EXP
    sec
    sbc FP2_EXP
    bcs @fp1_exp_ge

    ; FP2_EXP > FP1_EXP
    eor #$FF
    clc
    adc #1                  ; A = FP2_EXP - FP1_EXP
    cmp #25
    bcc @do_fsub            ; diff < 25: safe to FSUB
    ; diff >= 25: FP2 magnitude dominates
    lda FP1_MANT
    bmi @neg_fp1_smaller
    lda #$FF                ; both + , FP1 < FP2
    jmp @set_result
@neg_fp1_smaller:
    lda #1                  ; both - , FP1 > FP2
    jmp @set_result

@fp1_exp_ge:
    cmp #25
    bcc @do_fsub            ; diff < 25: safe to FSUB
    ; diff >= 25: FP1 magnitude dominates
    lda FP1_MANT
    bmi @neg_fp1_larger
    lda #1                  ; both + , FP1 > FP2
    jmp @set_result
@neg_fp1_larger:
    lda #$FF                ; both - , FP1 < FP2
    jmp @set_result

@both_zero:
    lda #0
    ; fall through

@set_result:
    ; A = $00 (equal), $01 (FP1>FP2), $FF (FP1<FP2)
    ; LDA already set N/Z appropriately; CMP #0 is a belt-and-braces
    ; confirmation in case any path loads A differently.
    cmp #0
    rts

@do_fsub:
    jsr FP_FSUB         ; FP1 = FP2 - FP1 (destroys both -
                        ; restored below before returning)

    ldy #0              ; assume equal
    lda FP1_EXP
    beq @restore        ; exponent 0 = canonical zero (see
                        ; labels_fp.s) = FP1 equals FP2
    lda FP1_MANT
    bmi @greater        ; FP2-FP1 < 0, i.e. FP1 > FP2
    ldy #$ff            ; FP2-FP1 > 0, i.e. FP1 < FP2
    jmp @restore
@greater:
    ldy #1              ; FP2-FP1 < 0, i.e. FP1 > FP2
@restore:
    ldx #3
@restore_loop:
    lda cmp_backup1,x
    sta FP1_EXP,x
    lda cmp_backup2,x
    sta FP2_EXP,x
    dex
    bpl @restore_loop
    tya                 ; A = result, N/Z set to match (TYA
    rts                 ; affects flags - no extra CMP needed)

cmp_backup1: .res 4,0
cmp_backup2: .res 4,0
.endproc

; ------------------------------------------------------------
; Short public aliases, matching the rest of the library's
; FP_FADD-style naming (no _PROC suffix).
; ------------------------------------------------------------
FP_COMPARE = FP_COMPARE_PROC
