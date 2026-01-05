;
; TODO: Need to tidy this up, more doc and examples.
;

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

!macro UINT16_DIVMOD_IMM DIVIDEND, DIVISOR {
	; --- Dividend ---
	lda #<DIVIDEND		; LSB
    sta MATH_DIVIDEND
    lda #>DIVIDEND		; MSB
    sta MATH_DIVIDEND+1

    ; --- Divisor ---
    lda #<DIVISOR		; LSB
    sta MATH_DIVISOR
    lda #>DIVISOR		; MSB
    sta MATH_DIVISOR+1
    
    jsr UINT16_DIVMOD
}

!macro INT16_DIVMOD_IMM DIVIDEND, DIVISOR {
	; --- Dividend ---
	lda #<DIVIDEND		; LSB
    sta MATH_DIVIDEND
    lda #>DIVIDEND		; MSB
    sta MATH_DIVIDEND+1

    ; --- Divisor ---
    lda #<DIVISOR		; LSB
    sta MATH_DIVISOR
    lda #>DIVISOR		; MSB
    sta MATH_DIVISOR+1
    
    jsr INT16_DIVMOD
}

;===========================================================
; Macro: Load Integer Immediate (Fixed Number)
; Usage: +OUTPUT_BINARYBYTE_IMM '?'
; eg. A = $3f
;===========================================================
!macro OUTPUT_BINARYBYTE_IMM REF2A {
	lda #REF2A
    jsr OutputByteToBinary
}

;===========================================================
; Macro: Load Integer from Memory (Variable)
; Usage: +OUTPUT_BINARYBYTE_MEM Ptr3
; eg. !address Ptr3 !word $0100
;	A = (Ptr3) = 00000001
;===========================================================
!macro OUTPUT_BINARYBYTE_MEM REF2A {
	lda REF2A				; LSB
	jsr OutputByteToBinary
}

;===========================================================
; Macro: Load Integer from Memory (Variable)
; Usage: +OUTPUT_BINARYWORD_MEM Ptr3
; eg. !address Ptr3 !word $0100
;	A = (Ptr3+1) = 00000000, A = (Ptr3) = 00000001
;===========================================================
!macro OUTPUT_BINARYWORD_MEM REF2A {
	lda REF2A+1				; MSB
    jsr OutputByteToBinary
    
	lda REF2A				; LSB
	jsr OutputByteToBinary
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

!macro OUTPUT_CUSTOMSTROUT_IMM StrAddr {
	lda #<StrAddr		; LSB
    ldy #>StrAddr		; MSB
    jsr CustomSTROUT	; Output zero/null terminated string
}

