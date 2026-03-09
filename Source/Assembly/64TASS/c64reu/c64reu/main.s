
.cpu "6502"

* = $0801   ; run

.comment
 ---------------------------------------------------------------------------
 BASIC stub — generates the one-line BASIC program:  10 SYS xxxx

 When RUN is typed, BASIC executes SYS xxxx which transfers control to the
 machine code entry point.

 BASIC line structure in memory:
   word  : pointer to the next line (little-endian)
   word  : line number (little-endian)
   bytes : tokenised BASIC content
   $00   : end-of-line terminator
 ---------------------------------------------------------------------------
.endcomment
stub_start
        .word   stub_end                ; pointer to the next BASIC line
        .word   10                      ; BASIC line number 10
        .byte   $9e                     ; BASIC token for SYS
        .text   format("%d", entry)     ; decimal string of 'entry' address
                                        ; format() is evaluated at assemble-time
                                        ; across 64TASS's multi-pass resolution
        .byte   0                       ; end-of-line terminator

stub_end:
        .word   0               ; null next-line pointer — end of BASIC program

entry
;
;
    lda REU_STATUS
    jsr OUTPUT_BYTETOBINARY_PROC
    jsr BASIC_GOCR
    
    #REU_QUICK_DETECT no_reu
    #BASIC_STROUT_MACRO msgFound
    
    jsr OUTPUT_BYTETOHEX_PROC
    jsr BASIC_GOCR
    
    sei
    jsr REU_ALIASING_DETECT_PROC
    cli
    jsr OUTPUT_BYTETOHEX_PROC
    jsr BASIC_GOCR
    
    sei
    jsr REU_DETECT_SIZE_PROC
    cli
    jsr BITWISE_MULTIPLY_64_PROC
    jsr BASIC_LINPRT
    jsr BASIC_GOCR
   
no_reu
    rts

msgFound    .null "reu detected", 13

;
; Required labels, macros and routines
;
.include "labels_rom_basic.s"
.include "macros_rom_basic.s"
;
.include "labels_rom_kernal.s"
;
.include "labels_reu.s"
.include "macros_reu.s"
;
.include "library_convert.s"
.include "library_bitwise.s"
.include "library_reu.s"
