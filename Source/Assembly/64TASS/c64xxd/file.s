; Load binary file directly into memory
; $0800 - $bfff ≈ 45k RAM (47,103 bytes)
loadData .proc
    ; Set filename
    ldx #<file.input
    ldy #>file.input
    lda #len(file.input)
    jsr SETNAM
    
    ; Set LFS
    lda #READ_LFN
    ldx #READ_DEV
    ldy #READ_ADR
    jsr SETLFS
    
    jsr OPEN		; Open file
		
    jsr READST		; Error check
    sta file.error
    beq _setChannel
    rts

_setChannel:
    ; Set as input channel
    ldx #READ_LFN
    jsr CHKIN
    
    ; Header: Original load address lsb/msb
    jsr CHRIN
    sta file.origin
    jsr CHRIN
    sta file.origin+1

    ; Prepare zero-page pointer for indirect indexed writes
    lda file.ramStart
    sta ZPVector
    lda file.ramStart+1
    sta ZPVector+1
    
_lloop
    jsr READST
    sta file.error
    bne _isEOF
    
    jsr CHRIN
    ldy #0
    sta (ZPVector),y

    ; Advance destination pointer
    inc ZPVector
    bne _lloop
    inc ZPVector+1
    bne _lloop
    
_isEOF
    and #%01000000  ; Check bit 6 (EOF)
;    beq _error

;_error
;_exit
    ; Calculate Length (End Address - Start Address)
    ; excludes the 2-byte origin address
    sec
    lda @b ZPVector
    sta file.ramEnd
    sbc file.ramStart
    sta file.ramLen     ; lsb
    lda @b ZPVector+1
    sta file.ramEnd+1
    sbc file.ramStart+1
    sta file.ramLen+1   ; msb
    
    ; Close
    jsr CLRCHN
    lda #READ_LFN
    jmp CLOSE
.endproc

setOutputFile .proc
toOpen
    ; Set filename
    ldx #<file.output
    ldy #>file.output
    lda #len(file.output)
    jsr SETNAM
    
    ; Set LFS
    lda #WRITE_LFN
    ldx #WRITE_DEV
    ldy #WRITE_ADR
    jsr SETLFS
    
    jsr OPEN		; Open file
		
    jsr READST		; Error check
    sta file.error
    beq _setChannel
    rts

_setChannel:
    ; Set for ASCII lowercase
    lda #$26
    sta outputByteToHex.adcRef
    
    ; Set as output channel
    ldx #WRITE_LFN
    jmp CHKOUT
    
toClose
    ; Set for PETSCII
    lda #$06
    sta outputByteToHex.adcRef
    
    ; Close
    jsr CLRCHN
    lda #WRITE_LFN
    jsr CLOSE
    rts
.endproc
