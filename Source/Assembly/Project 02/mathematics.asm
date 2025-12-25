; ------------------------------------------------------------
;  C64 MATHEMATICS
;  ------------------------------------------------------------
;  Experimenting with BASIC and custom mathematic routines
; ------------------------------------------------------------

!zone MATHEMATICS {

!address {
;
; Global Integer References
MATH_DIVIDEND	= MM_TAPE1BUF	; [$033C-$033D]
MATH_DIVISOR	= MM_TAPE1BUF+2	; [$033E-$033F]
MATH_REMAINDER	= MM_TAPE1BUF+4	; [$0340-$0341]
MATH_SIGN		= MM_TAPE1BUF+6	; [$0342]

;
; Workspace
PF_TMP: !byte $00, $00, $00, $00, $00

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
}


EntryPoint:
	
;	jsr TESTS_FOR_INTEGERS
;	jsr TESTS_FOR_FLOATS
	
	; Get passed value
	jsr BASIC_CHKCOM	; Skip passed ','
	jsr BASIC_FRMEVL	; Ugh, FAC1
	jsr FLOAT2UINT16	; Double-Ugh, FAC1 to U/INT16 in A/Y
;	pha
	tya
;	tax
;	pla
;	jsr BASIC_LINPRT
	jsr UINT8FLOAT		; Now, our INT to FAC1
	
	; Output FAC1
	+KERNEL_CHROUT_IMM 'U'
	+KERNEL_CHROUT_IMM '['
	+OUTPUT_HEXBYTE MM_FAC1
	+KERNEL_CHROUT_IMM ']'
	+KERNEL_CHROUT_IMM ' '
	+OUTPUT_HEXBYTE MM_FAC1+1
	+KERNEL_CHROUT_IMM ' '
	+OUTPUT_HEXBYTE MM_FAC1+2
	+KERNEL_CHROUT_IMM ' '
	+OUTPUT_HEXBYTE MM_FAC1+3
	+KERNEL_CHROUT_IMM ' '
	+OUTPUT_HEXBYTE MM_FAC1+4
	+KERNEL_CHROUT_IMM ' '
	+OUTPUT_HEXBYTE MM_FAC1+5
;	+KERNEL_CHROUT_IMM ','
	jsr BASIC_GOCR
	
	; Save FAC1
	+BASIC_MOVFM_IMM PF_TMP
	
	; Output Packed floating point
	+KERNEL_CHROUT_IMM 'P'
	+KERNEL_CHROUT_IMM '['
	+OUTPUT_HEXBYTE PF_TMP
	+KERNEL_CHROUT_IMM ']'
	+KERNEL_CHROUT_IMM ' '
	+OUTPUT_HEXBYTE PF_TMP+1
	+KERNEL_CHROUT_IMM ' '
	+OUTPUT_HEXBYTE PF_TMP+2
	+KERNEL_CHROUT_IMM ' '
	+OUTPUT_HEXBYTE PF_TMP+3
	+KERNEL_CHROUT_IMM ' '
	+OUTPUT_HEXBYTE PF_TMP+4
	+KERNEL_CHROUT_IMM ' '
	+KERNEL_CHROUT_IMM '-'
	+KERNEL_CHROUT_IMM '-'
	
	+KERNEL_CHROUT_IMM ' '
;	+BASIC_STROUT_IMM Spacer
	+BASIC_MOVMF_IMM PF_TMP
	jsr BASIC_FOUT
    jsr BASIC_STROUT
	jsr BASIC_GOCR
	
ExitPoint:
	rts
	
TESTS_FOR_FLOATS:
	;; Test 1: UINT8 $FC (252)
;    ; Should give: $86 $7C $00 $00 $00
;	lda #$FE
;	jsr UINT8_FLOAT
;	lda #<PF_TMP
;	ldy #>PF_TMP
;	jsr PACKED_FLOATTOMEM
;	
;    +OUTPUT_HEXBYTE PF_TMP
;   +KERNEL_CHROUT_IMM ' '
;   +OUTPUT_HEXBYTE PF_TMP+1
;   +KERNEL_CHROUT_IMM ' '
;   +OUTPUT_HEXBYTE PF_TMP+2
;   +KERNEL_CHROUT_IMM ' '
;   +OUTPUT_HEXBYTE PF_TMP+3
;   +KERNEL_CHROUT_IMM ' '
;   +OUTPUT_HEXBYTE PF_TMP+4
;   +KERNEL_CHROUT_IMM ','
;   
;	+BASIC_MOVMF_IMM PF_TMP
;	jsr BASIC_FOUT
;    jsr BASIC_STROUT
;	jsr BASIC_GOCR
;	
;	rts
;	
;	; Test 3: INT8 $FE (-2)
;    ; Should give: $82 $80 $00 $00 $00
;    lda #$FE
;    jsr INT8_FLOAT
;    lda #<PF_TMP
;	ldy #>PF_TMP
;    jsr PACKED_FLOATTOMEM
;	
;    +OUTPUT_HEXBYTE PF_TMP
;   +KERNEL_CHROUT_IMM ' '
;   +OUTPUT_HEXBYTE PF_TMP+1
;   +KERNEL_CHROUT_IMM ' '
;   +OUTPUT_HEXBYTE PF_TMP+2
;   +KERNEL_CHROUT_IMM ' '
;   +OUTPUT_HEXBYTE PF_TMP+3
;   +KERNEL_CHROUT_IMM ' '
;   +OUTPUT_HEXBYTE PF_TMP+4
;   +KERNEL_CHROUT_IMM ','
;   
;	+BASIC_MOVMF_IMM PF_TMP
;	jsr BASIC_FOUT
;    jsr BASIC_STROUT
;	jsr BASIC_GOCR
;	
;    ; Test 2: UINT16 $FFFD (65533)
;    ; Should give: $90 $7F $FD $00 $00
;    lda #$FD
;    ldx #$FF
;    jsr UINT16_FLOAT
;    lda #<PF_TMP
;	ldy #>PF_TMP
;    jsr PACKED_FLOATTOMEM
;	
;    +OUTPUT_HEXBYTE PF_TMP
;   +KERNEL_CHROUT_IMM ' '
;   +OUTPUT_HEXBYTE PF_TMP+1
;   +KERNEL_CHROUT_IMM ' '
;   +OUTPUT_HEXBYTE PF_TMP+2
;   +KERNEL_CHROUT_IMM ' '
;   +OUTPUT_HEXBYTE PF_TMP+3
;   +KERNEL_CHROUT_IMM ' '
;   +OUTPUT_HEXBYTE PF_TMP+4
;   +KERNEL_CHROUT_IMM ','
;   
;	+BASIC_MOVMF_IMM PF_TMP
;	jsr BASIC_FOUT
;    jsr BASIC_STROUT
;	jsr BASIC_GOCR
;	
;    ; Test 4: INT16 $FFFD (-3)
;    ; Should give: $82 $C0 $00 $00 $00
;    lda #$FD
;    ldx #$FF
;    jsr INT16_FLOAT
;    lda #<PF_TMP
;	ldy #>PF_TMP
;    jsr PACKED_FLOATTOMEM
;	
;    +OUTPUT_HEXBYTE PF_TMP
;   +KERNEL_CHROUT_IMM ' '
;   +OUTPUT_HEXBYTE PF_TMP+1
;   +KERNEL_CHROUT_IMM ' '
;   +OUTPUT_HEXBYTE PF_TMP+2
;   +KERNEL_CHROUT_IMM ' '
;   +OUTPUT_HEXBYTE PF_TMP+3
;   +KERNEL_CHROUT_IMM ' '
;   +OUTPUT_HEXBYTE PF_TMP+4
;   +KERNEL_CHROUT_IMM ','
;   
;	+BASIC_MOVMF_IMM PF_TMP
;	jsr BASIC_FOUT
;    jsr BASIC_STROUT
;	jsr BASIC_GOCR
	
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
 