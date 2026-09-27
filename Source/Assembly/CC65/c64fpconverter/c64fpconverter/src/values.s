.macpack longbranch

.include "labels_rom_kernal.s"
.include "macros_fp.s"
.include "labels_fp.s"
.include "../inc/layout.h"
.include "../inc/row_meta.h"

.import FP_TO_ASCII_SCI_V2, FP_TO_IEEE754, FP_TO_BASIC
.import prepare_message_line
.import recompute_decomp, draw_decomp

.export CalculatePosition
.export value_xval, value_yval
.export current_value
.export decimal_str, ieee754_bytes, basic_bytes
.export init_current_value
.export recompute_representations
.export draw_values
.export refresh_display

.segment "CODE"

; ============================================================
; FILE    : values.s
; PROJECT : Commodore 64 Floating Point Converter - Screen UI
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; Data layer: current_value plus its CACHED representations.
; recompute_representations is the ONLY place FP_TO_ASCII_SCI/
; FP_TO_IEEE754/FP_TO_BASIC get called from - see row_meta.s for
; why that matters.
;
; refresh_display IS THE ONE THING CALLERS SHOULD CALL after
; changing current_value - it does BOTH recompute and redraw, so
; there's no way to forget one. draw_values alone is for the
; "reject and revert" paths (convert.s/mathops.s failure cases):
; current_value didn't change there, so the cached buffers are
; still correct - just redraw them, don't recompute from a
; discarded/abandoned parse.
; ============================================================
.proc CalculatePosition
    ldy #layout_struct::own_line
    lda (CurrentEntry::e_ptr),y
    bne @own_line_case

    ldy #layout_struct::ymsg
    lda (CurrentEntry::e_ptr),y
    sta value_yval

    ldy #layout_struct::xmsg
    lda (CurrentEntry::e_ptr),y
    clc
    adc LayoutEntries::max_msg_len
    clc
    adc #1
    sta value_xval
    rts

@own_line_case:
    ldy #layout_struct::ymsg
    lda (CurrentEntry::e_ptr),y
    clc
    adc #1
    sta value_yval

    ldy #layout_struct::xmsg
    lda (CurrentEntry::e_ptr),y
    sta value_xval
    rts
.endproc

.segment "BSS"
value_xval:    .byte 0
value_yval:    .byte 0
current_value: .res 4,0
decimal_str:   .res 16,0   ; size for FP_TO_ASCII_SCI at X<=6.
                           ; X=7 needs 15+1=16 bytes exactly;
                           ; X=8 overflows -- widen if bumping.
ieee754_bytes: .res 4,0
basic_bytes:   .res 5,0
.segment "CODE"

.proc init_current_value
    ldx #3
@copy:
    lda initial_value,x
    sta current_value,x
    dex
    bpl @copy
    rts
.endproc

; ============================================================
; PROCEDURE : recompute_representations
; Purpose : Regenerate decimal_str/ieee754_bytes/basic_bytes from
;           current_value. woz/rankin and binary need no work
;           here - both read current_value directly.
; ============================================================
.proc recompute_representations
    FP_LOAD1_MACRO current_value
    jsr prepare_message_line
    FP_ERROR_INIT_MACRO @decimal_done
    lda #<decimal_str
    ldy #>decimal_str
    ldx #4
    jsr FP_TO_ASCII_SCI_V2
    FP_ERROR_CLEAR_MACRO
@decimal_done:

    FP_LOAD1_MACRO current_value
    jsr FP_TO_IEEE754              ; never traps - see lib_fp_ieee754.s
    lda FP1_EXP
    sta ieee754_bytes
    lda FP1_MANT
    sta ieee754_bytes+1
    lda FP1_MANT+1
    sta ieee754_bytes+2
    lda FP1_MANT+2
    sta ieee754_bytes+3

    FP_LOAD1_MACRO current_value
    jsr prepare_message_line
    FP_ERROR_INIT_MACRO @basic_done
    lda #<basic_bytes
    ldy #>basic_bytes
    jsr FP_TO_BASIC
    FP_ERROR_CLEAR_MACRO
@basic_done:

    jsr recompute_decomp
    rts
.endproc

; ============================================================
; PROCEDURE : draw_values
; Purpose : Redraw all five rows from whatever is CURRENTLY
;           cached - does NOT recompute anything.
; ============================================================
.proc draw_values
    lda #0
    sta @row_index

@row_loop:
    lda @row_index
    cmp LayoutEntries::l_entries
    bcs @done

    sta CurrentEntry::e_index
    jsr CurrentEntry::CalculateAddress
    jsr CalculatePosition

    ldy value_xval
    ldx value_yval
    clc
    jsr KERNAL_PLOT
    ldx @row_index
    lda RowMeta::display_width_table,x
    tax
@blank_loop:
    lda #' '
    jsr KERNAL_CHROUT
    dex
    bne @blank_loop

    ldy value_xval
    ldx value_yval
    clc
    jsr KERNAL_PLOT
    lda @row_index
    jsr RowMeta::print_row_value

    inc @row_index
    jmp @row_loop
@done:

    jsr draw_decomp
    rts

.segment "BSS"
@row_index: .byte 0
.segment "CODE"
.endproc

.proc refresh_display
    jsr recompute_representations
    jsr draw_values
;    jsr draw_decomp
    rts
.endproc

.segment "RODATA"
initial_value: .byte $00,$00,$00,$00
.segment "CODE"
