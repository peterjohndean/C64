;
; 64tass
; -a main.s -o c64xxd.prg --vice-labels --labels=vice.txt -Wunused -Wshadow -Woptimize -Wimmediate -Wcase-symbol
;
.cpu "6502"

*   =   $c000	; sys 49152

;
; entry
;
    jsr initialise
    jsr bank.romBasicOff
    
    jsr loadData
    sta file.error
    bne exit
    
    jsr setOutputFile.toOpen
    sta file.error
    bne exit
    
    jsr processData
    
    jsr setOutputFile.toClose
    jsr bank.romBasicOn
    
    lda #13
    jsr CHROUT
    
    lda file.ramLen+1
    jsr outputByteToHex
    lda file.ramLen
    jsr outputByteToHex
    
    lda #','
    jsr CHROUT
    
    lda file.origin+1
    jsr outputByteToHex
    lda file.origin
    jsr outputByteToHex
    
exit
    rts

;
; Required routines and labels
;
.include "labels.s"
.include "variables.s"
.include "file.s"
.include "bank.s"
.include "convert.s"
.include "process.s"
