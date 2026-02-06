;
; 64tass -a main.s -o c64xxd.prg --vice-labels --labels=vice.txt -Wunused -Wshadow -Woptimize -Wcase-symbol
;
.cpu "6502"

*   =   $c000    ; sys 49152

;
; LOAD "C64XXD.PRG",10,1: NEW: SYS49152,"FILENAME"  - BASIC 2.0
; %"FILENAME",10: SYS49152,"FILENAME"               - JiffyDOS v6.x
;

    ;
    ; Process
    ;
    jsr initialise
    jsr sysParameters.count
    beq exit
    jsr sysParameters.parse

    jsr bank.romBasicOff
    
    jsr setInputFile.toLoad
    sta file.error
    bne exit
    
    ;
    ; Output: File
    ;
    jsr setOutputFile.toOpen
    sta file.error
    bne exit
    
    jsr processData
    
    jsr setOutputFile.toClose
    jsr bank.romBasicOn
    
    ;
    ; Output: Screen
    ;
    lda #13
    jsr KERNAL_CHROUT
    
    lda file.ramLen+1
    jsr outputByteToHex
    lda file.ramLen
    jsr outputByteToHex
    
    lda #','
    jsr KERNAL_CHROUT
    
    lda file.prgOrigin+1
    jsr outputByteToHex
    lda file.prgOrigin
    jsr outputByteToHex
    
exit
    rts

;
; Required routines and labels
;
.include "labels.s"
.include "c64_memory.s"
.include "c64_basic.s"
.include "c64_kernel.s"
.include "c64_bank.s"
.include "variables.s"
.include "file.s"
.include "convert.s"
.include "process.s"
.include "parameters.s"
