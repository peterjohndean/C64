;
; Compute!s Gazette
; December ?
; Proofreader Version 3
; Page ???
;
; To methods of invoking the Proofreader,
; 1. load"pr-v3.bin",8,1:sys 2049	-> for normal BASIC
; 2. £"pr-v3.bin"                   -> for JiffyDOS v6.x
;

;
; ACME Assembler
; acme --vicelabels vice.txt proofreader_v3.asm
;
;!serious "Not working yet"
!zone Target {
	* = $0801					; sys 2049
			
    !cpu 6510					; C64
	!to "pr-v3.bin", cbm		; Program
    !symbollist "symbols.txt"	; Output symbol list for debugging
}

;
; Labels
;
TXTTAB	= $2b		; Pointer to the Start of BASIC Program Text (Defaults $0801)
INBIT	= $a7
;BITCI	= $a8
;LDTB1	= $d9		; Screen Line Link Table/Editor Temporary Storage ($00d9-$00f2)
;
CHKSUM	= INBIT		; ZP Checksum int variable
QFLAG	= $b0		; ZP Quote toggle flag
CINDEX	= $b4		; ZP Character index
;
LINNUM	= $14		; Integer Line Number Value ($0014-$0015)
BUF		= $200		; BASIC Line Editor Input Buffer ($0200-$0258)
ICRNCH	= $0304		; Vector to the Routine That Crunches the ASCII Text of Keywords into Tokens (Default at $A57C)
CHROUT	= $ffd2		; Output character in register A
NEW		= $a642		; When register A = 0 and routine is called, this performs NEW

BLOCK_BEGIN:
;
; Install:
;
Install:
		;
		; New ICRNCH handler
		;
istep1:
		sei
		lda #<Main
		sta ICRNCH		; Set new handler lsb vector
		lda #>Main
		sta ICRNCH+1	; Set new handler msb vector
		cli
		
		;
		; Set new BASIC2.0 TXTTAB vector
		;
istep2:
		lda #<BLOCK_END
		sta TXTTAB			; lsb
		lda #>BLOCK_END
		sta TXTTAB+1		; msb
istep3:
		lda #$0
		jsr NEW			; Perform NEW
		
		rts

;
; Main:
;
Main:
		; Include line number in checksum, prevent 2 lines entries that are the same, clever
		lda LINNUM
		sta CHKSUM		; lsb
		lda LINNUM+1
		sta CHKSUM+1	; msb

		; 6526 CIA #2 Data Port A?
;		lda #$00       
;		sta $ff00

;
; Copy (32bytes, 31 down to 0)
;          Base + Index
; Copy from $c7 	+ $1f	- $00E6, $00E5, $00E4, ... down to $00C7
;      to Preserve 	+ x
;

		; Preserve
		ldx #$1f		; Index (31 -> 00)
ploop:
		lda $c7,x
		sta Preserve,x	; why such a large block???
		dex
		bpl ploop

		; Home, reverse characters on
		lda #$13		; {HOME}
		jsr CHROUT
		lda #$12		; {RVS ON}
		jsr CHROUT

		; Initialise
		ldy #$00		; Y, Buffer index
		sty CINDEX		; Character index     
		sty QFLAG		; $00 = outside quote, $ff = inside quote aka string ""
		dey

		; Outer Loop
oloop:
		inc CINDEX		; Character index

		; Inner Loop
iloop:
		iny        
		lda BUF,y       
		beq display
		
		cmp #$22		; {"}
		bne noquote     
		pha        
		lda QFLAG
		eor #$ff		; Toggle quote flag 
		sta QFLAG
		pla

noquote:
		pha        
		cmp #$20		; {SPACE}
		bne nospace      
		lda QFLAG
		bne nospace      
		pla        
		bne iloop

nospace:
		pla        
		
		; Position-Weighted Checksum Loop
		ldx CINDEX
sloop:
		clc        
		lda CHKSUM
		adc BUF,y       
		sta CHKSUM		; update checksum lsb
		lda CHKSUM+1      
		adc #$00		; Add carry if set
		sta CHKSUM+1	; update checksum msb
		dex        
		bne sloop      
		beq oloop

display:
		;
		; Reduce a 16-bit checksum into 8-bit checksum fingerprint
		;
reduce:
		lda CHKSUM       
		eor CHKSUM+1
		
output:
		;
		; Output 8-bit fingerprint
		;
		pha
		and #$0f		; Mask to get low nibble
		tay        
		lda Lookup,y	; Finger print lookup table
		jsr CHROUT
		
		pla        
		lsr				; Shift upper nibble into lower 4 bits
		lsr        
		lsr        
		lsr        
		tay        
		lda Lookup,y	; Finger print lookup table
		jsr CHROUT       

		; Restore 
		ldx #$1f		; Index (31 -> 00)
rloop:
		lda Preserve,x       
		sta $c7,x		; why such a large block???
		dex        
		bpl rloop
		
		lda #$92		; {RVS OFF}
		jsr CHROUT
		
exit:
		jmp $ea64		; Original ICRNCH IRQ Vector

		;
		; Table encodes a checksum nibble into visually unambiguous
		; PETSCII letters, deliberately avoiding characters that
		; could be misread on a C64 display.
		;
Lookup:
		!byte $41, $42, $43, $44
		!byte $45, $46, $47, $48
		!byte $4a, $4b, $4d, $50
		!byte $51, $52, $53, $58

Preserve:
		!fill $0901-Preserve, $00	; Save/Restore blocks expects size $1f (32 bytes)
									; However we will fillout the block (255 bytes).
BLOCK_END:
		;
		; BASIC 2.0 Text
		; Old: $0801
		; New: $0901
		; Initialise: If not, basic command syntax errors will ok :(
		; $0901: $00		-> End of Line
		; $0902: $00 $00	-> End of Program
		;
		!fill $03, $00

;
; Compile Information
;
!warn "Start: ", BLOCK_BEGIN
!warn "  End: ", BLOCK_END
!warn "Bytes: ", BLOCK_END-BLOCK_BEGIN
!warn "TXTTAB:", BLOCK_END

;
; Perhaps a future version
;
; p/rloops might be able to be replaced with (untested - and I've spent enough time on v3 for now),
;	; Save essential screen editor variables
;    lda $d1      ; Cursor column
;    pha
;    lda $d6      ; Cursor line
;    pha
;    
;    ; ... rest of checksum code ...
;    
;    ; Restore essential variables
;    pla
;    sta $d6
;    pla  
;    sta $d1
!if BLOCK_END - BLOCK_BEGIN > 192 {
!warn "Wedge won't fit into Tape Buffer: ", BLOCK_END - BLOCK_BEGIN, " > 192 bytes max."
}

