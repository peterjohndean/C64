;
; Compute!s Gazette
; December 1983
; Proofreader Version 2
; Page 203
; load"pr-v2.bin",8,1
; sys886:new
;

;
; ACME Assembler
; acme --vicelabels vice.txt proofreader_v2.asm
;

!zone Target {
	* = $0376		; SYS 886
					; Small wedge to fit into tape buffer
						
    !cpu 6510					; C64
	!to "pr-v2.bin", cbm		; Program
    !symbollist "symbols.txt"	; Output symbol list for debugging
}

;
; Labels
;
IBASIN	= $0324		; Vector to Kernal CHRIN Routine [$0324-$0325] (Default at 61783 ($F157))
TBUFFR	= $033c		; Tape Buffer [$033c-$03fb]
CHRIN	= $f157		; Character In, returns character in register A 
CHKSUM	= $fe		; Checksum (8-bit) variable
TBLX	= $d6		; Current cursor physical line number
INSRT	= $d8		; Flag: Insert Mode (Any Number Greater Than 0 Is the Number of Inserts)
CHROUT	= $ffd2		; Output character in register A
LINPRT	= $bdcd		; Output ascii decimal of UInt in registers A/X

;
; Install: Check if already installed, then install new handler.
;
Install:
		lda IBASIN
		cmp #<Main
		bne Setup		; If ISBASIN != Main+1, then configure
		rts
;
; Setup: Install new handler and reset checksum variable
;
Setup:
		sta Main+1		; Update Main JSR lsb
      
		lda IBASIN+1
		sta Main+2		; Update Main JSR msb
			
		lda #<Main  
		sta IBASIN		; Set new handler lsb vector
		lda #>Main	
		sta IBASIN+1	; Set new handler msb vector
		
		lda #$00       
		sta CHKSUM		; Reset checksum
		rts

;
; Main: Main loop
;
Main:
		jsr CHRIN	; Call default CHRIN

		; Save registers
		sta $fb       
		stx $fc       
		sty $fd       
		php
		
		; Checksum finished
		cmp #$0d
		beq Show	; If Return, finished checksum
		
		; Ignore spaces
		cmp #$20       
		beq Next	; If Space, skip it
		
		; Perform checksum
		clc        
		adc CHKSUM	; 8-bit Checksum
		sta CHKSUM	; Store $fe = $fe + A (CHRIN)

Next:
		; Restore registers
		lda $fb
		ldx $fc  
		ldy $fd
		plp
		rts

Show:
		; Show checksum, cleanup for next line entry.
		lda #$0d
		jsr CHROUT
		
		lda TBLX		; Read cursor line position
		sta TBUFFR+191
		dec TBUFFR+191	; Temporary value
		
		lda #$00       
		sta INSRT	; No inserts, does this handle the {RVS OFF}

		lda #$13	; {HOME}
		jsr CHROUT
		lda #$12	; {RVS ON}
		jsr CHROUT       
		lda #$3a	; ':'
		jsr CHROUT
		
		ldx CHKSUM	; Read current checksum value
		lda #$00
		sta CHKSUM	; Reset checksum value
		
		; Another wedge? Warm Reset? Other?
		ldy Main+1
		cpy #<CHRIN
		bne BREAK	; If !=, another wedge as altered it
		
		jsr LINPRT	; Output checksum
		jmp Show2

BREAK:	jsr $ddcd	; Points to BRK, why not use the BRK, plus not a notable routine!

Show2:	
		lda #$20	; {SPACE}
		jsr CHROUT       
		jsr CHROUT
		
		lda TBUFFR+191       
		sta TBLX		; Update cursor line position
		jmp Next       
