
!zone PROCESSOPTION {
ProcessOption:
	; Original option
	lda ParameterOption
	
	cmp #MAX_OPTIONS+1
    bcs .default		; if A >= Max+1 then it's > Max
	asl					; A = A * 2
	tax
	lda .Vectors,x		; lsb
	sta ZPVector
	lda .Vectors+1,x	; msb
	sta ZPVector+1
	jmp (ZPVector)    ; jump to selected case (no RTS expected)

.default:
	;+BASIC_STROUT_IMM Help
	rts

.case0:
	+BASIC_MOVMF_IMM ParameterValue1	; Restore
	lda #<MM_FAC1
	ldy #>MM_FAC1
	jsr OutputFloatUnpackedToHex
	;jsr BASIC_GOCR
	rts
	
.case1:
	+BASIC_MOVMF_IMM ParameterValue1	; Restore
	+BASIC_MOVFM_IMM CustomValue		; Save
	lda #<CustomValue
	ldy #>CustomValue
	jsr OutputFloatPackedToHex
	;jsr BASIC_GOCR
	rts
	
.case2:
	; Float to Int8 to var ..%
	lda ParameterVarPtr1
	sta ZPVector
	lda ParameterVarPtr1+1
	sta ZPVector+1
	
	+BASIC_MOVMF_IMM ParameterValue1	; Restore
	jsr FLOATTOINT8						; Convert FAC1 to Int8 (A)
	
	; Save as big-endian
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
	; Float to Int16 to var ..%
	lda ParameterVarPtr1
	sta ZPVector
	lda ParameterVarPtr1+1
	sta ZPVector+1
	
	+BASIC_MOVMF_IMM ParameterValue1	; Restore
	jsr FLOATTOINT16					; Convert FAC1 to Int16 (A/Y)
	
	; Save as big-endian
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