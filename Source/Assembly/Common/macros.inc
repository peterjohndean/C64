; ------------------------------------------------------------
; CMP16 zp1, zp2
; ------------------------------------------------------------
; Compares two 16-bit values stored at zero-page addresses zp1 and zp2.
;
; Affected flags:
;   Z = 1 if equal, 0 if not equal
;   C = 1 if zp1 >= zp2, 0 if zp1 < zp2  (unsigned)
;   N, V reflect signed comparison result
;   A modified, X/Y unchanged
;
; Usage examples:
;   value1 !word $1234
;   value2 !word $5678
;
; For UNSIGNED comparisons (0–65535):
;   +CMP16 value1, value2
;   bcc value1_lower      ; C=0 → value1 < value2
;   bcs value1_higher_eq  ; C=1 → value1 ≥ value2
;   beq values_equal      ; Z=1 → equal
;   bne values_not_equal  ; Z=0 → not equal
;
; For SIGNED comparisons (−32768 to +32767):
;   +CMP16 value1, value2
;   bvc no_overflow       ; V=0 → no overflow
;   bvs overflow          ; V=1 → overflow occurred
;   bmi less_than         ; (N⊕V)=1 → value1 < value2
;   bpl greater_or_equal  ; (N⊕V)=0 → value1 ≥ value2
;
; Internal operation:
;   A = A - M - (1 - C), where M = byte from zp2/zp2+1
; ------------------------------------------------------------
!macro CMP16 zp1, zp2 {
    lda zp1		; load LSB of zp1
    cmp zp2		; compare with LSB of zp2, sets C
    lda zp1+1	; load MSB of zp1
    sbc zp2+1	; subtract MSB with borrow
}

; ------------------------------------------------------------
; SUB16 zpMinuend, zpSubtrahend, difference
; ------------------------------------------------------------
; Subtracts two 16-bit values stored at zero-page addresses.
; Performs: difference = zpMinuend - zpSubtrahend
;
; Affected flags:
;   C = 1 if minuend >= subtrahend (unsigned), 0 if borrow needed
;   V = 1 if signed overflow occurred, 0 otherwise  
;   N = 1 if result is negative (bit 7 of MSB set), 0 if positive
;   Z = set based on MSB only (not full 16-bit result)
;
; Usage examples:
;   value1 !word $1234
;   value2 !word $5678
;   value3 !word $0000
;
; For UNSIGNED comparisons (0-65535):
;   +SUB16 value1, value2, value3
;   bcs value1_ge          ; C=1 → value1 >= value2
;   bcc value1_lt          ; C=0 → value1 < value2
;
; For SIGNED comparisons (-32768 to +32767):
;   +SUB16 value1, value2, value3
;   bvs overflow           ; V=1 → signed overflow occurred
;   bmi result_negative    ; N=1 → result is negative
;   bpl result_positive    ; N=0 → result is positive
;
; Notes:
; - For full 16-bit zero check: LDA difference ORA difference+1 BEQ
; i.e.
;	lda difference
;	ora difference+1
;	beq result_is_zero
; - For signed comparisons: use (N ⊕ V) to determine relative order
; - A is modified, X/Y preserved
; ------------------------------------------------------------
!macro SUB16 zpMinuend, zpSubtrahend, difference {
	sec
	
	; LSB
	lda zpMinuend
    sbc zpSubtrahend
    sta difference
    
    ; MSB
    lda zpMinuend+1
    sbc zpSubtrahend+1
    sta difference+1
}

; Same as SUB16, except Subtrahend is a fixed value and not an address
!macro SUB16_IMM zpMinuend, Subtrahend, difference {
    sec             ; Set carry for subtraction
    
    ; --- LSB ---
    lda zpMinuend
    sbc #<Subtrahend    ; Subtract the LOW byte of the value
    sta difference
    
    ; --- MSB ---
    lda zpMinuend+1
    sbc #>Subtrahend    ; Subtract the HIGH byte of the value
    sta difference+1
}

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
; Macro: Load Integer Immediate (Fixed Number)
; Usage: +KERNEL_CHROUT_IMM '?'
; eg. A = $3f
;===========================================================
!macro KERNEL_CHROUT_IMM REF2A {
	lda #REF2A
    jsr KERNEL_CHROUT
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

!macro OUTPUT_HEXBYTE VariableAddress {
	lda VariableAddress
    jsr OutputByteToHex
}

!macro OUTPUT_HEXWORD VariableAddress {
	lda VariableAddress+1		; MSB
    jsr OutputByteToHex
    lda VariableAddress			; LSB
    jsr OutputByteToHex
}

;!macro BASIC_CLRFAC1 {
;	lda #$00
;	jsr BASIC_CLRFAC1
;	sta MM_FAC1+5
;}
