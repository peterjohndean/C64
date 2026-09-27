.include "labels_screen.s"
.include "macros_rom_kernal.s"
.include "macros_rom_basic.s"

.export draw_box
.exportzp MSG_ROW, LEGEND_ROW1, LEGEND_ROW2, LEGEND_ROW3, LEGEND_ROW4

.segment "CODE"

; ============================================================
; FILE    : box.s
; PROJECT : Commodore 64 Floating Point Converter - Screen UI
; ============================================================
BOX_X0 = 0
BOX_X1 = 39
BOX_Y0 = 1
BOX_Y1 = 12
BOX_WIDTH           = BOX_X1 - BOX_X0 + 1
BOX_INTERIOR_WIDTH  = BOX_WIDTH - 2

TITLE_ROW     = BOX_Y0 + 1
SEPARATOR_ROW = TITLE_ROW + 1

; --- screen real estate BELOW the box: one dedicated line for
;     FP_ERROR_PROC's trapped-error text (see message.s and the
;     project conversation), then three lines for the always-
;     visible key legend (see legend.s). Deriving these from
;     BOX_Y1 rather than hardcoding fresh row numbers means they
;     automatically stay correct if the box's own height ever
;     changes again. ---
MSG_ROW      = BOX_Y1 + 1
LEGEND_ROW1  = MSG_ROW + 1
LEGEND_ROW2  = LEGEND_ROW1 + 1
LEGEND_ROW3  = LEGEND_ROW2 + 1
LEGEND_ROW4  = LEGEND_ROW3 + 1

.segment "RODATA"
title_text: .asciiz "fp format converter"
TITLE_LEN = .strlen("fp format converter")
TITLE_COL = BOX_X0 + 1 + ((BOX_INTERIOR_WIDTH - TITLE_LEN) / 2)

.segment "CODE"

.proc draw_box
    lda #BOX_Y0
    sta @hl_row
    lda #PETSCII_CORNER_TL
    sta @hl_left
    lda #PETSCII_LINE_HORIZONTAL
    sta @hl_fill
    lda #PETSCII_CORNER_TR
    sta @hl_right
    jsr @draw_hline

    lda #(BOX_Y0+1)
    sta @vl_row
@vwall_loop:
    lda @vl_row
    cmp #BOX_Y1
    bcs @vwall_done

    ldy #BOX_X0
    ldx @vl_row
    clc
    jsr KERNAL_PLOT
    lda #PETSCII_LINE_VERTICAL
    jsr KERNAL_CHROUT

    ldy #BOX_X1
    ldx @vl_row
    clc
    jsr KERNAL_PLOT
    lda #PETSCII_LINE_VERTICAL
    jsr KERNAL_CHROUT

    inc @vl_row
    jmp @vwall_loop
@vwall_done:

    ldy #TITLE_COL
    ldx #TITLE_ROW
    clc
    jsr KERNAL_PLOT
    BASIC_STROUT_MACRO title_text

    lda #SEPARATOR_ROW
    sta @hl_row
    lda #PETSCII_LINE_VERTICAL
    sta @hl_left
    lda #PETSCII_LINE_HORIZONTAL
    sta @hl_fill
    lda #PETSCII_LINE_VERTICAL
    sta @hl_right
    jsr @draw_hline

    lda #BOX_Y1
    sta @hl_row
    lda #PETSCII_CORNER_BL
    sta @hl_left
    lda #PETSCII_LINE_HORIZONTAL
    sta @hl_fill
    lda #PETSCII_CORNER_BR
    sta @hl_right
    jsr @draw_hline

    rts

@draw_hline:
    ldy #BOX_X0
    ldx @hl_row
    clc
    jsr KERNAL_PLOT

    lda @hl_left
    jsr KERNAL_CHROUT

    ldx #BOX_INTERIOR_WIDTH
@hl_fill_loop:
    lda @hl_fill
    jsr KERNAL_CHROUT
    dex
    bne @hl_fill_loop

    lda @hl_right
    jsr KERNAL_CHROUT
    rts

.segment "BSS"
@hl_row:   .byte 0
@hl_left:  .byte 0
@hl_fill:  .byte 0
@hl_right: .byte 0
@vl_row:   .byte 0
.segment "CODE"
.endproc
