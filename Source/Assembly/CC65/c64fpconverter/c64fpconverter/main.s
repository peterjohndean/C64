; =============================================================================
; CC65 / CA65 Commodore 64 Boilerplate Template
; =============================================================================

; Enable special processing features and CBM-specific configuration extensions
;.features	on
;.cbm		on
.setcpu		"6502"

.include "macros_rom_kernal.s"
.include "labels_screen.s"

.import draw_box
.import draw_layouts
.import refresh_display
.import nav_init, nav_poll
.import init_current_value
.import draw_legend
.import FP_CLEANUP_FAC1FAC2

; ---------------------------------------------------------------------------
; 1. PRG Header
; ---------------------------------------------------------------------------
.export __LOADADDR__       ; Tell ca65 to expose this symbol to the linker
.segment "LOADADDR"
__LOADADDR__:              ; Define the label at the exact start of the segment
        .word $0801

; ---------------------------------------------------------------------------
; 2. BASIC Stub
; ---------------------------------------------------------------------------
.segment "STARTUP"
stub_start:
        .word   stub_end
        .word   10
        .byte   $9e
        .byte   "2061"                  
        .byte   0                       
stub_end:
        .word   0

; -----------------------------------------------------------------------------
; INIT Segment: Mapped immediately following the STARTUP block ($080D / 2061)
; -----------------------------------------------------------------------------
.segment "INIT"

.proc main

    KERNAL_CHROUT_MACRO PETSCII_CLEAR

    jsr draw_box
    jsr draw_legend
    jsr draw_layouts
    jsr init_current_value
    jsr refresh_display
    jsr nav_init

@main_loop:
    jsr nav_poll

    cmp #'q'
    beq @exit
    cmp #'Q'
    beq @exit
    
    jmp @main_loop

@exit:
    jsr FP_CLEANUP_FAC1FAC2
    KERNAL_CHROUT_MACRO PETSCII_CLEAR
    rts
.endproc
