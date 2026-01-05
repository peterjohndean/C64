;
; ZPVector2, FloatMemorySize
;
!zone FLOATTOHEXCHARACTERS {
OutputFloatToHexChars:
	ldy #0					; Index = 0
.loop:
	lda (ZPVector2),y		; (ZPVector2) + Y
	jsr OutputByteToHex
	iny
	cpy FloatMemorySize		; 5=Packed, 6=Unpacked
	bne .loop
	
	rts
}

;
; ZPVector, ZPVector2, FloatMemorySize
;
!zone FLOATTOHEXBASICSTRING {
!ifdef ZPVector2 {
FloatToHexBASICString:
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
	cpy FloatMemorySize		; 5=Packed, 6=Unpacked
	bne .loop
	
	rts
}
}