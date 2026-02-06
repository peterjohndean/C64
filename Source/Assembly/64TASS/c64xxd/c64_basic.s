;------------------------------------------------
; BASIC 2.0 ROM
; A000-BFFF	40960-49151 – 8192 Bytes (or 8K RAM)
;------------------------------------------------
;
;$B79E: Read the next expression in the BASIC text and put it as a 8 bit integer in the X register. If the number is greater than 255 then print Illegal quantity error and return to Basic.

;$B7EB: This routine reads two expressions or numbers separated by a comma from the Basic text. The first is a 16 bit number and the second is an 8 bit number. The 16 bit number is stored in $14 and $15 and the 8 bit number is stored in the X register.
;If either or both of the numbers are out of their ranges then the program will stop and print an illegal quantity error. If the comma is missing a syntax error with be displayed. Both these errors return control to Basic.

;$E1D4: This routine gets the file name, the device number and the secondary address from the Basic text. It gives an error if any of the above are wrong. It is used in preparation for loading, saving or verifying a program, as in MSAVE/MLOAD/ MVERIFY.

; Example:
; References:
;	- pg 26, BEST MACHINE CODE ROUTINES FOR THE COMMODORE 64, 1984, Mark Greenshields
;	- pg 391, Compute's Machine Language Routines for the Commodore 64/128, 1987, Todd D. Heimarck and Patrick Parrish
; BASIC text;
; ML - SYS 49152,SQR(9),(1 + 3*7)
;	JSR CHKCOM	; Skip passed ','
;	JSR FRMEVL	; Read SQR(9) and store in FAC1
;	JSR GETADR	; Convert FAC1 → Integer (A/Y & LINNUM)
;	JSR CHKCOM	; Skip passed ','
;	JSR FRMEVL	; Read (1 + 3*7) and store in FAC1
;	JSR GETADR	; Convert FAC1 → Integer (A/Y & LINNUM)
;
; ML - SYS 1234, 0123
;	JSR CHKCOM	; Skip passed ','
;	JSR FRMNUM	; Read 0123 and store in FAC1
;	JSR GETADR	; Convert FAC1 → Integer (A/Y & LINNUM)
;

;BASIC_GOCR		= $AAD7		; Output CR/LF
;BASIC_STROUT	= $ab1e		; Output the null-terminated string (Register Y/A aka MSB/LSB).
;
;BASIC_NEW		= $A642;	; Performs NEW (If register A = 0)
;
;BASIC_FRMNUM	= $AD8A		; Read next expression (variable, number, etc.) into the FAC1.
BASIC_FRMEVL	= $ad9e		; Data Type: Numeric - into the FAC1
                            ; Data Type: String  - length in A, address pointer $22-$23.
BASIC_CHKCOM	= $aefd		; Check if the next character is a comma and skip it.
                            ; Otherwise print SYNTAX ERROR and return to Basic.
BASIC_FRESTR    = $b6a3     ; Finalize string
;
;BASIC_GIVAYF	= $B391   	; Convert INT16 (Register A/Y) → FAC1
;BASIC_GETADR	= $B7F7		; Convert FAC1 → UINT16 (Register A/Y, and stores it to LINNUM $14/$15).
;							; If the number is too big then print illegal quantity error and return to Basic.
;
;BASIC_PTRGET	= $B08B		; Return Variable Pointer (Register Y/A) & VARPNT
;							; Scans variable name at TXTPTR, and searches the
;							; VARTAB and ARYTAB for the name.
;							; If not found, create variable of appropriate type.
;
;BASIC_CONUPK	= $BA8C		; Unpack Memory (Y/A) to FAC2
;
;BASIC_FDIV		= $BB0F		; Unpack Memory (Y/A) to FAC2, FAC1 = FAC2 ÷ FAC1
;
;BASIC_FADDT		= $B86A		; FAC1 = FAC2 + FAC1, must use BASIC_CONUPK
;BASIC_FDIVT		= $BB12		; FAC1 = FAC2 ÷ FAC1, must use BASIC_CONUPK
;
;BASIC_MOVFM		= $BBD4		; Pack FAC1 → Memory (Y/X). Memory contains a 5-Byte C64 float
;BASIC_MOVMF		= $BBA2		; Unpack Memory (Y/A) → FAC1. Memory contains a 5-Byte C64 float
;
;BASIC_MOVFA		= $BBFC		; Copy FAC2 → FAC1
;BASIC_MOVAF		= $BC0C		; Copy FAC1 (with Rounding Byte) → FAC2
;BASIC_MOVEF		= $BC0F		; Copy FAC1 (without Rounding Byte) → FAC2
;
;BASIC_ABS		= $BC58		; ABS(FAC1)
;
;BASIC_CLRFAC1	= $BCE9		; Clear FAC1 with value in A
;
;BASIC_LINPRT	= $BDCD		; Output UINT16 (Register A/X) as a Number in ASCII Decimal Digits
;BASIC_FOUT		= $BDDD		; Convert FAC1 → String, Register A/Y holding the pointer to null terminated string.
							; NB. Uses FAC1, thus changes the FAC1 value.
;BASIC_INLIN	= $A560   ; Input line into BASIC buffer
;BASIC_INTFAC	= $BCF3   ; Convert FAC1 → integer (in-place)
