.include "macros_rom_kernal.s"
.include "macros_rom_basic.s"
.include "../inc/box.h"

.export draw_legend

.segment "RODATA"
legend1: .asciiz "crsr up/dn:select  return:edit  (q)uit"
legend2: .asciiz "(s)in  (c)os  (t)an  (l)n  lo(g)10"
legend3: .asciiz "(e)xp  (d)eg>rad  (r)ad>deg (p/P)rint"
legend4: .asciiz "range: 5.9e-39 to 3.4e+38, 5 sig figs"
.segment "CODE"

; ============================================================
; FILE    : legend.s
; PURPOSE
; -------
; Static, always-visible key reference - drawn once at startup,
; below message.s's error line so the two never collide.
; ============================================================
.proc draw_legend
    ldy #0
    ldx #BoxLayout::LEGEND_ROW1
    clc
    jsr KERNAL_PLOT
    BASIC_STROUT_MACRO legend1

    ldy #0
    ldx #BoxLayout::LEGEND_ROW2
    clc
    jsr KERNAL_PLOT
    BASIC_STROUT_MACRO legend2

    ldy #0
    ldx #BoxLayout::LEGEND_ROW3
    clc
    jsr KERNAL_PLOT
    BASIC_STROUT_MACRO legend3

    ldy #0
    ldx #BoxLayout::LEGEND_ROW4
    clc
    jsr KERNAL_PLOT
    BASIC_STROUT_MACRO legend4

    rts
.endproc
