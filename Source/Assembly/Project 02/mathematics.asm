; ------------------------------------------------------------
;  C64 MATHEMATICS
;  ------------------------------------------------------------
;  Experimenting with BASIC and custom mathematic routines
; ------------------------------------------------------------

!zone MATHEMATICS {

!address {
;;
;; Global Integer References
;MATH_DIVIDEND	= MM_TAPE1BUF	; [$033C-$033D]
;MATH_DIVISOR	= MM_TAPE1BUF+2	; [$033E-$033F]
;MATH_REMAINDER	= MM_TAPE1BUF+4	; [$0340-$0341]
;MATH_SIGN		= MM_TAPE1BUF+6	; [$0342]

;
; Workspace
FP_ORG: !byte $00, $00, $00, $00, $00;	Holds the original SYS value
FP_NEW: !byte $00, $00, $00, $00, $00;	Holds the newly Float to Int to Float value

;
; Constants
;Header: !pet "[ee] m4 m3 m2 m1 sg  [ee] m4 m3 m2 m1", 13, 0
Spacer: !pet "....", 0
;PF_N0002:	!byte $82,$80,$00,$00,$00	; -2.0
;PF_P0000:	!byte $00,$00,$00,$00,$00	;  0.0
;PF_P0001:	!byte $81,$00,$00,$00,$00	;  1.0
;PF_P0002:	!byte $82,$00,$00,$00,$00	;  2.0  
;PF_P0007:	!byte $83,$60,$00,$00,$00	;  7.0
;PF_P0010:	!byte $84,$20,$00,$00,$00	; 10.0
;PF_P0063:	!byte $86,$7c,$00,$00,$00	; 63.0

P1:	!byte $00
}


EntryPoint:
;	jsr TESTS_FOR_INTEGERS
;	jsr TESTS_FOR_FLOATS
	

	
ExitPoint:
	rts
	
TESTS_FOR_FLOATS:

	rts
	
TESTS_FOR_INTEGERS:
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
    ;lda #$F4
;    sta MATH_DIVIDEND
;    lda #$01
;    sta MATH_DIVIDEND+1
;
;    ; Setup Divisor (300)
;    lda #$2c
;    sta MATH_DIVISOR
;    lda #$01
;    sta MATH_DIVISOR+1
;
;    ; Call the Routine
;    jsr UINT16_DIVMOD
;
;	+BASIC_LINPRT_MEM MM_TAPE1BUF+4
;	jsr BASIC_GOCR
	
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

    
    ;+UINT16_DIVMOD_IMM 77, 3
;
;	+BASIC_LINPRT_MEM MATH_DIVIDEND
;	+KERNEL_CHROUT_IMM ','
;	+BASIC_LINPRT_MEM MATH_REMAINDER
;	jsr BASIC_GOCR
;	
;
;    +INT16_DIVMOD_IMM 0077, $FFFD
;    
;    ;jsr INT16_DIVMOD
;    +BASIC_GIVAYF_MEM MATH_DIVIDEND
;    jsr BASIC_FOUT
;    jsr BASIC_STROUT
;    +KERNEL_CHROUT_IMM ','
;    +BASIC_GIVAYF_MEM MATH_REMAINDER
;    jsr BASIC_FOUT
;    jsr BASIC_STROUT
;    
;	jsr BASIC_GOCR
;	
;	+BASIC_LINPRT_MEM MATH_DIVIDEND
;	+KERNEL_CHROUT_IMM ','
;	+BASIC_LINPRT_MEM MATH_REMAINDER
	rts
}

; ------------------------------------------------------------
; Project source code
; ------------------------------------------------------------
!src "../Common/fp.asm"
!src "../Common/integer.asm"
 