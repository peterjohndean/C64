; Load binary file directly into memory
; $0800 - $bfff ≈ 45k RAM (47,103 bytes)
setInputFile .proc
toLoad
    ; Set filename
    ldx #<file.input.name   ; lsb
    ldy #>file.input.name   ; msb
;    lda #len(file.input)
    lda file.input.len
    jsr KERNAL_SETNAM
    
    ; Set LFS
    lda #READ_LFN
    ldx #READ_DEV
    ldy #READ_ADR
    jsr KERNAL_SETLFS
    
    jsr KERNAL_OPEN     ; Open file
		
    jsr KERNAL_READST   ; Error check
    sta file.error
    beq _setChannel
    rts

_setChannel:
    ; Set as input channel
    ldx #READ_LFN
    jsr KERNAL_CHKIN
    
    ; Header: prgOriginal load address lsb/msb
    jsr KERNAL_CHRIN
    sta file.prgOrigin
    jsr KERNAL_CHRIN
    sta file.prgOrigin+1

    ; Prepare zero-page pointer for indirect indexed writes
    lda file.ramStart
    sta ZPVector
    lda file.ramStart+1
    sta ZPVector+1
    
_lloop
    jsr KERNAL_READST
    sta file.error
    bne _isEOF
    
    jsr KERNAL_CHRIN
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
    ; excludes the 2-byte prgOrigin address
    sec
    lda ZPVector
    sta file.ramEnd
    sbc file.ramStart
    sta file.ramLen     ; lsb
    lda ZPVector+1
    sta file.ramEnd+1
    sbc file.ramStart+1
    sta file.ramLen+1   ; msb
    
    ; Close
    jsr KERNAL_CLRCHN
    lda #READ_LFN
    jmp KERNAL_CLOSE
.endproc

setOutputFile .proc
toOpen
    ; Set filename
;    ldx #<file.output       ; lsb
;    ldy #>file.output       ; msb
;    lda #len(file.output)
    ldx #<output       ; lsb
    ldy #>output       ; msb
    lda #len(output)
    jsr KERNAL_SETNAM
    
    ; Set LFS
    lda #WRITE_LFN
    ldx #WRITE_DEV
    ldy #WRITE_ADR
    jsr KERNAL_SETLFS
    
    jsr KERNAL_OPEN		; Open file
		
    jsr KERNAL_READST		; Error check
    sta file.error
    beq _setChannel
    rts

_setChannel:
    ; Set for ASCII lowercase
    lda #$26
    sta outputByteToHex.adcRef
    
    ; Set as output channel
    ldx #WRITE_LFN
    jmp KERNAL_CHKOUT
    
toClose
    ; Set for PETSCII
    lda #$06
    sta outputByteToHex.adcRef
    
    ; Close
    jsr KERNAL_CLRCHN
    lda #WRITE_LFN
    jmp KERNAL_CLOSE
;    rts
.endproc
