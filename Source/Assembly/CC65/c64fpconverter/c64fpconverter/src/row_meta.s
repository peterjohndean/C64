.include "labels_rom_kernal.s"
.include "labels_fp.s"
.include "../inc/values.h"

.import OUTPUT_BYTETOHEX, OUTPUT_BYTETOBINARY

.export row_format_kind, row_byte_count, row_data_lo, row_data_hi
.export display_width_table, edit_max_table, group_mask_table
.export print_row_value

.segment "CODE"

; ============================================================
; FILE    : row_meta.s
; PROJECT : Commodore 64 Floating Point Converter - Screen UI
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : CC65 tools, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; Single source of truth for "what does row N's value look like".
; load_edit_buffer (the "hold previous value" feature) was tried
; and removed - see project conversation: it caused more confusion
; in practice than it solved. Edit mode now always starts from an
; empty field again; this file only needs the read/print direction.
; ============================================================

.segment "RODATA"
FMT_ASCII = 0
FMT_HEX   = 1
FMT_BITS  = 2

row_format_kind: .byte FMT_ASCII, FMT_BITS, FMT_HEX, FMT_HEX, FMT_HEX
row_byte_count:  .byte 0,         4,        4,       5,       4
row_data_lo:
    .byte <LayoutValues::decimal_str
    .byte <LayoutValues::current_value
    .byte <LayoutValues::current_value
    .byte <LayoutValues::basic_bytes
    .byte <LayoutValues::ieee754_bytes
row_data_hi:
    .byte >LayoutValues::decimal_str
    .byte >LayoutValues::current_value
    .byte >LayoutValues::current_value
    .byte >LayoutValues::basic_bytes
    .byte >LayoutValues::ieee754_bytes

edit_max_table:      .byte 11, 32, 8, 10, 8
display_width_table: .byte 11, 35, 11, 14, 11
group_mask_table:    .byte 0,  7,  1, 1,  1
.segment "CODE"

; ============================================================
; PROCEDURE : print_row_value
; ============================================================
.proc print_row_value
    tax
    lda row_format_kind,x
    cmp #FMT_ASCII
    beq @ascii
    cmp #FMT_BITS
    beq @bits
    jmp @hex

@ascii:
    lda row_data_lo,x
    sta FP_STRPTR
    lda row_data_hi,x
    sta FP_STRPTR+1
    ldy #0
@ascii_loop:
    lda (FP_STRPTR),y
    beq @done
    jsr KERNAL_CHROUT
    iny
    jmp @ascii_loop

@hex:
    lda row_data_lo,x
    sta FP_STRPTR
    lda row_data_hi,x
    sta FP_STRPTR+1
    lda row_byte_count,x
    sta @remaining
    ldy #0
@hex_loop:
    lda (FP_STRPTR),y
    jsr OUTPUT_BYTETOHEX
    iny
    dec @remaining
    beq @done
    lda #' '
    jsr KERNAL_CHROUT
    jmp @hex_loop

@bits:
    lda row_data_lo,x
    sta FP_STRPTR
    lda row_data_hi,x
    sta FP_STRPTR+1
    lda row_byte_count,x
    sta @remaining
    ldy #0
@bits_loop:
    lda (FP_STRPTR),y
    jsr OUTPUT_BYTETOBINARY
    iny
    dec @remaining
    beq @done
    lda #' '
    jsr KERNAL_CHROUT
    jmp @bits_loop

@done:
    rts

.segment "BSS"
@remaining: .byte 0
.segment "CODE"
.endproc
