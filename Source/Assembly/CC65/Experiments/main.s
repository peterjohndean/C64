.setcpu "6502"

; Include parser definitions (These do not generate machine code)
.include "labels_rom_basic.s"
.include "macros_rom_basic.s"
.include "labels_rom_kernal.s"
.include "labels_reu.s"
.include "macros_reu.s"

; Import memory addresses from independently compiled libraries
.import OUTPUT_BYTETOBINARY, OUTPUT_BYTETOHEX
.import REU_ALIASING_DETECT
.import REU_DETECT_SIZE
.import BITWISE_MULTIPLY_64

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

; ---------------------------------------------------------------------------
; 3. Main Program Logic (SYS calls)
; ---------------------------------------------------------------------------
.segment "INIT"
entry:
    lda REU_STATUS
    jsr OUTPUT_BYTETOBINARY
    jsr BASIC_GOCR
    
    REU_QUICK_DETECT no_reu             
    BASIC_STROUT_MACRO msgFound         
    
    jsr OUTPUT_BYTETOHEX
    jsr BASIC_GOCR
    
    sei
    jsr REU_ALIASING_DETECT
    cli
    jsr OUTPUT_BYTETOHEX
    jsr BASIC_GOCR
    
    sei
    jsr REU_DETECT_SIZE
    cli
    jsr BITWISE_MULTIPLY_64
    jsr BASIC_LINPRT
    jsr BASIC_GOCR
   
no_reu:
    rts

; ---------------------------------------------------------------------------
; 4. Readonly Data
; ---------------------------------------------------------------------------
.segment "RODATA"
msgFound:
	.literal "REU DETECTED", $0d, $00
    ;.asciiz "REU DETECTED\n"
    ;.byte "REU DETECTED", 13, $00
