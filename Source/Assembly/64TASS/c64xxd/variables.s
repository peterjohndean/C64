;

initialise
    ; Clear error status
    lda #0
    sta KERNAL_STATUS
    rts

def_file .struct
ramStart    .addr $0800 ; Vector RAM start address for binary program
ramEnd      .addr $0000 ; Vector RAM end address for binary program
ramLen      .addr $0000 ; Vector RAM length
prgOrigin   .addr $0000 ; binary program origin/load/entry address
prgAddr     .addr $0000 ; binary program address counter
error       .byte $00   ; error code
input       .dstruct def_filename           ; user source file
output      .text "@0:outputhex.txt,s,w"    ; fixed output file
.endstruct

def_filename .struct
name        .fill 25    ; Reserved bytes for filename including any DOS directives
len         .byte $00   ; Length of filename
.endstruct

file .dstruct def_file  ; Create instance

