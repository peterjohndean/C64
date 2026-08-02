.include	"labels_rom_basic.s"

; ============================================================
; MACRO: BASIC_STROUT_MACRO
; Purpose : Output a null-terminated string via BASIC_STROUT
;           by loading the string address into A (lo) / Y (hi)
; Params  : msg    - label of a null-terminated string to print
; Destroys: Accumulator (A), Y register
; Notes   : The string must be terminated with a null byte ($00).
;           Typically defined as:  txt .null "your string"
; Cycles  : ~12 cycles + BASIC_STROUT call time
; ============================================================
.macro BASIC_STROUT_MACRO msg
	.if .paramcount <> 1
		.error  "Too few parameters for macro BASIC_STROUT_MACRO"
	.endif
    lda #<msg			; lsb
    ldy #>msg			; msb
    jsr BASIC_STROUT
.endmacro

.macro BASIC_STROUT_VECTOR_MACRO vector
	.if .paramcount <> 1
		.error  "Too few parameters for macro BASIC_STROUT_MACRO"
	.endif
    lda vector			; lsb
    ldy vector+1        ; msb
    jsr BASIC_STROUT
.endmacro
