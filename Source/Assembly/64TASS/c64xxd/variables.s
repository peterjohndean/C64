;

initialise
    ; Clear error status
    lda #0
    sta STATUS
    rts

def_file .struct
ramStart    .addr $0800 ; Vector RAM start address for binary program
ramEnd      .addr $0000 ; Vector RAM end address for binary program
ramLen      .addr $0000 ; Vector RAM length
origin      .addr $0000 ; binary program origin/load/entry address
offset      .addr $0000 ; ramStart
error       .byte $00   ; error code
input .text "dummy.bin"     ; our test filename
output .text "@0:dummy.txt,s,w"  ; our test filename
.endstruct

file .dstruct def_file  ; Instance
ZPVector = <FREKZP      ; zero-page pointer for indirect indexed read/writes
