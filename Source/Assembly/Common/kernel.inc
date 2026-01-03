; ------------------------------------------------------------
;  Commodore KERNAL & BASIC Jump Table Definitions (ACME)
;  ---------------------------------------------------------
;  Provides symbolic labels and detailed documentation for
;  ROM entry points.
; Prefixes:
; MM_		- for memory locations
; BASIC_	- BASIC subroutines
; KERNEL_	- Kernel subroutines
; ------------------------------------------------------------

; ============================================================
; Commodore 64 (BASIC 2.0)
; ============================================================
!address {
; --- MEMORY MAP Locations ---
; ------------------------------------------------------------
; Zero-Page Scratch Variables
; Ref: pg165-166, Commodore 64/128 Assembly Language Programming, Mark Andrews
; Ref: pg310, 316, COMMODORE 64 - PROGRAMMER'S REFERENCE GUIDE
; Ref: Appendix B, COMPUTE!s Mapping The Commodore 64, Sheldon Leemon
; ------------------------------------------------------------
MM_ADRAY1	= $0003		; Jump Vector: Convert FAC to Integer in (A/Y) (Default: $B1AA).
MM_ADRAY2	= $0005		; Jump Vector: Convert Integer in (A/Y) to Floating point in (FAC) (Default: $B391).

MM_LINNUM	= $0014		; Temporary INT16 value ($0014-$0015)

MM_INDEX	= $0022		; Utility Pointer Area ($0022-$0025)
MM_INDEX1	= $0022		; 1st Utility Pointer ($0022-$0023)
MM_INDEX2	= $0024		; 2nd Utility Pointer ($0024-$0025)

MM_RES		= $0026		; Floating Point Multiplication Work Area ($0026-$002A)

MM_VARTAB	= $002D		; Pointer: Start of BASIC Variables ($002D-$002E)
; Variable Name			x2 bytes
; Value					x5 bytes for floats
;						x2 bytes for integers (msb, lsb)
;						x3 bytes for strings (len, lsb, msb)
;						x4 bytes for functions FN A(X) (lsb, msb), X of FN(X) (lsb, msb)

MM_ARYTAB	= $002F		; Pointer: Start of BASIC Arrays ($002F-$0030)
; Array Name 			x2 bytes
; Offset to Next Array 	x2 bytes
; Array Dimensions		x1 byte (1 for A(x), 2 for A(x,y), etc)
; Default=Dim(10)+1		(x2 bytes) x Array Dim. i.e x2 for 1, x2x2 for 2, x2x2x2 for 3
; Value					x5 bytes for floats
;						x2 bytes for integers
;						x3 bytes for strings (len, lsb, msb)

MM_STREND	= $0031		; Pointer: End of BASIC Arrays storage ($0031-$0032)

MM_VARNAM	= $0045		; Current BASIC Variable Name ($0045-$0046)
MM_VARPNT	= $0047		; Pointer to the Current BASIC Variable Value ($0047-$0048)

MM_FAC1		= $0061		; Floating Point Accumulator #1 ($0061-$0066)
MM_BITS		= $0068		; Floating Point Accumulator #1 (Overflow Digit,  the overflow byte is used in an intermediate step of conversion from an integer or text string to a floating point number.)
MM_FAC2		= $0069		; Floating Point Accumulator #2 ($0069-$006E)
MM_FACOV	= $0070		; Floating Point Accumulator #1 (Low Order Mantissa Byte of For Rounding)

MM_TXTPTR	= $007A		; Pointer: Current Byte of BASIC Text [$007A-$007B]

MM_FREKZP	= $00FB		; Free 0/Zero-Page Space for User Programs ($00FB-$00FE)
MM_BASZPT	= $00FF		; Basic 0/Zero-Page Space for BASIC Temporary Data for Floating Point to ASCII Conversion

;MM_BUF		= $0200		; BASIC Line Editor Input Buffer ($0200-$0258)

MM_TAPE1	= $00B2		; Basic 0/Zero-Page Vector for the 16-bit start address of the tape buffer (192 bytes), which defaults to $033C. ($00B2-$00B3)
MM_BIVT		= $0300		; Basic Indirect Vector Table ($0300-$030B), $0300-$0301 points to Error Message handler.
MM_TAPE1BUF	= $033C		; Default tape buffer address.

; --- BASIC 2.0 ROM Routines ---
; A000-BFFF	40960-49151	ROM : Basic

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

BASIC_GOCR		= $AAD7		; Output CR/LF
BASIC_STROUT	= $AB1E		; Output the null-terminated string (Register Y/A aka MSB/LSB).

BASIC_FRMNUM	= $AD8A		; Read next expression (variable, number, etc.) into the FAC1.
BASIC_FRMEVL	= $AD9E		; Read and evaluate next expression into the FAC1
BASIC_CHKCOM	= $AEFD		; Check if the next character is a comma and skip it. Otherwise print SYNTAX ERROR and return to Basic.

BASIC_GIVAYF	= $B391   	; Convert INT16 (Register A/Y) → FAC1
BASIC_GETADR	= $B7F7		; Convert FAC1 → UINT16 (Register A/Y, and stores it to LINNUM $14/$15).
							; If the number is too big then print illegal quantity error and return to Basic.

BASIC_PTRGET	= $B08B		; Return Variable Pointer (Register Y/A) & VARPNT
							; Scans variable name at TXTPTR, and searches the
							; VARTAB and ARYTAB for the name.
							; If not found, create variable of appropriate type.

BASIC_CONUPK	= $BA8C		; Unpack Memory (Y/A) to FAC2

BASIC_FDIV		= $BB0F		; Unpack Memory (Y/A) to FAC2, FAC1 = FAC2 ÷ FAC1

BASIC_FADDT		= $B86A		; FAC1 = FAC2 + FAC1, must use BASIC_CONUPK
BASIC_FDIVT		= $BB12		; FAC1 = FAC2 ÷ FAC1, must use BASIC_CONUPK

BASIC_MOVFM		= $BBD4		; Pack FAC1 → Memory (Y/X). Memory contains a 5-Byte C64 float
BASIC_MOVMF		= $BBA2		; Unpack Memory (Y/A) → FAC1. Memory contains a 5-Byte C64 float

BASIC_MOVFA		= $BBFC		; Copy FAC2 → FAC1
BASIC_MOVAF		= $BC0C		; Copy FAC1 (with Rounding Byte) → FAC2
BASIC_MOVEF		= $BC0F		; Copy FAC1 (without Rounding Byte) → FAC2

BASIC_ABS		= $BC58		; ABS(FAC1)

BASIC_CLRFAC1	= $BCE9		; Clear FAC1 with value in A

BASIC_LINPRT	= $BDCD		; Output UINT16 (Register A/X) as a Number in ASCII Decimal Digits
BASIC_FOUT		= $BDDD		; Convert FAC1 → String, Register A/Y holding the pointer to null terminated string.
							; NB. Uses FAC1, thus changes the FAC1 value.
;BASIC_INLIN	= $A560   ; Input line into BASIC buffer
;BASIC_INTFAC	= $BCF3   ; Convert FAC1 → integer (in-place)

; --- KERNAL ROM Routines ---
;CINT     = $FF81   ; Initialize screen and I/O defaults
;IOINIT   = $FF84   ; Init I/O chips
;RAMTAS   = $FF87   ; Test and set RAM limits
;RESTOR   = $FF8A   ; Restore default vectors
;VECTOR   = $FF8D   ; Copy system vectors to RAM
;SETMSG   = $FF90   ; Enable/disable KERNAL messages
;SETTMO   = $FFA2   ; Set serial timeout
;MEMTOP   = $FF99   ; Get/set top of BASIC memory
;MEMBOT   = $FF9C   ; Get/set bottom of BASIC memory
;SCNKEY   = $FF9F   ; Keyboard scan
;SETLFS   = $FFBA   ; Logical/first/secondary addr
;SETNAM   = $FFBD   ; Set filename pointer
;OPEN     = $FFC0   ; Open logical file
;CLOSE    = $FFC3   ; Close logical file
;CHKIN    = $FFC6   ; Set input device
;CHKOUT   = $FFC9   ; Set output device
;CLRCHN   = $FFCC   ; Restore default channels
;CHRIN    = $FFCF   ; Input character
KERNEL_CHROUT   = $FFD2		; Output character to channel
;LOAD     = $FFD5   ; Load data/program
;SAVE     = $FFD8   ; Save data/program
;SETTIM   = $FFDB   ; Set clock
;RDTIM    = $FFDE   ; Read clock
;STOP     = $FFE1   ; Check STOP key
;GETIN    = $FFE4   ; Get input character
;CLALL    = $FFE7   ; Close all
;UDTIM    = $FFEA   ; Increment system clock
;SCREEN   = $FFED   ; Get screen mode info
;PLOT     = $FFF0   ; Get/set cursor position
;IOBASE   = $FFF3   ; Get I/O base
;LISTEN   = $FFB1
;TALK     = $FFB4
;READST   = $FFB7
;UNLSN    = $FFAE
;UNTLK    = $FFAB
}

; ============================================================
; End of KERNAL & BASIC Definition Table
; ============================================================