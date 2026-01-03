!zone FLOATPACKEDTOHEX {
OutputFloatPackedToHex:
	sta ZPVector
	sty ZPVector+1
	
	; Output Packed floating point
	+KERNEL_CHROUT_IMM 'P'
	+KERNEL_CHROUT_IMM '['
	
	ldy #0					; Index at 0
	lda (ZPVector),y		; (ZPVector) + Y
	jsr OutputByteToHex
	
	+KERNEL_CHROUT_IMM ']'
	
	ldy #1					; Index at 1
.loop:
	+KERNEL_CHROUT_IMM ' '	; leading space before each subsequent byte
	lda (ZPVector),y		; (ZPVector) + Y
	jsr OutputByteToHex
	iny
	cpy #5					; (0..4) EXP M1 M2 M3 M4
	bne .loop
	
	rts
}

!zone FLOATUNPACKEDTOHEX {
OutputFloatUnpackedToHex:
	sta ZPVector
	sty ZPVector+1
	
	; Output Packed floating point
	ldy #0					; Index = 0
.loop:
	lda (ZPVector),y		; (ZPVector) + Y
	jsr OutputByteToHex
	iny
	cpy #6					; (0..5) EXP M1 M2 M3 M4 SIGN
	bne .loop
	
	rts
}

!zone FLOATUNPACKEDTOHEXBASICSTRING {
!ifdef ZPVector2 {
FloatUnpackedToHexBASICString:
	ldy #0					; Index at 0
.loop:
	tya
	pha						; Preserve Y
	lda (ZPVector2),y		; (ZPVector2) + Y
	
	tax
	tya
	asl						; Adjust index, Y = Y * 2
	tay
	txa
	jsr ByteToHexBASICString
	pla
	tay						; Restore Y
	
	iny
	cpy #6					; (0..5) EXP M1 M2 M3 M4 SIGN
	bne .loop
	
	rts
}
}