;

initialise
    ; Clear error status
    lda #0
    sta KERNAL_STATUS
    
    ; Clear parameters
    sta param.count
    sta param.valid
    
    ; Clear file
    lda #<file          ; lsb
    sta ZPVector2
    lda #>file+1        ; msb
    sta ZPVector2+1
    ldy #size(file)-1   ; length/size of file struct
    lda #$00
    
_clearloop
    sta (ZPVector2),y
    dey
    bpl _clearloop      ; Is positive (0-127)?
    
    ; Set RAM start address $0800
    lda #<$0800
    sta file.ramStart
    lda #>$0800
    sta file.ramStart+1
    
    rts

def_param .struct
count   .byte $00       ; Parameter count
valid   .byte $00       ; Valid parameter(s)
.endstruct

def_file .struct
ramStart    .addr $0800 ; Vector RAM start address for binary program
ramEnd      .addr $0000 ; Vector RAM end address for binary program
ramLen      .addr $0000 ; Vector RAM length
prgOrigin   .addr $0000 ; binary program origin/load/entry address
prgAddr     .addr $0000 ; binary program address counter
error       .byte $00   ; error code
input       .dstruct def_filename           ; user source file
;output      .dstruct def_filename           ; user output file
.endstruct

def_filename .struct
name        .fill 25    ; Reserved bytes for filename including any DOS directives
len         .byte $00   ; Length of filename
.endstruct

file .dstruct def_file      ; Create instance
param .dstruct def_param    ; Create instance
output      .text "@0:outputhex.txt,s,w"    ; fixed output file
