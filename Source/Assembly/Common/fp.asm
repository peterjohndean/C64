;==========================================================
;  C64 MATHEMATICS FLOATING-POINT
;----------------------------------------------------------
; MEMORY MAP:
; MM_FAC1
; MM_FAC2
;----------------------------------------------------------
;   INT8FLOAT, for  8-bit signed to float
;  INT16FLOAT, for 16-bit signed to float
; FLOAT2INT16, for float to 16-bit signed integer
;==========================================================
!zone FLOATINGPOINT {
; eg.
; ldy #<$007E		; LSB
; lda #>$0000		; MSB
;
!address {
.FAC1_EXP	= MM_FAC1	; $61
.FAC1_MAN1	= MM_FAC1+1	; $62
.FAC1_MAN2	= MM_FAC1+2	; $63
.FAC1_MAN3	= MM_FAC1+3	; $64
.FAC1_MAN4	= MM_FAC1+4	; $65
.FAC1_SIGN	= MM_FAC1+5	; $66
}

;==========================================================
; INT16 to FAC1
; Parameters:
;	A (MSB)/Y (LSB)
; Returns:
;	Nothing, updates FAC1
;==========================================================
INT16FLOAT:
		sta .FAC1_MAN1	;save fac1 mantissa 1
		sty .FAC1_MAN2	;save fac1 mantissa 2
		ldx #$90		;set exponent=2^16 (integer) aka $90 - $80 = $10 or 16-bits
		jmp bc44		;set exp = x, clear fac1 m3 and m4, normalise and return

;==========================================================
; INT8 to FAC1
; Parameters:
;	A
; Returns:
;	Nothing, pdates FAC1
;==========================================================
INT8FLOAT:
		sta .FAC1_MAN1	; save fac1 mantissa 1
		lda #$00		; clear a
		sta .FAC1_MAN2	; clear fac1 mantissa 2
		ldx #$88		; set exponent=2^8 (integer) aka $88 - $80 = $08 or 8-bits

;this entry point is used by the routine at b391.
;set exponent = x, clear fac1 3 and 4 and normalise
bc44:	lda .FAC1_MAN1	; get fac1 mantissa 1
		eor #$ff		; complement it
		rol				; sign bit into carry

;this entry point is used by the routine at bdcd.
;set exponent = x, clear mantissa 4 and 3 and normalise fac1
bc49:	lda #$00		; clear a
		sta .FAC1_MAN4	; clear fac1 mantissa 4
		sta .FAC1_MAN3	; clear fac1 mantissa 3

;this entry point is used by the routine at af28.
;set exponent = x and normalise fac1
bc4f:	stx .FAC1_EXP	; set fac1 exponent
		sta $70			; clear fac1 rounding byte
		sta .FAC1_SIGN	; clear fac1 sign (b7)
		jmp b8d2		; do abs and normalise fac1

;used by the routines at bc3c and bccc.
b8d2:	bcs b8d7		; branch if number is +ve
		jsr b947		; negate fac1

;b8d7: normalise fac1
;used by the routines at b8d2, bb0f and e097.
b8d7:	ldy #$00		; clear y
		tya				; clear a
		clc				; clear carry for add
		
b8db:	ldx .FAC1_MAN1	; get fac1 mantissa 1
		bne b929		; if not zero normalise fac1
		
		ldx .FAC1_MAN2	; get fac1 mantissa 2
		stx .FAC1_MAN1	; save fac1 mantissa 1
		
		ldx .FAC1_MAN3	; get fac1 mantissa 3
		stx .FAC1_MAN2	; save fac1 mantissa 2
		
		ldx .FAC1_MAN4	; get fac1 mantissa 4
		stx .FAC1_MAN3	; save fac1 mantissa 3
		
		ldx $70			; get fac1 rounding byte
		stx .FAC1_MAN4	; save fac1 mantissa 4
		
		sty $70			; clear fac1 rounding byte
		adc #$08		; add x to exponent offset
		cmp #$20		; compare with $20, max offset, all bits would be = 0
		bne b8db		; loop if not max

;b8f7: clear fac1 exponent and sign
;used by the routines at b7ad, b8fe and bad4.
b8f7:	lda #$00		; clear a

;this entry point is used by the routine at bf7b.
b8f9:	sta .FAC1_EXP	; set fac1 exponent

;b8fb: save fac1 sign
;used by the routine at bab7.
b8fb:	sta .FAC1_SIGN	; save fac1 sign (b7)
		rts

b91d:	adc #$01		; add 1 to exponent offset
		asl $70			; shift fac1 rounding byte
		rol .FAC1_MAN4	; shift fac1 mantissa 4
		rol .FAC1_MAN3	; shift fac1 mantissa 3
		rol .FAC1_MAN2	; shift fac1 mantissa 2
		rol .FAC1_MAN1	; shift fac1 mantissa 1

;this entry point is used by the routine at b8d7.
;normalise fac1
b929:	bpl b91d		; loop if not normalised
		sec				; set carry for subtract
		sbc .FAC1_EXP	; subtract fac1 exponent
		bcs b8f7		; branch if underflow (set result = $0)
		eor #$ff		; complement exponent
		adc #$01		; +1 (twos complement)
		sta .FAC1_EXP	; save fac1 exponent

;test and normalise fac1 for c=0/1
b936:	bcc b946	; exit if no overflow

;this entry point is used by the routine at bc1b.
;normalise fac1 for c=1
b938:	inc .FAC1_EXP	; increment fac1 exponent
		beq .b97e		; if zero do overflow error then warm start
		ror .FAC1_MAN1	; shift fac1 mantissa 1
		ror .FAC1_MAN2	; shift fac1 mantissa 2
		ror .FAC1_MAN3	; shift fac1 mantissa 3
		ror .FAC1_MAN4	; shift fac1 mantissa 4
		ror $70			; shift fac1 rounding byte
b946:	rts

;b947: negate fac1
;used by the routine at b8d2.
.fac1_negate:
b947:	lda .FAC1_SIGN	; get fac1 sign (b7)
		eor #$ff		; complement it
		sta .FAC1_SIGN	; save fac1 sign (b7)

;this entry point is used by the routine at bc9b.
;twos complement fac1 mantissa
.b94d:	lda .FAC1_MAN1	; get fac1 mantissa 1
		eor #$ff		; complement it
		sta .FAC1_MAN1	; save fac1 mantissa 1
		
		lda .FAC1_MAN2	; get fac1 mantissa 2
		eor #$ff		; complement it
		sta .FAC1_MAN2	; save fac1 mantissa 2
		
		lda .FAC1_MAN3	; get fac1 mantissa 3
		eor #$ff		; complement it
		sta .FAC1_MAN3	; save fac1 mantissa 3
		
		lda .FAC1_MAN4	; get fac1 mantissa 4
		eor #$ff		; complement it
		sta .FAC1_MAN4	; save fac1 mantissa 4
		
		lda $70			; get fac1 rounding byte
		eor #$ff		; complement it
		sta $70			; save fac1 rounding byte
		inc $70			; increment fac1 rounding byte
		
		bne b97d		; exit if no overflow

;this entry point is used by the routine at bc1b.
;increment fac1 mantissa
b96f:	inc .FAC1_MAN4	; increment fac1 mantissa 4
		bne b97d		; finished if no rollover
		
		inc .FAC1_MAN3	; increment fac1 mantissa 3
		bne b97d		; finished if no rollover
		
		inc .FAC1_MAN2	; increment fac1 mantissa 2
		bne b97d		; finished if no rollover
		
		inc .FAC1_MAN1	; increment fac1 mantissa 1
b97d:	rts	


;b97e: do overflow error then warm start
;used by the routines at b8fe, bad4 and bd91.
.b97e:	ldx #$0f		; error $0f, overflow error
		jmp $a437		; do error #x then warm start

;==========================================================
; FAC1 to INT16
; Parameters:
;	None
; Returns:
;	Int16 in A (MSB)/Y (LSB)
;==========================================================		
FLOAT2INT16:
		jsr .bc9b		; convert FAC1 floating to fixed
		lda .FAC1_MAN3			; get FAC1 mantissa 3
		ldy .FAC1_MAN4			; get FAC1 mantissa 4
		rts
		
;BC9B: convert FAC1 floating to fixed
;Used by the routines at A9A5, B1B2, B7F7, BCCC and BDDD.
.bc9b:	lda .FAC1_EXP		; get fac1 exponent
		beq .bce9	; if zero go clear fac1 and return
		sec			; set carry for subtract
		sbc #$a0	; subtract maximum integer range exponent
		bit .FAC1_SIGN		; test fac1 sign (b7)
		bpl .bcaf	; branch if fac1 +ve

					; fac1 was -ve
		tax			; copy subtracted exponent
		lda #$ff	; overflow for -ve number
		sta $68		; set fac1 overflow byte
		jsr .b94d	; twos complement fac1 mantissa
		txa			; restore subtracted exponent
.bcaf:	ldx #$61	; set index to fac1
		cmp #$f9	; compare exponent result
		bpl .bcbb	; if < 8 shifts shift fac1 a times right and return
		jsr .b999	; shift fac1 a times right (> 8 shifts)
		sty $68		; clear fac1 overflow byte

; this entry point is used by the routine at bc5b.
.bcba:	rts	

;bcbb: shift fac1 a times right
;used by the routine at bc9b.
.bcbb:	tay			; copy shift count
		lda .FAC1_SIGN		; get fac1 sign (b7)
		and #%10000000	; mask sign bit only (x000 0000)
		lsr .FAC1_MAN1		; shift fac1 mantissa 1
		ora .FAC1_MAN1		; or sign in b7 fac1 mantissa 1
		sta .FAC1_MAN1		; save fac1 mantissa 1
		jsr .b9b0	; shift fac1 y times right
		sty $68		; clear fac1 overflow byte
		rts

;B983: shift FCAtemp << A+8 times
;Used by the routine at BA28.
.b983:	ldx #$25	; set the offset to factemp
.b985:	ldy $04,x	; get facx mantissa 4
		sty $70		; save as fac1 rounding byte
		ldy $03,x	; get facx mantissa 3
		sty $04,x	; save facx mantissa 4
		ldy $02,x	; get facx mantissa 2
		sty $03,x	; save facx mantissa 3
		ldy $01,x	; get facx mantissa 1
		sty $02,x	; save facx mantissa 2
		ldy $68		; get fac1 overflow byte
		sty $01,x	; save facx mantissa 1

;this entry point is used by the routines at b862 and bc9b.
;shift facx -a times right (> 8 shifts)
.b999:	adc #$08	; add 8 to shift count
		bmi .b985	; go do 8 shift if still -ve
		beq .b985	; go do 8 shift if zero
		sbc #$08	; else subtract 8 again
		tay			; save count to y
		lda $70		; get fac1 rounding byte
		bcs .b9ba	
.b9a6:	asl $01,x	; shift facx mantissa 1
		bcc .b9ac	; branch if +ve
		inc $01,x	; this sets b7 eventually
.b9ac:	ror $01,x	; shift facx mantissa 1 (correct for asl)
		ror $01,x	; shift facx mantissa 1 (put carry in b7)

;this entry point is used by the routines at b86a and bcbb.
;shift facx y times right
.b9b0:	ror $02,x	; shift facx mantissa 2
		ror $03,x	; shift facx mantissa 3
		ror $04,x	; shift facx mantissa 4
		ror 		; shift facx rounding byte
		iny			; increment exponent diff
		bne .b9a6	; branch if range adjust not complete
.b9ba:	clc			; just clear it
		rts	

; bce9: clear fac1
; used by the routine at bc9b.
.bce9:	sta .FAC1_MAN1		; clear fac1 mantissa 1
		sta .FAC1_MAN2		; clear fac1 mantissa 2
		sta .FAC1_MAN3		; clear fac1 mantissa 3
		sta .FAC1_MAN4		; clear fac1 mantissa 4
		tay			; clear y

; this entry point is used by the routine at bccc.
.bcf2:	rts
}