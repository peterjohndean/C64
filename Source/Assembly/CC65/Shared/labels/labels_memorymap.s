.ifndef LABELS_MEMORYMAP_S
LABELS_MEMORYMAP_S = 1

; Commodore 64 Memory Map
MM_D6510    := $0000    ; MOS 6510 On-chip Data Direction Register.
                        ; Register (xx101111): Bit= 1: Output, Bit= 0: Input,Bit= x: Don't Care
MM_R6510    := $0001    ; MOS 6510 On-chip 8-bit Input/Output Register.
                        ; On-Chip I/O Port
                        ; 0	/LORAM Signal (0=Switch	BASIC ROM Out)
                        ; 1	/HIRAM Signal (0=Switch Kernal ROM Out)
                        ; 2	/CHAREN Signal (O=Switch Char. ROM In)
                        ; 3	Cassette Data Output Line
                        ; 4	Cassette Switch Sense: 1 = Switch Closed
                        ; 5	Cassette Motor Control
                        ;     O = ON, 1 = OFF
                        ; 6-7	Undefined

MM_TBLX     := $00d6    ; Current Screen Line number of Cursor.

MM_COLOR    := $0286    ; Current Foreground Color for Text

MM_SAREG    := $030c    ; Storage for 6510 Accumulator during SYS.
MM_SXREG    := $030d    ; Storage for 6510 X-Register during SYS.
MM_SYREG    := $030e    ; Storage for 6510 Y-Register during SYS.
MM_SPREG    := $030f    ; Storage for 6510 Status Register during SYS.

MM_SPNTRS   := $07f8    ; 07F8-07FF Default Sprite Data Pointers.
.endif
