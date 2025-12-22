; ------------------------------------------------------------
;  C64 MATHEMATICS
;  ------------------------------------------------------------
;  Experimenting with BASIC and custom mathematic routines
; ------------------------------------------------------------

!zone MATHEMATICS {

!address {
;
; Global References
MATH_DIVIDEND	= MM_TAPE1BUF	; [$033C-$033D]
MATH_DIVISOR	= MM_TAPE1BUF+2	; [$033E-$033F]
MATH_REMAINDER	= MM_TAPE1BUF+4	; [$0340-$0341]
MATH_SIGN		= MM_TAPE1BUF+6	; [$0342]

;
; Workspace

;
; Constants
!address FP_07:	!byte $83, $60, $00, $00, $00	; Value = 7.0

}


EntryPoint:
	
	;lda #20           ; Load Accumulator with 20
;    ldx #6            ; Load X register with 6
;    jsr MOD8
;    
;    clc               ; Clear carry for addition
;    adc #$30          ; Convert number to ASCII/PETSCII char
;    sta $0400         ; Store '2' at top-left of screen

	; Let's calculate 500 % 300
    ; 500 = $01F4
    ; 300 = $012C
    ; Expected Result = 200 ($00C8)

    ; Setup Dividend (500)
    lda #$F4
    sta MATH_DIVIDEND
    lda #$01
    sta MATH_DIVIDEND+1

    ; Setup Divisor (300)
    lda #$2c
    sta MATH_DIVISOR
    lda #$01
    sta MATH_DIVISOR+1

    ; Call the Routine
    jsr UINT16_DIVMOD

	+BASIC_LINPRT_MEM MM_TAPE1BUF+4
	jsr BASIC_GOCR
	
	;; Setup Dividend (77)
;    lda #77
;    sta MATH_DIVIDEND
;    lda #$00
;    sta MATH_DIVIDEND+1
;
;    ; Setup Divisor (3)
;    lda #$03
;    sta MATH_DIVISOR
;    lda #$00
;    sta MATH_DIVISOR+1

    ; Call the Routine
    +UINT16_DIVMOD_IMM 77, 3

	+BASIC_LINPRT_MEM MATH_DIVIDEND
	+KERNEL_CHROUT_IMM ','
	+BASIC_LINPRT_MEM MATH_REMAINDER
	jsr BASIC_GOCR
	
	;; Setup Dividend (77)
;    lda #77
;    sta MATH_DIVIDEND
;    lda #$00
;    sta MATH_DIVIDEND+1
;
;    ; Setup Divisor (3)
;    lda #$FF
;    sta MATH_DIVISOR
;    lda #$FF
;    sta MATH_DIVISOR+1

    +INT16_DIVMOD_IMM 0077, $FFFD
    
    ;jsr INT16_DIVMOD
    +BASIC_GIVAYF_MEM MATH_DIVIDEND
    jsr BASIC_FOUT
    jsr BASIC_STROUT
    +KERNEL_CHROUT_IMM ','
    +BASIC_GIVAYF_MEM MATH_REMAINDER
    jsr BASIC_FOUT
    jsr BASIC_STROUT
    
	jsr BASIC_GOCR
	
	+BASIC_LINPRT_MEM MATH_DIVIDEND
	+KERNEL_CHROUT_IMM ','
	+BASIC_LINPRT_MEM MATH_REMAINDER
	
ExitPoint:
	rts
}

; ------------------------------------------------------------
; Project source code
; ------------------------------------------------------------
!src "../Common/integer.asm"
 