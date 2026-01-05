
!zone PROCESSOPTION {
ProcessOption:
	; Original option
	lda ParameterOption
	
	cmp #MAX_OPTIONS+1	; Sanity check.
    bcs .default		; if A >= Max+1 then it's > Max
	asl					; A = A * 2
	tax
	lda .Vectors,x		; lsb
	sta ZPVector
	lda .Vectors+1,x	; msb
	sta ZPVector+1
	jmp (ZPVector)    ; jump to selected case (no RTS expected)

.default:
	rts

.case0:
	; Float (Unpacked) to String/Output
	lda #FLOAT_SIZE_UNPACKED			; (0..5) EXP M1 M2 M3 M4 SIGN
	sta FloatMemorySize
	
	; Source (Float): Setup ZP Vectors
	+BASIC_MOVMF_IMM ParameterValue1	; Restore
	lda #<MM_FAC1
	sta ZPVector2						; lsb
	lda #>MM_FAC1
	sta ZPVector2+1						; msb
	
	; Source (String): Setup ZP Vectors #1 - VARTAB string$
	lda ParameterVarPtr1
	sta ZPVector
	lda ParameterVarPtr1+1
	sta ZPVector+1
	
	; Sanity Check - string$ length
	ldy #0								; Index = 0
	lda (ZPVector),y					; Length
	cmp #FLOAT_SIZE_UNPACKED*2			; Min. Length
	bcc .nostore00						; A < Min. Length
	
	; Source (String): Setup ZP Vectors #2 - Get string$ vector
	ldy #1								; Index = 1
	lda (ZPVector),y
	tax
	iny									; Index = 2
	lda (ZPVector),y
	
	; Destination (String): Setup ZP Vectors #2 - Set string$ vector
	sta ZPVector+1						; msb
	txa
	sta ZPVector						; lsb
	
	; Convert & Store
	jsr FloatToHexBASICString
	
	rts

.nostore00:
	; BASIC string$ length doesn't meet minimum requirements.
	jsr OutputFloatToHexChars			; Output
	rts

.case1:
	; Float (Packed) to String/Output
	lda #FLOAT_SIZE_PACKED				; (0..4) EXP M1 M2 M3 M4
	sta FloatMemorySize
	
	; Source (Float): Setup ZP Vectors
	lda #<ParameterValue1
	sta ZPVector2						; lsb
	lda #>ParameterValue1
	sta ZPVector2+1						; msb
	
	; Source (String): Setup ZP Vectors #1 - VARTAB string$
	lda ParameterVarPtr1
	sta ZPVector
	lda ParameterVarPtr1+1
	sta ZPVector+1
	
	; Sanity Check - string$ length
	ldy #0								; Index = 0
	lda (ZPVector),y					; Length
	cmp #FLOAT_SIZE_PACKED*2			; Min. Length
	bcc .nostore01						; A < Min. Length
	
	; Source (String): Setup ZP Vectors #2 - Get string$ vector
	ldy #1								; Index = 1
	lda (ZPVector),y
	tax
	iny									; Index = 2
	lda (ZPVector),y
	
	; Destination (String): Setup ZP Vectors #2 - Set string$ vector
	sta ZPVector+1						; msb
	txa
	sta ZPVector						; lsb
	
	; Convert & Store
	jsr FloatToHexBASICString
	
	rts

.nostore01:
	; BASIC string$ length doesn't meet minimum requirements.
	jsr OutputFloatToHexChars			; Output
	rts


.case2:
	; Float to Int8 to Var%
	lda ParameterVarPtr1
	sta ZPVector
	lda ParameterVarPtr1+1
	sta ZPVector+1
	
	+BASIC_MOVMF_IMM ParameterValue1	; Restore
	jsr FLOATTOINT8						; Convert FAC1 to Int8 (A)
	
	; Save as big-endian, why CBM, why!
	; Oh, we are saving an 8-bit value, that expects it to be 16-bits
	ldy #$01							; Index
	sta (ZPVector),y					; Save lsb (..%)
	dey									; Index = Index + 1
	
	asl									; Bit 7 into carry
	lda #$FF							; Set msb for negative
	bcs .isnegative						; If C=1, then is negative
	lda #$00							; Set msb for positive

.isnegative:
	sta (ZPVector),y					; Save msb (..%)
	rts
	
.case3:
	; Float to Int16 to Var%
	lda ParameterVarPtr1
	sta ZPVector
	lda ParameterVarPtr1+1
	sta ZPVector+1
	
	+BASIC_MOVMF_IMM ParameterValue1	; Restore
	jsr FLOATTOINT16					; Convert FAC1 to Int16 (A/Y)
	
	; Save as big-endian, why CBM, why!
	pha
	tya
	ldy #$01							; Index
	sta (ZPVector),y					; Save lsb (..%)
	dey									; Index = Index + 1
	pla
	sta (ZPVector),y					; Save msb (..%)
	rts
	
.case4:
.case5:

	rts
	
!address{
.Vectors:
        !word .case0
        !word .case1
        !word .case2
        !word .case3
        !word .case4
        !word .case5
}
}