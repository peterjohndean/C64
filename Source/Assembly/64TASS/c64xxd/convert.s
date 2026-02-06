; -----------------------------------------------------------------
; Output the byte in A as 8-bit binary ASCII characters to channel.
; Input: A = byte to convert and output
; Destroys: A
; -----------------------------------------------------------------
;outputByteToBinary .proc
;    ldx #7				; 8 bits to output
;_loop
;    asl					; Shift left, MSB → Carry
;    pha					; Save A
;    lda #0
;    adc #'0'			; Convert carry to '0' or '1'
;    jsr KERNAL_CHROUT			; Output binary value
;    pla					; Restore A
;    dex
;    bpl _loop
;    rts
;    .endproc

; ------------------------------------------------------------
; Output the byte in A as two hex ASCII characters to channel.
; Input: A = byte to convert and output
; Destroys: A
; ------------------------------------------------------------
outputByteToHex .proc
    pha					; Preserve prgOriginal A
    lsr					; Shift upper nibble into lower 4 bits
    lsr
    lsr
    lsr
    jsr _OutputNibble	; Output high nibble
    pla
    and #$0F			; Mask to get low nibble
    
; ------------------------------------------------------------
; Convert nibble in A to ASCII hex, output via KERNAL_CHROUT
; ------------------------------------------------------------
_OutputNibble
    ora #$30	; Add ASCII '0'
    cmp #$3A 	; If >= '9'+1
    bcc _Output	; ...then it's 0–9
;    adc #$06	; else convert to A–F
    adc adcRef
    			; C=1 from CMP, so effectively adds 7
_Output:
    jmp KERNAL_CHROUT	; Output nibble, the kernel routine will rts
    
adcRef  .byte   $06 ; $06 for PETSCII/ASCII uppercase, $26 for ASCII lowercase
.endproc

