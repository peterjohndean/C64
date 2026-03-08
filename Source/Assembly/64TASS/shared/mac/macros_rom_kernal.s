; ============================================================
; FILE      : macros_rom_KERNAL.s
; Project   : Commodore 64 ROM / KERNAL Macro Library
; Target    : Commodore 64 / 6510 CPU
; Assembler : 64TASS v1.60+
; ============================================================
; PURPOSE
; -------
; Provides convenience macros for invoking Commodore 64 KERNAL
; ROM routines without manually loading registers beforehand.
; Each macro encapsulates the load-and-call pattern into a
; single assembler directive, reducing boilerplate and making
; call sites self-documenting.
;
; WHAT IS THE KERNAL?
; -------------------
; The Commodore 64 KERNAL is an 8KB ROM at $E000-$FFFF that
; provides the operating system layer: screen I/O, serial bus,
; tape and disk routines, memory initialisation, and the IRQ/
; NMI/RESET vectors. It is accessed through a fixed jump table
; of 3-byte JSR stubs at the top of the address map, ensuring
; that programs remain compatible across hardware revisions
; even if the underlying ROM implementation changes.
;
; Selected KERNAL jump table entry points:
;   $FFD2  CHROUT / BSOUT  — output character in A to open channel
;   $FFE4  GETIN           — read character from keyboard queue
;   $FFCF  CHRIN           — input character from open channel
;   $FFE1  STOP            — test the STOP key
;   $FFC0  OPEN            — open a logical file
;   $FFC3  CLOSE           — close a logical file
;   $FFC6  CHKIN           — set input channel
;   $FFC9  CHKOUT          — set output channel
;   $FFCC  CLRCHN          — reset I/O channels to defaults
;
; DEPENDENCIES
; ------------
; The label KERNAL_CHROUT must be defined before invoking any
; macro in this file. Define it once in your labels file:
;
;   KERNAL_CHROUT  =  $FFD2    ; KERNAL CHROUT jump table entry
;
; MACRO INVENTORY
; ---------------
;   KERNAL_CHROUT_MACRO  — load immediate byte into A, call CHROUT
;
; ASSEMBLER : 64TASS (tested against v1.60)
; ============================================================

; ============================================================
; MACRO     : KERNAL_CHROUT_MACRO
; ============================================================
; PURPOSE
; -------
; Outputs a single compile-time constant character to the
; current output channel by loading the value into A and
; calling the KERNAL CHROUT routine ($FFD2).
;
; This macro is intended for outputting literal characters or
; control codes that are known at assembly time. For runtime
; values already in a register or memory, call KERNAL_CHROUT
; (or the CHROUT procedure wrappers in library_convert.s)
; directly — using this macro with a runtime variable is not
; possible because LDA immediate only accepts a constant.
;
; KERNAL CHROUT ($FFD2) BEHAVIOUR
; --------------------------------
; CHROUT expects the character to output in the accumulator.
; It writes the character to whichever output channel is
; currently open (screen by default, or a serial/tape file
; if CHKOUT has redirected output). On return, A is preserved
; and the carry flag indicates an I/O error (C=1 = error).
;
; Common control codes useful with this macro:
;   $0D  — carriage return (move cursor to start of next line)
;   $11  — cursor down
;   $93  — clear screen
;   $05  — change text colour to white
;   $1C  — change text colour to red
;   $9E  — change text colour to yellow
; Full control code reference: C64 Programmer's Reference Guide,
; Appendix E — Screen Editor Control Characters.
;
; ALGORITHM
; ---------
;   1. LDA #\byte      — load the constant byte into A
;   2. JSR KERNAL_CHROUT — call KERNAL CHROUT to output the character
;      (CHROUT's own RTS returns to the macro call site)
;
; PARAMS    : byte — compile-time constant character or control code
;                    range: $00-$FF (any 8-bit value)
;
; REGISTER USE
; ------------
;   Entry : none required
;   Exit  : A = the byte that was output (CHROUT preserves A)
;           C = I/O error flag (0 = success, 1 = error)
;
; DESTROYS  : A (loaded with \byte before the call)
; PRESERVES : X, Y
;
; CYCLES    : 2 (LDA #imm) + 6 (JSR) + KERNAL_CHROUT call time
;             ≈ 8 cycles + KERNAL_CHROUT call time
;
; EXAMPLE
; -------
;     #KERNAL_CHROUT_MACRO $0D    ; output carriage return
;     #KERNAL_CHROUT_MACRO $93    ; clear screen
;     #KERNAL_CHROUT_MACRO 'A'    ; output the letter A
; ============================================================
KERNAL_CHROUT_MACRO .macro byte
    lda #\byte              ; load compile-time constant into accumulator
    jsr KERNAL_CHROUT       ; call KERNAL CHROUT: output A to current channel
.endmacro
