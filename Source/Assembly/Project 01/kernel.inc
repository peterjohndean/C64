; ------------------------------------------------------------
;  Commodore KERNAL & BASIC Jump Table Definitions (ACME)
;  ---------------------------------------------------------
;  Provides symbolic labels and detailed documentation for
;  ROM entry points.
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
LINNUM	= $0014		; Pointer: Temporary 16-bit integer value ($0014-$0015)

VARTAB	= $002D		; Pointer: Start of BASIC Variables ($002D-$002E)
ARYTAB	= $002F		; Pointer: Start of BASIC Arrays ($002F-$0030)
STREND	= $0031		; Pointer: End of BASIC Arrays storage ($0031-$0032)

FAC1	= $0061		; Floating Point Accumulator #1 ($0061-$0066)
FAC2	= $0069		; Floating Point Accumulator #2 ($0069-$006E)
FREKZP	= $00FB		; Free 0/Zero-Page Space for User Programs ($00FB-$00FE)

; --- BASIC 2.0 ROM Routines ---


;$B79E: Read the next expression in the BASIC text and put it as a 8 bit integer in the X register. If the number is greater than 255 then print Illegal quantity error and return to Basic.

;$B7EB: This routine reads two expressions or numbers separated by a comma from the Basic text. The first is a 16 bit number and the second is an 8 bit number. The 16 bit number is stored in $14 and $15 and the 8 bit number is stored in the X register.
;If either or both of the numbers are out of their ranges then the program will stop and print an illegal quantity error. If the comma is missing a syntax error with be displayed. Both these errors return control to Basic.

;$E1D4: This routine gets the file name, the device number and the secondary address from the Basic text. It gives an error if any of the above are wrong. It is used in preparation for loading, saving or verifying a program, as in MSAVE/MLOAD/ MVERIFY.

; Example:
; BASIC text;
; 	SYS 1234, 0123
; ML;
;	JSR CHKCOM	; Skip passed ','
;	JSR FRMNUM	; Read 0123 and store in FAC1
;	JSR GETADR	; Convert FAC1 → Integer (LINNUM)

FRMNUM  = $AD8A   ; Read next expression (variable, number, etc.) into the FAC.
CHKCOM	= $AEFD	  ; Check if the next character is a comma and skip it. Otherwise print SYNTAX ERROR and return to Basic.
GIVAYF  = $B391   ; Convert FAC1 → signed integer (A/Y)
GETADR	= $B7F7   ; Convert FAC1 → unsigned integer (LINNUM $14/$15). If the number is too big then print illegal quantity error and return to Basic.

MOVFM   = $BBA2   ; Move FAC1 → memory (store variable)
MOVMF   = $BBA8   ; Move memory → FAC1 (load variable)
MOVFA   = $BBD4   ; Copy FAC1 → FAC2
MOVAF   = $BBD7   ; Copy FAC2 → FAC1
ADDNUM  = $B867   ; FAC1 = FAC1 + FAC2
SUBNUM  = $B850   ; FAC1 = FAC1 - FAC2
MULT    = $BA28   ; FAC1 = FAC1 × FAC2
DIV     = $BA7C   ; FAC1 = FAC1 ÷ FAC2
SQR     = $BF71   ; FAC1 = √FAC1
LOG     = $BFED   ; FAC1 = ln(FAC1)
EXP     = $BF7B   ; FAC1 = e^FAC1
LINPRT	= $BDCD	  ; Output a Number in ASCII Decimal Digits
FOUT    = $BDDD   ; FAC1 → ASCII string (for print)
INLIN   = $A560   ; Input line into BASIC buffer
INTFAC  = $BCF3   ; Convert FAC1 → integer (in-place)

; --- KERNAL ROM Routines ---
CINT     = $FF81   ; Initialize screen and I/O defaults
IOINIT   = $FF84   ; Init I/O chips
RAMTAS   = $FF87   ; Test and set RAM limits
RESTOR   = $FF8A   ; Restore default vectors
VECTOR   = $FF8D   ; Copy system vectors to RAM
SETMSG   = $FF90   ; Enable/disable KERNAL messages
SETTMO   = $FFA2   ; Set serial timeout
MEMTOP   = $FF99   ; Get/set top of BASIC memory
MEMBOT   = $FF9C   ; Get/set bottom of BASIC memory
SCNKEY   = $FF9F   ; Keyboard scan
SETLFS   = $FFBA   ; Logical/first/secondary addr
SETNAM   = $FFBD   ; Set filename pointer
OPEN     = $FFC0   ; Open logical file
CLOSE    = $FFC3   ; Close logical file
CHKIN    = $FFC6   ; Set input device
CHKOUT   = $FFC9   ; Set output device
CLRCHN   = $FFCC   ; Restore default channels
CHRIN    = $FFCF   ; Input character
CHROUT   = $FFD2   ; Output character
LOAD     = $FFD5   ; Load data/program
SAVE     = $FFD8   ; Save data/program
SETTIM   = $FFDB   ; Set clock
RDTIM    = $FFDE   ; Read clock
STOP     = $FFE1   ; Check STOP key
GETIN    = $FFE4   ; Get input character
CLALL    = $FFE7   ; Close all
UDTIM    = $FFEA   ; Increment system clock
SCREEN   = $FFED   ; Get screen mode info
PLOT     = $FFF0   ; Get/set cursor position
IOBASE   = $FFF3   ; Get I/O base
LISTEN   = $FFB1
TALK     = $FFB4
READST   = $FFB7
UNLSN    = $FFAE
UNTLK    = $FFAB
}

; ============================================================
; End of KERNAL & BASIC Definition Table
; ============================================================