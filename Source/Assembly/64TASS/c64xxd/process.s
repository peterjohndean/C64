processData .proc

; xxxx: xxxx xxxx xxxx xxxx xxxx xxxx
    ;
    lda file.prgOrigin
    sta file.prgAddr
    lda file.prgOrigin+1
    sta file.prgAddr+1
    
    ;
    ; Prepare zero-page pointer for indirect indexed reads
    lda file.ramStart
    sta ZPVector
    lda file.ramStart+1
    sta ZPVector+1
    
_oloop
    ;
    lda #13
    jsr KERNAL_CHROUT
    
    ; Output address
    lda file.prgAddr+1
    jsr outputByteToHex
    lda file.prgAddr
    jsr outputByteToHex
    lda #':'
    jsr KERNAL_CHROUT

    ldy #0
    ldx #8
    
_iloop
    lda (ZPVector),y
    jsr outputByteToHex
    jsr incVector
    bcs _end
    
    jsr incPrgAddr
    
    lda (ZPVector),y
    jsr outputByteToHex
    jsr incVector
    bcs _end
    
    jsr incPrgAddr
    
    lda #' '
    jsr KERNAL_CHROUT
    
    dex
    bne _iloop
;    jmp _oloop
    geq _oloop
    
_end
    rts
    
.endproc

incVector .proc
    inc ZPVector
    bne +
    inc ZPVector+1
+
    ; If C=0, ZPVector < file.ramEnd, elsif C=1, ZPVector >= file.ramEnd
    lda ZPVector     ; lsb
    cmp file.ramEnd
    lda ZPVector+1   ; msb
    sbc file.ramEnd+1
    rts
.endproc

incPrgAddr .proc
    inc file.prgAddr
    bne +
    inc file.prgAddr+1
+
    rts
.endproc

