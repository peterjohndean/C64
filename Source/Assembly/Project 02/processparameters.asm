!zone PROCESSPARAMETERS {
ProcessParameters:
; Approached it as if it was like a swift SWITCH statement,
;
; switch ParameterOption {
; case0:
;	rts
; ...
; default:
;	rts
; }
;

	; Fetch parameters base on option selected
	lda ParameterOption
	cmp #MAX_OPTIONS+1	; Sanity check.
    bcs .default		; if A >= Max+1 then it's > Max
	asl					; A = A * 2
	tax
	lda .Vectors,x		; lsb
	sta ZPVector
	lda .Vectors+1,x	; msb
	sta ZPVector+1
	jmp (ZPVector)    	; jump to selected case, rts is expected at each Vector

.default:
	rts
	
.case0:
.case1:
.case2:
.case3:
	; Parameter #2
	jsr BASIC_CHKCOM					; Skip passed ','
	jsr BASIC_FRMEVL					; Load FAC1
	+BASIC_MOVFM_IMM ParameterValue1	; Save FAC1
	
	; Parameter #3
	jsr BASIC_CHKCOM					; Skip passed ','
	jsr BASIC_PTRGET					; String Variable
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
