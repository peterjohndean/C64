;
; Labels
;
;SCREEN_DEV	= 0		; Screen device number
;
READ_LFN	= 1		; logical file number
READ_DEV	= 10	; device
READ_ADR	= 0		; secondary address
;
WRITE_LFN	= 2		; logical file number
WRITE_DEV	= 10	; device
WRITE_ADR	= 2		; secondary address
;
;PRINTER_LFN = 4		; Printer logical file number
;PRINTER_DEV = 4		; Printer device
;PRINTER_ADR = 0		; Printer secondary address
;
;

;
ZPVector    = <USER_FREKZP      ; zero-page pointer for indirect indexed read/writes
ZPVector2   = <USER_FREKZP+2
