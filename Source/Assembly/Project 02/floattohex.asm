!zone FLOATPACKEDTOHEX {
OutputFloatPackedToHex:
	sta JumpVector
	sty JumpVector+1
	
	; Output Packed floating point
	+KERNEL_CHROUT_IMM 'P'
	+KERNEL_CHROUT_IMM '['
	
	ldy #0					; Index at 0
	lda (JumpVector),y		; (JumpVector) + Y
	jsr OutputByteToHex
	
	+KERNEL_CHROUT_IMM ']'
	
	ldy #1					; Index at 1
.loop:
	+KERNEL_CHROUT_IMM ' '	; leading space before each subsequent byte
	lda (JumpVector),y		; (JumpVector) + Y
	jsr OutputByteToHex
	iny
	cpy #5					; (0..4) EXP M1 M2 M3 M4
	bne .loop
	
	rts
}

!zone FLOATUNPACKEDTOHEX {
OutputFloatUnpackedToHex:
	sta JumpVector
	sty JumpVector+1
	
	; Output Packed floating point
	+KERNEL_CHROUT_IMM 'U'
	+KERNEL_CHROUT_IMM '['
	
	ldy #0					; Index at 0
	lda (JumpVector),y		; (JumpVector) + Y
	jsr OutputByteToHex
	
	+KERNEL_CHROUT_IMM ']'
	
	ldy #1					; Index at 1
.loop:
	+KERNEL_CHROUT_IMM ' '	; leading space before each subsequent byte
	lda (JumpVector),y		; (JumpVector) + Y
	jsr OutputByteToHex
	iny
	cpy #6					; (0..5) EXP M1 M2 M3 M4 SIGN
	bne .loop
	
	rts
}
