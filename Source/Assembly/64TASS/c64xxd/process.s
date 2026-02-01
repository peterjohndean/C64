processData .proc

; xxxx: xxxx xxxx xxxx xxxx xxxx xxxx
    ;
    lda file.origin
    sta file.offset
    lda file.origin+1
    sta file.offset+1
    
    ;
    ; Prepare zero-page pointer for indirect indexed reads
    lda file.ramStart
    sta ZPVector
    lda file.ramStart+1
    sta ZPVector+1
    
_oloop
    ;
    lda #13
    jsr CHROUT
    
    ; Output address
    lda file.offset+1
    jsr outputByteToHex
    lda file.offset
    jsr outputByteToHex
    lda #':'
    jsr CHROUT

    ldy #0
    ldx #8
    
_iloop
    lda (ZPVector),y
    jsr outputByteToHex
    jsr incVector
    bcs _end
    
    jsr incOffset
    
    lda (ZPVector),y
    jsr outputByteToHex
    jsr incVector
    bcs _end
    
    jsr incOffset
    
    lda #' '
    jsr CHROUT
    
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
    lda @b ZPVector     ; lsb
    cmp file.ramEnd
    lda @b ZPVector+1   ; msb
    sbc file.ramEnd+1
    rts
.endproc

incOffset .proc
    inc file.offset
    bne +
    inc file.offset+1
+
    rts
.endproc

