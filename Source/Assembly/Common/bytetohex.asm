; ------------------------------------------------------------
; Output the byte in A as two hex ASCII characters to channel.
; Input:
;	A = byte to convert and output
; Destroys:
;	A
; ------------------------------------------------------------
!zone OUTPUTBYTEASASCIIHEX {
OutputByteToHex:
    pha					; Preserve original A
    lsr					; Shift upper nibble into lower 4 bits
    lsr
    lsr
    lsr
    jsr .OutputNibble	; Output high nibble
    pla
    and #$0F			; Mask to get low nibble
    
; ------------------------------------------------------------
; Convert nibble in A to ASCII hex, output via KERNEL_CHROUT
; ------------------------------------------------------------
.OutputNibble:
    ora #$30	; Add ASCII '0'
    cmp #$3A 	; If >= '9'+1
    bcc .Output	; ...then it's 0–9
    adc #$06	; else convert to A–F
    			; C=1 from CMP, so effectively adds 7
.Output:
    jmp KERNEL_CHROUT	; Output nibble, the kernel routine will rts
}

; ------------------------------------------------------------
; Convert byte to ASCII hex, Store to allocated BASIC string$.
; ------------------------------------------------------------
; Parameters
;	- ZPVector, pointer (lsb,msb) to start of allocated BASIC string$.
;	- Register Y, index
;	- Register A, value to be converted and stored
;
; Destroys:
;	- A, Y, X and (ZPVector)
; ------------------------------------------------------------
!zone STOREBYTETOASCIIHEXASBASICSTRING {
!ifdef ZPVector {
ByteToHexBASICString:
    pha					; Preserve original A
    lsr					; Shift upper nibble into lower 4 bits
    lsr
    lsr
    lsr
    jsr .ConvertNibble	; Output high nibble
    pla
    and #$0F			; Mask to get low nibble
    
; ------------------------------------------------------------
; Convert nibble in A to ASCII hex, store via BASIC string$
; ------------------------------------------------------------
.ConvertNibble:
    ora #$30			; Add ASCII '0'
    cmp #$3A 			; If >= '9'+1
    bcc .StoreNibble	; ...then it's 0–9
    adc #$06			; else convert to A–F
    					; C=1 from CMP, so effectively adds 7
.StoreNibble:
    sta (ZPVector),y	; Store nibble
    iny 				; Increment index
    rts
}
}
