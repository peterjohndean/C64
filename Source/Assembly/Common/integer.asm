;==========================================================
;  C64 MATHEMATICS INTEGERS
;----------------------------------------------------------
; MEMORY MAP:
; MATH_DIVIDEND		- Dividend & Quotient (Result of '/')
; MATH_DIVISOR		- Divisor
; MATH_REMAINDER	- Remainder (Result of '%')
;----------------------------------------------------------
; UINT16_DIVMOD, for 16-bit unsigned division & modulo
;  INT16_DIVMOD, for 16-bit   signed division & modulo
;==========================================================
!zone INTEGERS {

;==========================================================
; FAST MODULO 8 (2 to the power of 3)
; Equivalent to: Dividend % 8
;==========================================================
;FAST_MOD_8:
;    lda MATH_DIVIDEND       ; Load the low byte
;    and #%00000111      ; Keep only the bottom 3 bits (values 0-7)
;    sta MATH_REMAINDER
;    lda #0
;    sta MATH_REMAINDER+1    ; High byte of MOD 8 is always 0
;    rts
    
;==========================================================
; FAST DIVIDE BY 16 (2 to the power of 4)
; Equivalent to: Dividend / 16
;==========================================================
;FAST_DIV_16:
;    ldy #4              ; We want to shift 4 times (2^4 = 16)
;    
;.loop99:
;    lsr MATH_DIVIDEND+1     ; Shift High Byte Right. Bit 0 goes into Carry.
;    ror MATH_DIVIDEND       ; Rotate Low Byte Right. Carry goes into Bit 7.
;    dey
;    bne .loop99
;    rts

    
;==========================================================
; INT16/UINT16 DIVIDE & MODULO ROUTINES
;
; INPUTS:  MATH_DIVIDEND, MATH_DIVISOR
; OUTPUTS: MATH_DIVIDEND  = Quotient (Result of /)
;          MATH_REMAINDER = Remainder (Result of %)
; FLAGS:	C = 1, Divide by 0 Error
;			C = 0, No Error
;==========================================================
;----------------------------------------------------------
; UINT16 DIVIDE & MODULO ROUTINE
;----------------------------------------------------------
UINT16_DIVMOD:
	; Clear the Remainder
	lda #0              
    sta MATH_REMAINDER     	; LSB 
    sta MATH_REMAINDER+1	; MSB
    
    ; Check for divide by zero
    lda MATH_DIVISOR
    ora MATH_DIVISOR+1	; LSB OR'd MSB ≠ 0
    bne .u16_dm			; If result is NOT zero, divisor is safe

    sec                 ; Set Carry: Divide by Zero Error
    rts					; Return (Done/Finished)
    
.u16_dm:
      
    ldy #16             ; Set Loop Counter to 16 bits

.u16_dm_loop:
    ;--- STEP 1: 16-BIT SHIFT (Conveyor Belt) ---
    ; We shift the whole 32-bit chain (Dividend + Remainder) left,
    ; aka shift the Dividend and Remainder as one unit.
    asl MATH_DIVIDEND       ; Shift LSB of Dividend
    rol MATH_DIVIDEND+1     ; Rotate MSB (Carry moves from Low to High)
    rol MATH_REMAINDER      ; Rotate LSB of Remainder (Carry comes from Dividend)
    rol MATH_REMAINDER+1    ; Rotate MSB of Remainder
    ; The MSB of the Dividend is now in the LSB of the Remainder.  

    ;--- STEP 2: 16-BIT COMPARE ---
    ; Does Divisor fit into the current Remainder?
    lda MATH_REMAINDER
    sec						; Prepare carry for subtraction
    sbc MATH_DIVISOR		; Subtract LSB
    tax						; Store LSB result in X
    
    lda MATH_REMAINDER+1
    sbc MATH_DIVISOR+1		; Subtract MSB
    bcc .u16_dm_next		; If result is negative, Divisor > Remainder
    						; (If Rem > Div, Carry=1. If Rem < Div, Carry=0).
    
    ;--- STEP 3: COMMIT SUBTRACTION ---
    ; If we're here, the subtraction was successful.
    sta MATH_REMAINDER+1    ; Store MSB (already in A)
    stx MATH_REMAINDER      ; Store LSB (from X)
    
    inc MATH_DIVIDEND       ; Set the Quotient bit to 1
							; This turns Modulo into a Divide!
							
.u16_dm_next:
    dey                 	; Decrement Y counter
    bne .u16_dm_loop		; Continue until all 16-bits have been processed
    
	clc                 	; Clear Carry: Success/No Error
    rts						; Return (Done/Finished)

;----------------------------------------------------------
; INT16 DIVIDE & MODULO ROUTINE
;----------------------------------------------------------
INT16_DIVMOD:
	; 1. Calculate the final sign ahead of time
    lda MATH_DIVIDEND+1
    eor MATH_DIVISOR+1		; Exclusive OR the MSB
    sta MATH_SIGN			; Bit 7 is now 1 if the result should be negative
    
    ; 2. Make Dividend positive if it's negative
    lda MATH_DIVIDEND+1
    bpl .i16_dm_check_divisor	; If positive, skip
    jsr .i16_dm_negate_dividend	; If negative, make it positive (Negate)

.i16_dm_check_divisor:
    lda MATH_DIVISOR+1
    bpl .i16_dm					; If positive, skip
    jsr .i16_dm_negate_divisor	; If negative, make it positive

.i16_dm:
    jsr UINT16_DIVMOD		; Call our existing unsigned routine
    bcs .i16_dm_exit		; Exit if Division by Zero

	; 3. Apply the sign to the Quotient (MATH_DIVIDEND)
    bit MATH_SIGN				; The BIT instruction copies bit 7 of memory to the N flag
    bpl .i16_dm_exit			; If N is 0 (positive), we are done
    jsr .i16_dm_negate_dividend	; Otherwise, make quotient negative

.i16_dm_exit:
    rts

;--- Helper: Two's Complement (Negate) ---
; To negate: Flip all bits and add 1
.i16_dm_negate_dividend:
    lda MATH_DIVIDEND		; eg. Load LSB (%00000001)
    eor #$FF				; eg. Flip all bits! (%11111110)
    clc						; Clear carry for the addition
    adc #1					; Add 1 (%11111111)
    sta MATH_DIVIDEND		; Store back ($FF)
    lda MATH_DIVIDEND+1		; eg. Load MSB (%00000000)
    eor #$FF				; Flip all bits! (%11111111)
    adc #0					; Add 0 PLUS the Carry flag from before
    						; Notice we didn't use clc here. We want to add the Carry bit that might have "spilled over" from the LSB addition.
							; If the Low Byte was $FF and we added 1, it becomes $00 and sets the Carry. The High Byte then gets flipped and adds that 1.
    sta MATH_DIVIDEND+1		; Store back ($FF)
    rts

.i16_dm_negate_divisor:
    lda MATH_DIVISOR
    eor #$FF
    clc
    adc #1
    sta MATH_DIVISOR
    lda MATH_DIVISOR+1
    eor #$FF
    adc #0
    sta MATH_DIVISOR+1
    rts

}   