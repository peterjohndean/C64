
;===========================================================
; Macro: Load Integer from Memory (Variable)
; Usage: +BASIC_GIVAYF_MEM Ptr3
; eg. !address Ptr3 !word $0100
;	A = (Ptr3+1) = $00, Y = (Ptr3) = $01
;===========================================================
!macro BASIC_GIVAYF_MEM REF2AY {
	ldy REF2AY			; LSB
	lda REF2AY+1		; MSB
   	jsr BASIC_GIVAYF	; INT16 to FAC1
}

;===========================================================
; Macro: Load Integer Immediate (Fixed Number)
; Usage: +BASIC_GIVAYF_IMM $0007
; eg. A = $00, Y = $07
;===========================================================
!macro BASIC_GIVAYF_IMM REF2AY {
	ldy #<REF2AY		; LSB
    lda #>REF2AY		; MSB
    jsr BASIC_GIVAYF	; INT16 to FAC1
}

!macro BASIC_MOVFM_IMM REF2YX {
	ldx #<REF2YX	; LSB
    ldy #>REF2YX	; MSB
    jsr BASIC_MOVFM	; FAC1 → Memory (Y/X)
}

!macro BASIC_MOVMF_IMM REF2YA {
	lda #<REF2YA	; LSB
	ldy #>REF2YA	; MSB
	jsr BASIC_MOVMF	; Memory (Y/A) → FAC1
}

!macro BASIC_CONUPK_IMM REF2YA {
	lda #<REF2YA		; LSB
	ldy #>REF2YA		; MSB
	jsr BASIC_CONUPK	; Memory (Y/A) → FAC2
}

!macro BASIC_FDIV_IMM REF2YA {
	lda #<REF2YA	; LSB
    ldy #>REF2YA	; MSB
    jsr BASIC_FDIV	; Memory (Y/A) to FAC2, FAC1 = FAC2 ÷ FAC1
}

!macro BASIC_STROUT_IMM StrAddr {
	lda #<StrAddr		; LSB
    ldy #>StrAddr		; MSB
    jsr BASIC_STROUT	; Output zero/null terminated string
}

;===========================================================
; Macro: Load Integer from Memory (Variable)
; Usage: +BASIC_LINPRT_MEM Ptr3
; eg. !address Ptr3 !word $0100
;	A = (Ptr3+1) = $00, X = (Ptr3) = $01
;===========================================================
!macro BASIC_LINPRT_MEM REF2AX {
	ldx REF2AX			; LSB
    lda REF2AX+1		; MSB
    jsr BASIC_LINPRT	; UInt16
}

;===========================================================
; Macro: Load Integer Immediate (Fixed Number)
; Usage: +BASIC_LINPRT_IMM $0007
; eg. A = $07, X = $00
;===========================================================
!macro BASIC_LINPRT_IMM REF2AX {
	lda #<REF2AX		; LSB
    ldx #>REF2AX		; MSB
	jsr BASIC_LINPRT	; UInt16
}

;!macro BASIC_CLRFAC1 {
;	lda #$00
;	jsr BASIC_CLRFAC1
;	sta MM_FAC1+5
;}
