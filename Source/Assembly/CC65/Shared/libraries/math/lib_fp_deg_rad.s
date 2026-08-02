.include "macros_fp.s"

.export FP_DEG_TO_RAD, FP_RAD_TO_DEG
.import FP_FMUL

.segment "CODE"
; ============================================================
; FILE    : lib_fp_deg_rad.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; FP_SIN/FP_SIN_FULL/FP_COS/FP_TAN all take radians, but degrees
; are what a human (or a test angle, or a game's rotation value)
; usually starts with - every test in tr_sin.s/tr_sin_full.s/
; tr_cos.s/tr_tan.s so far has had to hand-derive its own radian
; byte constant with an external Python script rather than just
; writing "30" and converting it on the C64 itself. These two
; routines close that gap.
;
; THE MATH: A SINGLE SCALE FACTOR, NOTHING ELSE
; -----------------------------------------------------
; A full circle is both 360 degrees and 2*pi radians, so converting
; between them is nothing more than one multiplication by a fixed
; ratio:
;
;   radians = degrees * (pi/180)      pi/180 = 0.0174532925...
;   degrees = radians * (180/pi)      180/pi = 57.2957795...
;
; That's the entire algorithm for both directions - one FP_FMUL
; each against a precomputed constant, no range reduction, no
; polynomial, nothing this library hasn't already done a hundred
; times over. Deliberately the simplest file in the trig family.
;
; ROUND-TRIP PRECISION - HONEST NUMBERS, NOT JUST "IT WORKS"
; -----------------------------------------------------------------
; Because pi/180 and 180/pi are each independently rounded to fit
; this format's ~22-bit mantissa, converting degrees->radians->
; degrees again does NOT reproduce the original value bit-for-bit -
; checked numerically before writing this file, not assumed:
;
;   input      round-trip result   error
;   ---------  -------------------  ----------
;    30 deg      30.000001 deg      +1.32e-6
;    90 deg      90.000004 deg      +3.97e-6
;   270 deg     270.000012 deg      +1.19e-5
;   400 deg     400.000018 deg      +1.76e-5
;
; The error grows roughly linearly with the input magnitude (it's
; a RELATIVE error of about 4e-8, staying constant - consistent
; with this format's own ~1e-7 mantissa precision floor, same
; floor every other routine in this library runs into, not a new
; problem specific to these two routines). For any use where a
; few parts-per-hundred-thousand doesn't matter - display angles,
; game rotation, typical test inputs - this is invisible. It would
; matter for something computing a huge number of accumulated small
; rotations (e.g. repeatedly rotating a value by a fixed degree
; step thousands of times) - not a concern for how this library's
; trig functions have been used so far, but worth knowing rather
; than discovering by surprise later.
;
; ERROR HANDLING
; ----------------
; No FP_ERROR_INIT_MACRO guard of its own - same convention as
; FP_COS_PROC/FP_TAN_PROC. A single FP_FMUL against a fixed,
; reasonably-sized constant is extremely unlikely to overflow for
; any realistic input, but if it somehow did (an astronomically
; large degree value), that trap propagates upward to whatever
; guard the CALLER armed, same contract as the rest of this
; library.
;
; ROUTINE INVENTORY
; -------------------
;   FP_DEG_TO_RAD_PROC - FP1 = FP1 (degrees) * pi/180 -> radians
;   FP_RAD_TO_DEG_PROC - FP1 = FP1 (radians) * 180/pi -> degrees
; ============================================================

; ============================================================
; PROCEDURE : FP_DEG_TO_RAD_PROC
; Purpose : Convert FP1 from degrees to radians, in place.
; Entry   : FP1 = angle in degrees
; Exit    : FP1 = angle in radians
; Destroys: A, X, Y; FP2
; Example : #FP_LOAD1_MACRO some_degree_value
;           jsr FP_DEG_TO_RAD
;           jsr FP_SIN_FULL      ; now safe to feed straight into
;                                ; any of this library's trig calls
; ============================================================
.proc FP_DEG_TO_RAD_PROC
    FP_LOAD2_MACRO deg_to_rad_const
    jsr FP_FMUL                  ; FP1 = degrees * (pi/180) = radians
    rts

deg_to_rad_const: .byte $7a,$47,$7d,$1b   ; pi/180 = 0.0174532925
.endproc

; ============================================================
; PROCEDURE : FP_RAD_TO_DEG_PROC
; Purpose : Convert FP1 from radians to degrees, in place. The
;           inverse of FP_DEG_TO_RAD_PROC - see that routine's
;           header, and this file's own ROUND-TRIP PRECISION note,
;           for why applying both in sequence doesn't return
;           EXACTLY the original value.
; Entry   : FP1 = angle in radians
; Exit    : FP1 = angle in degrees
; Destroys: A, X, Y; FP2
; ============================================================
.proc FP_RAD_TO_DEG_PROC
    FP_LOAD2_MACRO rad_to_deg_const
    jsr FP_FMUL                  ; FP1 = radians * (180/pi) = degrees
    rts

rad_to_deg_const: .byte $85,$72,$97,$70   ; 180/pi = 57.2957795
.endproc

; ------------------------------------------------------------
; Short public aliases, matching the rest of the library's
; FP_FADD-style naming (no _PROC suffix).
; ------------------------------------------------------------
FP_DEG_TO_RAD = FP_DEG_TO_RAD_PROC
FP_RAD_TO_DEG = FP_RAD_TO_DEG_PROC
