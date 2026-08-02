; ============================================================
; FILE    : labels_fp.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; Zero page address definitions for FP_CORE_PROC, FP_LOG_PROC,
; FP_LOG10_PROC and FP_EXP_PROC in lib_fp.s. This is a
; ca65/cc65-tools port of the classic Rankin/Wozniak 6502 floating point
; package published in Dr. Dobb's Journal, August 1976:
;
;   "Floating Point Routines for the 6502"
;   by Roy Rankin (Stanford) and Steve Wozniak (Apple)
;   https://6502.org/source/floats/wozfp1.txt
;
; Roy Rankin's November/December 1976 errata corrected LOG's
; sign-extension step; that fix is implemented in lib_fp_log.s.
; See lib_fp.s and the math doc files for the full provenance.
;
; NUMBER FORMAT (unchanged from the original)
; --------------------------------------------
; 4-byte floating point value: 1 exponent byte + 3 mantissa
; bytes (this predates the C64 KERNAL's 5-byte/4-mantissa-byte
; FAC format - see the WHY NOT 4 MANTISSA BYTES note below).
;
;   Exponent : excess-128, so $80 = 2^0, $81 = 2^1, $7F = 2^-1
;   Mantissa : 2's complement, normalized to the range 1.0-2.0,
;              binary point between bits 6 and 5 of the MSB
;
;     SEEEEEEE  SM.MMMMMM  MMMMMMMM  MMMMMMMM
;        n         n+1       n+2       n+3
;
; WHY REUSE THE BASIC FAC1/FAC2 ZERO PAGE FOOTPRINT?
; ----------------------------------------------------
; Per project convention, this port deliberately places the two
; live operands (FP1 = "EXP/MANT1", FP2 = "EXP/MANT2" in the
; original documentation) at the same zero page addresses BASIC
; uses for its own Floating Point Accumulators:
;
;   FAC1  $61-$66   (6 bytes: exponent, 4-byte mantissa, sign)
;   FAC2  $69-$6E   (6 bytes: exponent, 4-byte mantissa, sign)
;
; IMPORTANT: this is address reuse only, NOT binary compatibility
; with BASIC's own FAC routines (MOVFM, FOUT, the ROM LOG/EXP,
; etc). BASIC's FAC uses a different internal algorithm (a 5-byte
; format with a guard/rounding byte) and calling any BASIC FP
; ROM routine while this package's operands are "live" in $61-$6E
; WILL corrupt them, exactly the same as calling BASIC_STROUT
; corrupts FAC1/FAC2 per the existing REU library notes. The
; benefit of reusing these addresses is simply that they are a
; well-known, documented, genuinely free 12-13 bytes whenever
; BASIC's own FP engine is not concurrently in use (e.g. once
; BASIC has been switched out, or between statements in a machine
; language program that never touches BASIC's FP commands).
;
; WHY NOT 4 MANTISSA BYTES PER OPERAND?
; ---------------------------------------
; The Woz/Rankin algorithm is written for a 3-byte mantissa (24
; bits), one byte narrower than BASIC's 4-byte (32-bit) mantissa.
; Rather than widen the algorithm - which would require re-deriving
; every shift count, carry propagation, and the FMUL/FDIV loop
; iteration counts (Y is loaded with $17 = 23 for exactly 24
; mantissa bits) - this port keeps the original 3-byte mantissa
; and simply leaves FAC1's/FAC2's 4th mantissa byte unused by FP1/
; FP2 proper. FAC1's spare 4th mantissa byte, together with its
; sign byte and the two bytes that would ordinarily hold BASIC's
; series-evaluation pointer, are instead reclaimed as the "E"
; scratch/extension buffer FP_CORE_PROC needs for the FADD/FSUB
; right-shift routine - see the FP_EXT note below.
;
; ZERO PAGE MAP
; --------------
;   Address   Label        Original name   Purpose
;   -------   -----------  --------------  ------------------------
;   $02       FP_SIGN      SIGN            mul/div running sign flag
;   $61       FP1_EXP      X1              FP1 (EXP/MANT1) exponent
;   $62-$64   FP1_MANT     M1              FP1 mantissa, MSB first
;   $65-$68   FP_EXT       E               FADD/FSUB shift extension
;   $69       FP2_EXP      X2              FP2 (EXP/MANT2) exponent
;   $6A-$6C   FP2_MANT     M2              FP2 mantissa, MSB first
;
; $02 is one of the small handful of zero page bytes with no
; fixed KERNAL/BASIC role and is commonly used by machine language
; programs for exactly this kind of one-byte flag (see also the
; project's REU library, which reserves $FB-$FD for its own,
; unrelated, aliasing-detection scratch bytes - deliberately a
; DIFFERENT block, so the FP and REU libraries can be used in the
; same program without collision).
;
; FP_EXT ("E") MUST IMMEDIATELY FOLLOW FP1_MANT
; ------------------------------------------------
; FP_CORE_PROC's 6-byte right-shift routine (used to align
; mantissas before FADD/FSUB, and to normalize FMUL/FDIV results)
; addresses FP1_MANT and FP_EXT as one continuous 6-byte run using
; a single indexed loop (LSR FP_EXT+3,X for X = -6..-1). This only
; works because zero-page,X indexed addressing wraps modulo 256,
; so FP_EXT must sit in zero page, immediately after FP1_MANT, with
; no gap. Do not move FP_EXT without re-deriving that offset - see
; the RTLOG1 comments in library_fp.s for the full derivation.
;
; SCRATCH FOR LOG/LOG10/EXP (Z, T, SEXP, INT)
; ----------------------------------------------
; The original package also declares four scratch areas (Z, T,
; SEXP - each 4 bytes - and INT, 1 byte) used internally by LOG
; and EXP. These have no adjacency requirement (they are only ever
; walked with a plain LDX #3..0 countdown, never the zero-page-
; wraparound trick above), so rather than reserve more scarce zero
; page for them, each of FP_LOG_PROC and FP_EXP_PROC declares its
; OWN private copy as ordinary (non-zero-page) RAM at the end of
; its own .proc block, following the project convention of
; declaring buffers with .fill/.byte at the end of the file/proc
; rather than at a fixed address. This costs a few extra cycles per
; access (absolute,X instead of zero-page,X) but keeps LOG and EXP
; independent and avoids spending extra zero page unless those
; routines are linked.
; ============================================================
.ifndef LABELS_FP_S
LABELS_FP_S = 1
FP_SIGN     = $02   ; mul/div running sign flag (SIGN)

FP_STRPTR   = $FB   ; string pointer (2 bytes, $FB-$FC), used only by
                     ; FP_FROM_ASCII_PROC/FP_TO_ASCII_PROC in
                     ; lib_fp_from_ascii.s/lib_fp_to_ascii.s for
                     ; (FP_STRPTR),y indirect
                     ; addressing - indirect-indexed addressing REQUIRES
                     ; its pointer to live in zero page, unlike everything
                     ; else in this library. $FB-$FE is a commonly-cited
                     ; genuinely free block ("FB-FE are not used, you
                     ; should be good even with BASIC running" - per
                     ; community consensus; also where this project's own
                     ; REU library stages its aliasing-detection bytes).
                     ; That REU use is transient (inside single subroutine
                     ; calls, never held across a JSR out to other code),
                     ; and so is this one, so the two don't collide in
                     ; practice - but don't call FP_FROM_ASCII_PROC or
                     ; FP_TO_ASCII_PROC from the middle of an in-flight
                     ; REU_ALIASING_DETECT_PROC/REU_DETECT_SIZE_PROC call
                     ; (or vice versa); they aren't reentrant with respect
                     ; to this shared block.

FP_ERROR_SP   = $FD  ; saved stack pointer for FP_ERROR_PROC's recovery
                      ; unwind (see library_fp_error.s) - part of the same
                      ; commonly-free $FB-$FE block as FP_STRPTR above, and
                      ; subject to the same transient-use caveat
FP_ERROR_CODE = $FE  ; last trapped error code (see library_fp_error.s
                      ; for the code list) - readable after a trapped
                      ; operation returns control via FP_ERROR_PROC's
                      ; unwind, so the caller can find out what happened

FP1_EXP     = $61   ; FP1 exponent               (X1)  - FAC1 exponent byte
FP1_MANT    = $62   ; FP1 mantissa, 3 bytes       (M1)  - FAC1 mantissa bytes 1-3
FP_EXT      = $65   ; FADD/FSUB shift extension   (E)   - FAC1 mantissa byte 4 + sign + 2 spare bytes

FP2_EXP     = $69   ; FP2 exponent                (X2)  - FAC2 exponent byte
FP2_MANT    = $6A   ; FP2 mantissa, 3 bytes       (M2)  - FAC2 mantissa bytes 1-3
.endif
