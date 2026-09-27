.include "labels_rom_kernal.s"

; ============================================================
; FILE      : macros_rom_KERNAL.s
; Project   : Commodore 64 ROM / KERNAL Macro Library
; Target    : Commodore 64 / 6510 CPU
; Assembler : CC65 tools
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
;   KERNAL_CHROUT_MACRO    — load immediate byte into A, call CHROUT
;   KERNAL_PLOT_SET_MACRO  — move the cursor to a compile-time
;                            constant (column,row) via KERNAL PLOT
;   KERNAL_PLOT_GET_MACRO  — read the cursor's current (column,row)
;                            via KERNAL PLOT
;
; ASSEMBLER : ca65 / cc65 tools
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
; (or another runtime wrapper around CHROUT)
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
;     KERNAL_CHROUT_MACRO $0D    ; output carriage return
;     KERNAL_CHROUT_MACRO $93    ; clear screen
;     KERNAL_CHROUT_MACRO 'A'    ; output the letter A
; ============================================================
.macro KERNAL_CHROUT_MACRO byte
	.if .paramcount <> 1
			.error  "Too few parameters for macro KERNAL_CHROUT_MACRO"
	.endif
    lda #byte			; load compile-time constant into accumulator
    jsr KERNAL_CHROUT	; call KERNAL CHROUT: output A to current channel
.endmacro


; ============================================================
; MACRO     : KERNAL_PLOT_SET_MACRO
; ============================================================
; PURPOSE
; -------
; Moves the text cursor to a compile-time constant screen
; position (column, row) by loading the KERNAL PLOT routine's
; registers and calling it with carry CLEAR (the "set" mode).
;
; This is the counterpart to KERNAL_PLOT_GET_MACRO below - one
; sets the cursor, the other reads it back. Both share the same
; underlying KERNAL entry point ($FFF0); it's the carry flag on
; entry that tells PLOT which of the two jobs to do (see KERNAL
; PLOT BEHAVIOUR below).
;
; KERNAL PLOT ($FFF0) BEHAVIOUR
; --------------------------------
; PLOT is a dual-purpose routine baked into the KERNAL jump
; table (see labels_rom_kernal.s) - the SAME entry point either
; reads or writes the cursor position, distinguished only by the
; carry flag on entry:
;   carry CLEAR on entry -> SET cursor to X=row, Y=column
;   carry SET   on entry -> GET cursor into X=row, Y=column
; This "one routine, carry flag picks the mode" pattern is
; common in KERNAL routines from this era - it keeps the jump
; table entry, and hence any code compiled against it, unchanged
; between C64 ROM revisions even though it does two logically
; different things.
;
; WHY X=ROW AND Y=COLUMN (NOT THE OTHER WAY ROUND)
; -----------------------------------------------------
; This mapping comes directly from the KERNAL's own convention
; (see labels_rom_kernal.s's own comment on the KERNAL_PLOT
; label) and is easy to get backwards, since "X,Y" superficially
; looks like it should mean "column,row" (the usual math-graph
; ordering). It doesn't here - X is the row (0-24, the screen's
; 25 text lines) and Y is the column (0-39, the screen's 40
; character columns). Getting this backwards silently plots to
; the wrong spot rather than erroring, since both registers are
; valid 8-bit values either way - there's nothing for the KERNAL
; to reject.
;
; WHY THE RANGE CHECKS ARE COMPILE-TIME .error, NOT A RUNTIME
; BOUNDS CHECK
; -----------------------------------------------------------------
; column/row here are macro PARAMETERS - values baked in at
; assembly time, not runtime variables - so an out-of-range value
; is a bug in the SOURCE CODE, not something that can happen at
; runtime for this particular macro. .error stops assembly dead
; with a message pointing at the mistake, rather than silently
; assembling a PLOT call that would move the cursor off-screen
; (which, on real hardware, could corrupt adjacent screen memory
; or at minimum render somewhere unexpected). This is strictly
; cheaper than a runtime check too - zero extra bytes and zero
; extra cycles in the assembled program, since the check never
; makes it into the 6510 instruction stream at all.
;
; ALGORITHM
; ---------
;   1. LDY #\column     — column (0-39) into Y, per PLOT's own
;                          X=row/Y=column convention
;   2. LDX #\row         — row (0-24) into X
;   3. CLC               — carry clear selects PLOT's "set" mode
;   4. JSR KERNAL_PLOT   — move the cursor; PLOT's own RTS
;                          returns to the macro call site
;
; PARAMS    : column — compile-time constant, screen column,
;                       range: 0-39 (40 text columns)
;             row    — compile-time constant, screen row,
;                       range: 0-24 (25 text lines)
;             Both are checked at ASSEMBLY TIME (see the
;             .error note above) - passing a value outside
;             either range fails the build, it does not produce
;             a working-but-wrong program.
;
; REGISTER USE
; ------------
;   Entry : none required
;   Exit  : X, Y as left by KERNAL PLOT (not meaningfully
;           reusable - see DESTROYS below)
;
; DESTROYS  : A is NOT touched by this macro itself, but KERNAL
;             PLOT's own internal implementation is not
;             guaranteed A-safe across ROM revisions - treat A as
;             clobbered by convention, the same caution this
;             file's own labels_rom_kernal.s comment implies for
;             every KERNAL jump table call
; PRESERVES : nothing guaranteed beyond what's stated above -
;             X and Y are deliberately loaded by this macro and
;             so are never "preserved" in the sense of holding
;             their PRE-macro values
;
; CYCLES    : 2 (LDY #imm) + 2 (LDX #imm) + 2 (CLC) + 6 (JSR)
;             ≈ 12 cycles + KERNAL_PLOT call time
;
; A NOTE ON RUNTIME (NON-CONSTANT) CURSOR POSITIONS
; -----------------------------------------------------
; Like KERNAL_CHROUT_MACRO above, this macro only accepts
; assembly-time CONSTANTS (LDY/LDX immediate can't load a
; runtime variable). If the column/row to plot to is only known
; at runtime (e.g. computed from a game object's position), load
; X and Y yourself from memory/registers and JSR KERNAL_PLOT
; directly with carry clear - this macro is a convenience
; wrapper for the common "I already know exactly where" case, not
; the only way to call PLOT.
;
; REFERENCE
; -----------
; C64 Programmer's Reference Guide, KERNAL routine PLOT ($FFF0) -
; the authoritative description of the X=row/Y=column convention
; and the carry-flag get/set dispatch used here.
;
; EXAMPLE
; -------
;     KERNAL_PLOT_SET_MACRO 0, 0      ; cursor to top-left corner
;     KERNAL_PLOT_SET_MACRO 20, 12    ; cursor to (col 20, row 12),
;                                      ; roughly screen centre
; ============================================================
.macro KERNAL_PLOT_SET_MACRO column, row
	.if .paramcount <> 2
        .error  "Too few parameters for macro KERNAL_PLOT_SET_MACRO"
    .endif
    .if ((column < 0) .OR (column > 39))
        .error "KERNAL_PLOT_SET_MACRO column must be in range 0-39"
    .endif
    .if ((row < 0) .OR (row > 24))
        .error "KERNAL_PLOT_SET_MACRO row must be in range 0-24"
    .endif
    ldy #column			; column (0-39) - PLOT's Y register input
    ldx #row			; row    (0-24) - PLOT's X register input
    clc					; carry CLEAR = "set" mode (see PLOT BEHAVIOUR above)
    jsr KERNAL_PLOT		; move the cursor to (column,row)
.endmacro

; ============================================================
; MACRO     : KERNAL_PLOT_GET_MACRO
; ============================================================
; PURPOSE
; -------
; Reads the text cursor's CURRENT screen position by calling the
; KERNAL PLOT routine with carry SET (the "get" mode) - the
; read-back counterpart to KERNAL_PLOT_SET_MACRO above. See that
; macro's own KERNAL PLOT BEHAVIOUR note for why one routine at
; $FFF0 does both jobs, selected by the carry flag on entry.
;
; WHY THIS TAKES NO PARAMETERS (UNLIKE THE "SET" MACRO)
; -----------------------------------------------------------
; KERNAL_PLOT_SET_MACRO needs column/row as INPUTS - values only
; the caller can supply, since the whole point is choosing where
; to move the cursor. This macro is the opposite: the cursor's
; position isn't something the CALLER decides, it's something
; the KERNAL already knows, and this macro's whole job is asking
; for it back. There is nothing meaningful for a caller to pass
; in here - the code always does exactly one thing (SEC, then
; JSR), so the macro's parameter list is legitimately empty
; rather than missing something.
;
; ALGORITHM
; ---------
;   1. SEC               — carry set selects PLOT's "get" mode
;   2. JSR KERNAL_PLOT    — read the cursor; PLOT's own RTS
;                           returns to the macro call site, with
;                           X=row, Y=column already loaded
;
; PARAMS    : none
;
; REGISTER USE
; ------------
;   Entry : none required
;   Exit  : X = current cursor row    (0-24)
;           Y = current cursor column (0-39)
;           (same X=row/Y=column convention as the "set" macro -
;           see that macro's WHY X=ROW AND Y=COLUMN note; it's
;           easy to misremember as the other way round when
;           reading these registers back out afterward)
;
; DESTROYS  : A is not loaded by this macro itself, but - same
;             caution as KERNAL_PLOT_SET_MACRO above - KERNAL
;             PLOT's own internals aren't guaranteed A-safe, so
;             treat A as clobbered by convention
; PRESERVES : nothing - X and Y are OVERWRITTEN with the cursor
;             position by this macro; back them up first with
;             PHA/TXA/PHA/TYA/PHA (or a zero page scratch byte)
;             if you need their pre-call values again afterward
;
; CYCLES    : 2 (SEC) + 6 (JSR) ≈ 8 cycles + KERNAL_PLOT call time
;
; EXAMPLE
; -------
;     KERNAL_PLOT_GET_MACRO      ; X = current row, Y = current column
;     stx saved_row               ; stash them somewhere durable -
;     sty saved_column            ; X/Y won't survive the next call
;                                 ; that also uses them
; ============================================================
.macro KERNAL_PLOT_GET_MACRO
	.if .paramcount <> 0
			.error  "Too few parameters for macro KERNAL_PLOT_GET_MACRO"
    .endif
    sec					; carry SET = "get" mode (see PLOT BEHAVIOUR above)
    jsr KERNAL_PLOT		; read the cursor: X=row, Y=column on return
.endmacro
