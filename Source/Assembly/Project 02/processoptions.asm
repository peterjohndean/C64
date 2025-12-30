
!zone PROCESSOPTION {
ProcessOption:
	; Original option
	lda ParameterOption
	
	cmp #MAX_OPTIONS+1
    bcs .default		; if A >= Max+1 then it's > Max
	asl					; A = A * 2
	tax
	lda .Vectors,x		; lsb
	sta JumpVector
	lda .Vectors+1,x	; msb
	sta JumpVector+1
	jmp (JumpVector)    ; jump to selected case (no RTS expected)

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
	+BASIC_MOVFM_IMM CustomValue	; Save
	lda #<CustomValue
	ldy #>CustomValue
	jsr OutputFloatPackedToHex
	;jsr BASIC_GOCR
	rts
	
.case2:
	; Not working yet!
	; Need to step through it
	lda ParameterVarPtr1
	sta JumpVector
	lda ParameterVarPtr1+1
	sta JumpVector
	
	+BASIC_MOVMF_IMM ParameterValue1	; Restore
	jsr FLOATTOINT8						; Convert FAC1 to Int8
	ldy #$01
	sta (JumpVector),y				; LSB
	dey
	lda #$00
	sta (JumpVector),y				; MSB
	rts
	
.case3:
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