;
; 64tass -a main.s -o c64xxd.prg --vice-labels --labels=vice.txt -Wunused -Wshadow -Woptimize -Wcase-symbol
;
.cpu "6502"

*   =   $c000    ; sys 49152

;
; LOAD "C64XXD.PRG",10,1: NEW: SYS49152,"FILENAME"  - BASIC 2.0
; %"FILENAME",10: SYS49152,"INPUT"                  - JiffyDOS v6.x
;

; TODO
; - Remove the parameter passing.
; - Remove fixed output file.
; - Add modern drive & file selection process
; - Add xxd options

    ;
    ; Process
    ;
    jsr initialise
    
    ; Minimum # of parameters
    jsr sysParameters.count
    lda param.count
    cmp #$01
    bne _parametermismatch

    ; Are valid parameters?
    jsr sysParameters.parse
    lda param.valid
    beq _parametermismatch
;    gne exit
    
    jsr bank.romBasicOff
    
    jsr setInputFile.toLoad
    sta file.error
    bne exit
    
    ;
    ; Output: File
    ;
;    lda param.count
;    cmp #$01
;    beq _toScreen
    
    jsr setOutputFile.toOpen
    sta file.error
    bne exit
    
    jsr processData
    
    jsr setOutputFile.toClose
    
;    jmp exit
;    
;_toScreen
;    jsr processData
    
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
    
_parametermismatch

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
