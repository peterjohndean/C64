; =============================================================================
; CC65 / CA65 Commodore 64 Boilerplate Template
; =============================================================================

; Enable special processing features and CBM-specific configuration extensions
;.features	on
;.cbm		on
.setcpu		"6502"
.import test_editor

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
    jsr test_editor

    rts             ; Safe return to BASIC (if loop is bypassed)
.endproc
