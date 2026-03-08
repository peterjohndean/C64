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
BASIC_STROUT_MACRO  .macro msg
    lda #<\msg          ; lsb
    ldy #>\msg          ; msb
    jsr BASIC_STROUT
.endmacro
