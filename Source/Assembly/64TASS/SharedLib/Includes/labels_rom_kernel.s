;------------------------------------------------
; C64 KERNEL ROM
; E000–FFFF 57344–65535 – 8192 Bytes (or 8K RAM)
;------------------------------------------------
KERNEL_LISTEN	= $ffb1	; Command devices on the serial bus to LISTEN, register A = Logical
KERNEL_READST	= $ffb7	; Read status register, register A
KERNEL_SETNAM	= $ffbd	; Set filename pointer, Register A = length, YX to filename
KERNEL_SETLFS	= $ffba	; Set LFS, Register A = Logical, X = First/Device, Y = secondary address
KERNEL_OPEN	    = $ffc0	; Open logical file
KERNEL_CLOSE	= $ffc3	; Close logical file, register A = logical file #
KERNEL_CHKIN	= $ffc6	; Set input device, register X = logic file #
KERNEL_CHKOUT	= $ffc9	; Set output device, register X = logical file #
KERNEL_CLRCHN	= $ffcc	; Clear channels
KERNEL_CHRIN	= $ffcf	; Read character from input channel, register A
KERNEL_LOAD     = $ffd5 ; Load RAM from device, A=0 (load), A=1 (verify), RAM at Y/X address.
KERNEL_CLALL	= $ffe7	; Close all
KERNEL_CHROUT	= $ffd2	; Output character in register A
