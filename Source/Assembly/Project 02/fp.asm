; ------------------------------------------------------------
;  C64 MATHEMATICS
;  ------------------------------------------------------------
;  Experimenting with BASIC and custom mathematic routines
; ------------------------------------------------------------

!zone MATHEMATICS {
;
; Workspace

;
; Constants
!address PF07:	!byte $83, $60, $00, $00, $00	; Value = 7.0


EntryPoint:
	
	lda #20           ; Load Accumulator with 20
    ldx #6            ; Load X register with 6
    jsr MOD8
    
    clc               ; Clear carry for addition
    adc #$30          ; Convert number to ASCII/PETSCII char
    sta $0400         ; Store '2' at top-left of screen

	; Let's calculate 500 % 300
    ; 500 = $01F4
    ; 300 = $012C
    ; Expected Result = 200 ($00C8)

    ; Setup Dividend (500)
    lda #$F4
    sta MM_TAPE1BUF
    lda #$01
    sta MM_TAPE1BUF+1

    ; Setup Divisor (300)
    lda #$2c
    sta MM_TAPE1BUF+2
    lda #$01
    sta MM_TAPE1BUF+3

    ; Call the Routine
    jsr MOD16

	+BASIC_LINPRT_MEM MM_TAPE1BUF+4
	jsr BASIC_GOCR
	
	; Setup Dividend (77)
    lda #77
    sta MM_TAPE1BUF
    lda #$00
    sta MM_TAPE1BUF+1

    ; Setup Divisor (3)
    lda #$03
    sta MM_TAPE1BUF+2
    lda #$00
    sta MM_TAPE1BUF+3

    ; Call the Routine
    jsr UNSIGNED_DIVMOD16

	+BASIC_LINPRT_MEM MM_TAPE1BUF
	+KERNEL_CHROUT_IMM ','
	+BASIC_LINPRT_MEM MM_TAPE1BUF+4
	jsr BASIC_GOCR
	
	; Setup Dividend (77)
    lda #77
    sta MM_TAPE1BUF
    lda #$00
    sta MM_TAPE1BUF+1

    ; Setup Divisor (3)
    lda #$FF
    sta MM_TAPE1BUF+2
    lda #$FF
    sta MM_TAPE1BUF+3

    ; Call the Routine
    jsr SIGNED_DIVMOD16

	+BASIC_LINPRT_MEM MM_TAPE1BUF
	+KERNEL_CHROUT_IMM ','
	+BASIC_LINPRT_MEM MM_TAPE1BUF+4
	
ExitPoint:
	rts
}


!zone INTEGERS {
;==========================================================
; C64 MODULO (REMAINDER) SUBROUTINE
;	The C64's built-in BASIC V2 does not have a dedicated modulo operator.
;	The remainder is calculated using the formula R=V-(INT(V/D)*D), 
;	where V is the dividend and D is the divisor. 
;
; INPUTS:
;   Accumulator (A) = Dividend (The number being divided)
;   X Register  (X) = Divisor (The number to divide by)
;
; OUTPUT:
;   Accumulator (A) = Remainder (The result of MOD)
;==========================================================
!zone MODULO {
!address {
.DIVIDEND	= <MM_FREKZP	; Zero Page address for the number to divide
.DIVISOR	= <MM_FREKZP+1	; Zero Page address for the number to divide by
.REMAINDER	= <MM_FREKZP+2	; Zero Page address to store the result
}

MOD8:
    sta .DIVIDEND      ; Store A into memory
    stx .DIVISOR       ; Store X into memory
    
    lda #0            ; Clear Accumulator
    sta .REMAINDER     ; Initialize Remainder to 0
    
    ldx #8            ; Set Loop Counter to 8 (for 8-bit integers)

.bit_loop:
    ;--- STEP 1: SHIFT ---
    ; We shift the Dividend Left (ASL). 
    ; The Most Significant Bit (MSB) moves into the Carry Flag.
    asl .DIVIDEND      
    
    ; We rotate the Remainder Left (ROL).
    ; The Carry Flag (from the dividend) moves into the LSB of Remainder.
    rol .REMAINDER     

    ;--- STEP 2: COMPARE ---
    ; Check if Remainder is big enough to subtract the Divisor.
    lda .REMAINDER     
    cmp .DIVISOR       ; Compare A (Remainder) with Memory (Divisor)
                      ; If A >= M, Carry Flag is SET.
                      ; If A < M, Carry Flag is CLEAR.
    
    bcc .skip_sub     ; Branch if Carry Clear (Remainder is too small)

    ;--- STEP 3: SUBTRACT ---
    ; If we are here, Remainder >= Divisor.
    sbc .DIVISOR       ; Subtract Divisor from Accumulator
                      ; Note: SBC uses the Carry. Since CMP set the Carry,
                      ; we don't need a SEC instruction here.
    sta .REMAINDER     ; Save the new (reduced) Remainder

.skip_sub:
    dex               ; Decrement loop counter
    bne .bit_loop     ; If not zero, do the next bit

    ;--- CLEANUP ---
    lda .REMAINDER     ; Load the final remainder into A for return
    rts               ; Return from Subroutine
}

;==========================================================
; C64 16-BIT MODULO (TAPE BUFFER VERSION)
; ACME Assembler Format
;
; MEMORY MAP:
; We use the Tape Buffer at $033C.
; We need 6 bytes total.
;
; INPUTS:
;   Store values in:
;   .DIVIDEND (Low/High)
;   .DIVISOR  (Low/High)
;
; OUTPUT:
;   .REMAINDER (Low/High)
;==========================================================

!zone MODULO16_TAPE {

!address {
    ; We define the labels to point to the Tape Buffer memory.
    ; This uses "Absolute" addresses ($xxxx) instead of ZP ($xx).

    .TAPE_BUF_START = $033C       ; Standard start of C64 Tape Buffer

    .DIVIDEND		= MM_TAPE1BUF	; $033C and $033D
    .DIVISOR		= MM_TAPE1BUF+2	; $033E and $033F
    .REMAINDER		= MM_TAPE1BUF+4	; $0340 and $0341
    .SIGN_COUNTER	= MM_TAPE1BUF+6	; Extra byte to track signs
}

;==========================================================
; FAST MODULO 8 (2 to the power of 3)
; Equivalent to: Dividend % 8
;==========================================================
FAST_MOD_8:
    lda .DIVIDEND       ; Load the low byte
    and #%00000111      ; Keep only the bottom 3 bits (values 0-7)
    sta .REMAINDER
    lda #0
    sta .REMAINDER+1    ; High byte of MOD 8 is always 0
    rts
    
;==========================================================
; FAST DIVIDE BY 16 (2 to the power of 4)
; Equivalent to: Dividend / 16
;==========================================================
FAST_DIV_16:
    ldy #4              ; We want to shift 4 times (2^4 = 16)
    
.loop:
    lsr .DIVIDEND+1     ; Shift High Byte Right. Bit 0 goes into Carry.
    ror .DIVIDEND       ; Rotate Low Byte Right. Carry goes into Bit 7.
    dey
    bne .loop
    rts

MOD16:
    ;--- INIT ---
    ; Clear the Remainder to start (both bytes)
    lda #0              
    sta .REMAINDER      
    sta .REMAINDER+1    
    
    ldx #16             ; Set Loop Counter to 16 bits

.bit_loop:
    ;--- STEP 1: 16-BIT SHIFT (Conveyor Belt) ---
    ; We shift the whole 32-bit chain (Dividend + Remainder) left.
    ; Because these variables are now at $03xx, the CPU uses 
    ; Absolute Addressing.

    asl .DIVIDEND       ; Shift Low Byte of Dividend
    rol .DIVIDEND+1     ; Rotate High Byte (Carry moves from Low to High)
    
    rol .REMAINDER      ; Rotate Low Byte of Remainder (Carry comes from Dividend)
    rol .REMAINDER+1    ; Rotate High Byte of Remainder
    
    ; The MSB of the Dividend is now in the LSB of the Remainder.

    ;--- STEP 2: 16-BIT COMPARE ---
    ; Is Remainder >= Divisor?
    ; Rule: Compare High Bytes first.

    lda .REMAINDER+1    ; Load High Byte
    cmp .DIVISOR+1      ; Compare High Bytes
    bne .check_carry    ; If not equal, the Carry flag is already set correctly.
                        ; (If Rem > Div, Carry=1. If Rem < Div, Carry=0).
    
    ; If High Bytes are equal, we must compare Low Bytes.
    lda .REMAINDER
    cmp .DIVISOR

.check_carry:
    ; Branch if Carry Clear (Remainder < Divisor)
    bcc .skip_sub

    ;--- STEP 3: 16-BIT SUBTRACTION ---
    ; Remainder = Remainder - Divisor
    
    lda .REMAINDER      ; Load Low Byte
    sbc .DIVISOR        ; Subtract Low Byte of Divisor
    sta .REMAINDER      ; Store result back to Tape Buffer
    
    lda .REMAINDER+1    ; Load High Byte
    sbc .DIVISOR+1      ; Subtract High Byte (with borrow)
    sta .REMAINDER+1    ; Store result

.skip_sub:
    dex                 ; Decrement Loop Counter
    bne .bit_loop       ; Loop if not zero

    rts                 ; Return
    
;==========================================================
; 16-BIT DIVIDE & MODULO (TAPE BUFFER)
;
; INPUTS:  .DIVIDEND, .DIVISOR
; OUTPUTS: .DIVIDEND  = Quotient (Result of /)
;          .REMAINDER = Remainder (Result of %)
;==========================================================

MOD16_WITH_DIV:
    lda #0              
    sta .REMAINDER      
    sta .REMAINDER+1    
    
    ldx #16             

.bit_loop2:
    asl .DIVIDEND       
    rol .DIVIDEND+1     
    rol .REMAINDER      
    rol .REMAINDER+1    

    lda .REMAINDER+1    
    cmp .DIVISOR+1      
    bne .check_carry2    
    lda .REMAINDER
    cmp .DIVISOR

.check_carry2:
    bcc .skip_sub2

    ;--- SUBTRACTION ---
    lda .REMAINDER      
    sbc .DIVISOR        
    sta .REMAINDER      
    lda .REMAINDER+1    
    sbc .DIVISOR+1      
    sta .REMAINDER+1    

    ;--- THE ONLY ADDITION FOR SPEED ---
    inc .DIVIDEND       ; Set the lowest bit of the Quotient to 1
                        ; This turns your Modulo into a Divide!

.skip_sub2:
    dex                 
    bne .bit_loop2       
    rts
    
;==========================================================
; 16-BIT DIVIDE & MODULO (OPTIMIZED)
;==========================================================
UNSIGNED_DIVMOD16:
	;--- STEP 0: DIVISION BY ZERO CHECK ---
    ; Check if both High and Low bytes of Divisor are 0
    lda .DIVISOR
    ora .DIVISOR+1	; OR the two bytes together
    bne .start3     ; If result is NOT zero, divisor is safe
    
    ; If we are here, Divisor is 0. 
    ; We should return an error or specific value.
    ; Most C64 routines set the Carry Flag to indicate an error.
    sec                 ; Set Carry = Error
    rts
    
.start3
    lda #0              
    sta .REMAINDER      
    sta .REMAINDER+1    
    
    ldy #16             ; Using Y as the loop counter

.bit_loop3:
    ;--- STEP 1: THE 32-BIT SHIFT ---
    ; We shift the Dividend and Remainder as one unit.
    asl .DIVIDEND       
    rol .DIVIDEND+1     
    rol .REMAINDER      
    rol .REMAINDER+1    

    ;--- STEP 2: 16-BIT COMPARE ---
    ; Does Divisor fit into the current Remainder?
    lda .REMAINDER
    sec                 ; Prepare carry for subtraction
    sbc .DIVISOR        ; Subtract Low Byte
    tax                 ; Temporarily save Low Byte result in X
    
    lda .REMAINDER+1
    sbc .DIVISOR+1      ; Subtract High Byte
    bcc .skip_sub3       ; If result is negative, Divisor > Remainder

    ;--- STEP 3: COMMIT SUBTRACTION ---
    ; If we're here, the subtraction was successful.
    sta .REMAINDER+1    ; Save High Byte (already in A)
    stx .REMAINDER      ; Save Low Byte (from X)
    
    inc .DIVIDEND       ; Set the Quotient bit to 1

.skip_sub3:
    dey                 ; Decrement Y counter
    bne .bit_loop3       
	clc                 ; Clear Carry = Success/No Error
    rts

SIGNED_DIVMOD16:
    lda #0
    sta .SIGN_COUNTER

    ; 1. Check Dividend Sign
    lda .DIVIDEND+1
    bpl .check_divisor      ; If positive, skip
    
    ; If negative, make it positive (Negate)
    jsr negate_dividend
    inc .SIGN_COUNTER       ; Track that one input was negative

.check_divisor:
    lda .DIVISOR+1
    bpl .do_the_math        ; If positive, skip
    
    ; If negative, make it positive
    jsr negate_divisor
    inc .SIGN_COUNTER

.do_the_math:
    jsr UNSIGNED_DIVMOD16	; Call our existing unsigned routine
    bcs .exit               ; Exit if Division by Zero

    ; 2. Handle Quotient Sign (Result is negative if one input was neg)
    ; If .SIGN_COUNTER is 1, result is negative.
    lda .SIGN_COUNTER
    lsr                     ; Shift Bit 0 into Carry
    bcc .check_remainder_sign ; If Carry clear, 0 or 2 negs = Positive result
    
    jsr negate_dividend     ; Convert Quotient back to negative

.check_remainder_sign:
    ; Rule: Remainder sign usually matches original Dividend sign.
    ; (This requires storing the original sign earlier, but for now 
    ; let's stick to simple division signs).
    clc

.exit:
    rts

;--- Helper: Two's Complement (Negate) ---
; To negate: Flip all bits and add 1
negate_dividend:
    lda .DIVIDEND
    eor #$FF
    clc
    adc #1
    sta .DIVIDEND
    lda .DIVIDEND+1
    eor #$FF
    adc #0
    sta .DIVIDEND+1
    rts

negate_divisor:
    lda .DIVISOR
    eor #$FF
    clc
    adc #1
    sta .DIVISOR
    lda .DIVISOR+1
    eor #$FF
    adc #0
    sta .DIVISOR+1
    rts
             
}

}   