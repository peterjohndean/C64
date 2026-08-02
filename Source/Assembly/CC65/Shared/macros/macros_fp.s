.include "labels_fp.s"

; ============================================================
; FILE    : macros_fp.s
; PROJECT : Commodore 64 Floating Point Library (Rankin/Wozniak port)
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; FP_CORE_PROC only ever operates on the fixed FP1/FP2 zero page
; workspace in labels_fp.s. These macros are the glue for getting
; 4-byte float values in and out of that fixed workspace and an
; arbitrary caller-chosen memory location - a constant table, a
; struct field, a save-game slot, wherever.
;
; MACRO INVENTORY
; ---------------
;   FP_LOAD1_MACRO addr           - addr (4 bytes) -> FP1
;   FP_STORE1_MACRO addr          - FP1 -> addr (4 bytes)
;   FP_LOAD2_MACRO addr           - addr (4 bytes) -> FP2
;   FP_STORE2_MACRO addr          - FP2 -> addr (4 bytes)
;   FP_LOAD1_INDEXED_MACRO base   - base+Y..base+Y+3 -> FP1
;   FP_STORE1_INDEXED_MACRO base  - FP1 -> base+Y..base+Y+3
;   FP_LOAD2_INDEXED_MACRO base   - base+Y..base+Y+3 -> FP2
;   FP_STORE2_INDEXED_MACRO base  - FP2 -> base+Y..base+Y+3
;   FP_COPY1TO2_MACRO             - FP1 -> FP2, directly, no memory
;   FP_COPY2TO1_MACRO             - FP2 -> FP1, directly, no memory
;   FP_ERROR_INIT_MACRO recovery_label - arm a trap recovery point
;                                    (see library_fp_error.s)
;   FP_COMPARE_TO_MACRO addr      - compare FP1 against a memory
;                                    constant (see library_fp_compare.s)
;
; INDEXED VARIANTS: Y IS NOT MULTIPLIED FOR YOU
; -------------------------------------------------
; The _INDEXED macros read/write 4 CONSECUTIVE bytes starting at
; base+Y - i.e. Y must already be a BYTE offset, not a "float
; number" in a table. For a table of floats, that means Y = index*4
; before calling. This is deliberate: multiplying by 4 is one ASL
; ASL, cheap enough that folding it into the macro would just hide
; a cost the call site should show, and different callers may want
; that index in A or X first, which the macro can't assume for you.
; Example - load the 5th float (index 4) from a table:
;
;     lda #4
;     asl a
;     asl a           ; A = 16 = byte offset of table[4]
;     tay
;     #FP_LOAD1_INDEXED_MACRO my_float_table
;
; Because Y is a single 8-bit register, base+Y can only reach 256
; bytes past base - a table of more than 64 floats (64*4=256) needs
; a different addressing scheme entirely (e.g. a 16-bit computed
; address loaded into two zero page bytes, then indirect-indexed
; addressing) - out of scope for these macros.
;
; ROUND-TRIP EXAMPLE
; ---------------------
;   #FP_LOAD1_MACRO my_saved_value    ; load a constant into FP1
;   #FP_LOAD2_MACRO ten_constant      ; load another into FP2
;   jsr FP_FADD
;   #FP_STORE1_MACRO my_saved_value   ; write the sum back out
; ============================================================

; ============================================================
; MACRO: FP_LOAD1_MACRO
; Purpose : Copy a 4-byte float from a fixed memory address into FP1.
; Params  : addr - label or address of the 4-byte float to load
; Destroys: A
; Cycles  : ~16 cycles (4x LDA absolute + 4x STA zero page)
; ============================================================
.macro FP_LOAD1_MACRO addr
    .if .paramcount <> 1
		.error  "Too few parameters for macro FP_LOAD1_MACRO"
	.endif
    lda addr
    sta FP1_EXP
    lda addr+1
    sta FP1_MANT
    lda addr+2
    sta FP1_MANT+1
    lda addr+3
    sta FP1_MANT+2
.endmacro

; ============================================================
; MACRO: FP_STORE1_MACRO
; Purpose : Copy FP1 out to a fixed 4-byte memory address.
; Params  : addr - label or address of the 4-byte destination
; Destroys: A
; Cycles  : ~16 cycles
; ============================================================
.macro FP_STORE1_MACRO addr
    .if .paramcount <> 1
		.error  "Too few parameters for macro FP_STORE1_MACRO"
	.endif
    lda FP1_EXP
    sta addr
    lda FP1_MANT
    sta addr+1
    lda FP1_MANT+1
    sta addr+2
    lda FP1_MANT+2
    sta addr+3
.endmacro

; ============================================================
; MACRO: FP_LOAD2_MACRO / FP_STORE2_MACRO
; Purpose : As FP_LOAD1_MACRO/FP_STORE1_MACRO, for FP2.
; ============================================================
.macro FP_LOAD2_MACRO addr
    .if .paramcount <> 1
		.error  "Too few parameters for macro FP_LOAD2_MACRO"
	.endif
    lda addr
    sta FP2_EXP
    lda addr+1
    sta FP2_MANT
    lda addr+2
    sta FP2_MANT+1
    lda addr+3
    sta FP2_MANT+2
.endmacro

.macro FP_STORE2_MACRO addr
    .if .paramcount <> 1
		.error  "Too few parameters for macro FP_STORE2_MACRO"
	.endif
    lda FP2_EXP
    sta addr
    lda FP2_MANT
    sta addr+1
    lda FP2_MANT+1
    sta addr+2
    lda FP2_MANT+2
    sta addr+3
.endmacro

; ============================================================
; MACRO: FP_LOAD1_INDEXED_MACRO / FP_STORE1_INDEXED_MACRO
;         FP_LOAD2_INDEXED_MACRO / FP_STORE2_INDEXED_MACRO
; Purpose : As the plain LOAD/STORE macros above, but reading from
;           or writing to base+Y (4 consecutive bytes) instead of a
;           fixed compile-time address - for walking a table of
;           floats. See the file header for why Y isn't multiplied
;           for you.
; Params  : base - label or address of the start of the table
; Entry   : Y = byte offset into the table (index * 4)
; Exit    : Y = entry offset + 3 (advanced past the 4 bytes just
;           touched) - reload Y before the next indexed call if
;           you want base+Y to mean "index*4" again
; Destroys: A, Y
; Cycles  : ~24 cycles (4x LDA/STA absolute,Y + 3x INY)
; ============================================================
.macro FP_LOAD1_INDEXED_MACRO base
    .if .paramcount <> 1
		.error  "Too few parameters for macro FP_LOAD1_INDEXED_MACRO"
	.endif
    lda base,y
    sta FP1_EXP
    iny
    lda base,y
    sta FP1_MANT
    iny
    lda base,y
    sta FP1_MANT+1
    iny
    lda base,y
    sta FP1_MANT+2
.endmacro

.macro FP_STORE1_INDEXED_MACRO base
    .if .paramcount <> 1
		.error  "Too few parameters for macro FP_STORE1_INDEXED_MACRO"
	.endif
    lda FP1_EXP
    sta base,y
    iny
    lda FP1_MANT
    sta base,y
    iny
    lda FP1_MANT+1
    sta base,y
    iny
    lda FP1_MANT+2
    sta base,y
.endmacro

.macro FP_LOAD2_INDEXED_MACRO base
    .if .paramcount <> 1
		.error  "Too few parameters for macro FP_LOAD2_INDEXED_MACRO"
	.endif
    lda base,y
    sta FP2_EXP
    iny
    lda base,y
    sta FP2_MANT
    iny
    lda base,y
    sta FP2_MANT+1
    iny
    lda base,y
    sta FP2_MANT+2
.endmacro

.macro FP_STORE2_INDEXED_MACRO base
    .if .paramcount <> 1
		.error  "Too few parameters for macro FP_STORE2_INDEXED_MACRO"
	.endif
    lda FP2_EXP
    sta base,y
    iny
    lda FP2_MANT
    sta base,y
    iny
    lda FP2_MANT+1
    sta base,y
    iny
    lda FP2_MANT+2
    sta base,y
.endmacro

; ============================================================
; MACRO: FP_COPY1TO2_MACRO / FP_COPY2TO1_MACRO
; Purpose : Copy directly between FP1 and FP2, register-to-
;           register, with no memory intermediary. Added while
;           auditing library_fp_ascii.s for missed macro usage -
;           several spots there (e.g. building a second operand
;           for FP_FADD/FP_FSUB straight out of FP1) needed
;           exactly this and there was no macro for it yet, only
;           the to/from-memory LOAD/STORE macros above.
; Destroys: A
; Cycles  : ~16 cycles (4x LDA zero page + 4x STA zero page)
; ============================================================
.macro FP_COPY1TO2_MACRO
    lda FP1_EXP
    sta FP2_EXP
    lda FP1_MANT
    sta FP2_MANT
    lda FP1_MANT+1
    sta FP2_MANT+1
    lda FP1_MANT+2
    sta FP2_MANT+2
.endmacro

.macro FP_COPY2TO1_MACRO
    lda FP2_EXP
    sta FP1_EXP
    lda FP2_MANT
    sta FP1_MANT
    lda FP2_MANT+1
    sta FP1_MANT+1
    lda FP2_MANT+2
    sta FP1_MANT+2
.endmacro

; ============================================================
; MACRO: FP_ERROR_INIT_MACRO
; Purpose : Arm a recovery point: if any FP operation between this
;           macro and the given label traps, execution resumes AT
;           that label instead of anywhere inside library_fp.s.
;           See library_fp_error.s's file header for the full
;           setjmp/longjmp-style contract.
; Params  : recovery_label - a label YOU define, anywhere in your
;           own code (typically right after the risky call(s), or
;           at a dedicated error-handling block) - this is where
;           control lands if something traps. Forward references
;           are fine (64TASS resolves this over its normal passes).
; Destroys: A
; Cycles  : ~15 cycles
; Notes   : This pushes a return address that MUST be consumed -
;           either a trap fires and FP_ERROR_PROC's RTS consumes
;           it, or, on the success path, FP_ERROR_CLEAR_MACRO
;           (below) discards it explicitly. Skipping that on the
;           success path leaks 2 bytes of stack every time this
;           macro runs without a trap - fine once, and a real
;           stack overflow if it happens in a loop.
; Example : #FP_ERROR_INIT_MACRO my_recovery
;           jsr FP_FDIV                ; may trap
;           #FP_ERROR_CLEAR_MACRO       ; succeeded: recovery point
;           jmp my_success               ; no longer needed
;           my_recovery
;           ; only reached if something trapped - FP_ERROR_CODE
;           ; says what
;           my_success
; ============================================================
.macro FP_ERROR_INIT_MACRO recovery_label
    .if .paramcount <> 1
		.error  "Too few parameters for macro FP_ERROR_INIT_MACRO"
	.endif
    lda #>(recovery_label-1)
    pha
    lda #<(recovery_label-1)
    pha                         ; push a return address that will
                                ; land exactly at recovery_label
                                ; when something eventually RTS's
                                ; to it (see FP_ERROR_PROC)
    tsx
    stx FP_ERROR_SP             ; remember this exact stack depth -
                                ; the pushed address above is
                                ; INCLUDED in what gets restored
.endmacro

; ============================================================
; MACRO: FP_ERROR_CLEAR_MACRO
; Purpose : Discard the return address FP_ERROR_INIT_MACRO pushed,
;           for use on the SUCCESS path once you're past the risky
;           call(s) and don't need that recovery point armed
;           anymore. Without this, every non-trapping use of
;           FP_ERROR_INIT_MACRO permanently leaks 2 bytes of stack
;           (the pushed address is only ever consumed by
;           FP_ERROR_PROC's RTS if something actually traps) - fine
;           once, invisible for a while, and eventually a real
;           stack overflow if the guarded call runs in a loop or
;           the program does much more work afterward.
; Params  : none
; Destroys: nothing (A is unaffected - PLA into nowhere would
;           normally clobber A, so this discards via two throwaway
;           PLAs immediately followed by nothing that reads A, but
;           callers should still treat A as clobbered per usual
;           convention)
; Example : #FP_ERROR_INIT_MACRO my_recovery
;           jsr FP_FDIV
;           #FP_ERROR_CLEAR_MACRO      ; success: discard the now-
;           jmp my_success              ; unneeded recovery address
;           my_recovery
;           ; only reached if something trapped
;           my_success
; ============================================================
.macro FP_ERROR_CLEAR_MACRO
    pla
    pla
.endmacro

; ============================================================
; MACRO: FP_COMPARE_TO_MACRO
; Purpose : Compare FP1 against a compile-time-known 4-byte float
;           constant held in memory, without needing to load it
;           into FP2 yourself first. Thin wrapper: loads FP2, then
;           calls FP_COMPARE_PROC (library_fp_compare.s).
; Params  : addr - label of the 4-byte float to compare FP1 against
; Returns : A = 0 (FP1==addr), A = 1 (FP1>addr), A = $FF (FP1<addr),
;           N/Z flags set to match (safe for beq/bmi/bpl)
; Destroys: A, X, Y; FP2 (overwritten with the loaded constant)
; Notes   : FP1 itself is left unchanged - FP_COMPARE_PROC backs it
;           up and restores it internally.
; Example : #FP_COMPARE_TO_MACRO zero_const
;           bmi is_negative
;           beq is_zero
;           ; else FP1 > zero_const
; ============================================================
.macro FP_COMPARE_TO_MACRO addr
    .if .paramcount <> 1
		.error  "Too few parameters for macro FP_COMPARE_TO_MACRO"
	.endif
    FP_LOAD2_MACRO addr
    jsr FP_COMPARE
.endmacro
