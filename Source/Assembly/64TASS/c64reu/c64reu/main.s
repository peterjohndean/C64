
.cpu "6502"

;* = $c000   ; sys 49152
* = $0801   ; run

; ---------------------------------------------------------------------------
; BASIC stub — generates the one-line BASIC program:  10 SYS xxxx
;
; When RUN is typed, BASIC executes SYS xxxx which transfers control to the
; machine code entry point.
;
; BASIC line structure in memory:
;   word  : pointer to the next line (little-endian)
;   word  : line number (little-endian)
;   bytes : tokenised BASIC content
;   $00   : end-of-line terminator
; ---------------------------------------------------------------------------
;stub_start:
        .word   stub_end                ; pointer to the next BASIC line
        .word   10                      ; BASIC line number 10
        .byte   $9e                     ; BASIC token for SYS
        .text   format("%d", entry)     ; decimal string of 'entry' address
                                        ; format() is evaluated at assemble-time
                                        ; across 64TASS's multi-pass resolution
        .byte   0                       ; end-of-line terminator

stub_end:
        .word   0               ; null next-line pointer — end of BASIC program

entry:
    jsr reu_init
;
    lda REU_STATUS
    jsr OutputByteToBinary
    jsr BASIC_GOCR
    
    #REU_QUICK_DETECT no_reu
    
    jsr Output_ByteToHex
    #BASIC_STROUT_MACRO msgFound
    
    ; Store a message into REU
    #REU_FROM_C64 $100000, msg, msg_end - msg
    jsr REU_WAIT_EOB_PROC
    
    ; Clear the source area
    ldx #0
    lda #$20                ; Space character
clr
    sta msg,x
    inx
    cpx #(msg_end - 1 - msg)
    bne clr

    ; Make sure only spaces are output
    #BASIC_STROUT_MACRO msg
    jsr BASIC_GOCR
    
    ; Retrieve it back
    #REU_TO_C64 $100000, msg, msg_end - msg
    jsr REU_WAIT_EOB_PROC
    #BASIC_STROUT_MACRO msg
    
no_reu
    rts

msgFound    .null " reu detected", 13
msg         .null "hello from reu!", 13
msg_end

;
; Required labels, macros and routines
;
.include "labels_reu.s"
.include "labels_rom_basic.s"
.include "macros_rom_basic.s"
.include "labels_rom_kernel.s"
.include "macros_reu.s"
.include "convert.s"

.include "reusize.s"
