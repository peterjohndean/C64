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
R6510   .addr $01   ; 6510 Processor Port
;
FREKZP  = $00FB ; Free 0/Zero-Page Space for User Programs ($00FB-$00FE)
;
STATUS	= $0090	; Kernal I/O Status Word (ST)
;;
;LISTEN	= $ffb1	; Command devices on the serial bus to LISTEN, register A = Logical
READST	= $ffb7	; Read status register, register A
SETNAM	= $ffbd	; Set filename pointer, Register A = length, YX to filename
SETLFS	= $ffba	; Set LFS, Register A = Logical, X = First/Device, Y = secondary address
OPEN	= $ffc0	; Open logical file
CLOSE	= $ffc3	; Close logical file, register A = logical file #
CHKIN	= $ffc6	; Set input device, register X = logic file #
CHKOUT	= $ffc9	; Set output device, register X = logical file #
CLRCHN	= $ffcc	; Clear channels
CHRIN	= $ffcf	; Read character from input channel, register A
;LOAD    = $ffd5 ; Load RAM from device, A=0 (load), A=1 (verify), Y/X address. 
;CLALL	= $ffe7	; Close all
;;
CHROUT	= $ffd2	; Output character in register A
