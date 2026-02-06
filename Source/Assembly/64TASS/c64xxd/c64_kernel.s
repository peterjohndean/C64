;------------------------------------------------
; KERNAL ROM
; E000–FFFF 57344–65535 – 8192 Bytes (or 8K RAM)
;------------------------------------------------
;
;KERNAL_LISTEN	= $ffb1	; Command devices on the serial bus to LISTEN, register A = Logical
KERNAL_READST	= $ffb7	; Read status register, register A
KERNAL_SETNAM	= $ffbd	; Set filename pointer, Register A = length, YX to filename
KERNAL_SETLFS	= $ffba	; Set LFS, Register A = Logical, X = First/Device, Y = secondary address
KERNAL_OPEN	    = $ffc0	; Open logical file
KERNAL_CLOSE	= $ffc3	; Close logical file, register A = logical file #
KERNAL_CHKIN	= $ffc6	; Set input device, register X = logic file #
KERNAL_CHKOUT	= $ffc9	; Set output device, register X = logical file #
KERNAL_CLRCHN	= $ffcc	; Clear channels
KERNAL_CHRIN	= $ffcf	; Read character from input channel, register A
;KERNAL_LOAD    = $ffd5 ; Load RAM from device, A=0 (load), A=1 (verify), RAM at Y/X address. 
;KERNAL_CLALL	= $ffe7	; Close all
KERNAL_CHROUT	= $ffd2	; Output character in register A
