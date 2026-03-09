; ---------------------------------------------------------------------------
; main.s — project entry point
;
; Assembled with 64TASS targeting the MOS 6510 CPU (Commodore 64).
;
; Memory layout:
;   $0801  — BASIC program start address (standard CBM load address)
;   $080d  — machine code entry point, reached via the BASIC SYS stub
;   $ffd2  — Kernal CHROUT: outputs character in A to the current output device
; ---------------------------------------------------------------------------

.cpu "6502"

; set the program counter to the BASIC start address
* = $0801	; run

; ---------------------------------------------------------------------------
; BASIC stub — generates the one-line BASIC program:  10 SYS xxxx
;
; When RUN is typed, BASIC executes SYS xxxx which transfers control to the
; machine code entry point.
;
; BASIC line structure in memory:
;   word  : pointer to the next line (little-endian)
;   word  : line number (little-endian)
;   bytes : tokenised BASIC content
;   $00   : end-of-line terminator
; ---------------------------------------------------------------------------

basic_stub
        .word   basic_end			; pointer to the next BASIC line
        .word   10					; BASIC line number 10
        .byte   $9e					; BASIC token for SYS
        .text   format("%d", entry)	; decimal string of 'entry' address
									; format() is evaluated at assemble-time
									; across 64TASS's multi-pass resolution
        .byte   0					; end-of-line terminator

basic_end
        .word   0					; null next-line pointer — end of BASIC program

; ---------------------------------------------------------------------------
; Machine code entry point
; ---------------------------------------------------------------------------
entry
    jsr initiate_reu_tests
    jsr initiate_test_library
    rts

.include "labels_rom_basic.s"
.include "labels_rom_kernal.s"
.include "labels_reu.s"
.include "labels_screen.s"
.include "labels_memorymap.s"
;
.include "macros_reu.s"
.include "macros_rom_basic.s"
.include "macros_rom_kernal.s"
;
.include "library_reu.s"
.include "library_bitwise.s"
.include "library_convert.s"
;
.include "../routines/for_macros_reu.s"
.include "../routines/for_library_all.s"
