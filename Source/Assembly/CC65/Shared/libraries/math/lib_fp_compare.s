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
; WHY THIS IS BUILT ON TOP OF FP_FSUB, NOT A FRESH COMPARISON
; ------------------------------------------------------------
; Comparing two floats in this format directly (byte by byte)
; is NOT as simple as an unsigned compare: the mantissa is 2's
; complement, so a negative number's raw bytes look "larger" than
; a positive number's, and for two numbers of the same sign, a
; larger exponent means a larger MAGNITUDE - which means a larger
; VALUE if both are positive, but a SMALLER (more negative) value
; if both are negative. Getting all of that right from scratch is
; exactly the kind of subtle sign-logic that has caused real bugs
; elsewhere in this port (see the errata fix and the FSUB/FDIV
; register-clobbering bugs in earlier revisions of this library).
; FP_FADD/FP_FSUB already get this correct - proven by the test
; suite - so FP_COMPARE_PROC computes FP2-FP1 via the real FSUB and
; reads the sign of the (canonically normalized) result, rather
; than re-implementing comparison logic that could reintroduce the
; same class of bug. The cost is a full FSUB's worth of cycles
; instead of a handful of byte compares - a fair trade for
; correctness given how easy this specific kind of bug is to get
; wrong and how hard it is to notice (it only shows up for specific
; sign/magnitude combinations, not universally).
;
; DEPENDENCIES
; ------------
; Requires labels_fp.s and library_fp.s to be included before this
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
; Cycles  : dominated by one FP_FSUB call, plus ~50 cycles of
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
