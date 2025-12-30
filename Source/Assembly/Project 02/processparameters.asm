!zone FETCHOPTIONPARAMETERS {
FetchOptionParameters:
	lda ParameterOption
	cmp #MAX_OPTIONS+1
    bcs .default		; if A >= Max+1 then it's > Max
	asl					; A = A * 2
	tax
	lda .Vectors,x		; lsb
	sta JumpVector
	lda .Vectors+1,x		; msb
	sta JumpVector+1
	jmp (JumpVector)    ; jump to selected case, rts is expected at each Vector

.default:
	+BASIC_STROUT_IMM Help
	rts
	
.case0:
.case1:
	; Parameter #2
	jsr BASIC_CHKCOM					; Skip passed ','
	jsr BASIC_FRMEVL					; Load FAC1
	+BASIC_MOVFM_IMM ParameterValue1	; Save FAC1
	rts
	
.case2:
.case3:
	; Parameter #2
	jsr BASIC_CHKCOM					; Skip passed ','
	jsr BASIC_FRMEVL					; Load FAC1
	+BASIC_MOVFM_IMM ParameterValue1	; Save FAC1
	
	; Parameter #3
	jsr BASIC_CHKCOM					; Skip passed ','
	jsr BASIC_PTRGET					; Variable
	sta ParameterVarPtr1				; LSB
	sty ParameterVarPtr1+1				; MSB
	
	rts
	
!address{
.Vectors:
        !word .case0
        !word .case1
        !word .case2
        !word .case3
}
}
