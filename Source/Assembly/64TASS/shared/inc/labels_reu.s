; ============================================================
; REU Hardware Register Definitions
; The REU communicates via registers mapped at $DF00-$DF0A
; ============================================================
REU_STATUS      = $DF00 ; Status  register  (read)
REU_COMMAND     = $DF01 ; Command register  (write)
REU_C64_LO      = $DF02 ; C64 base address  - low  byte
REU_C64_HI      = $DF03 ; C64 base address  - high byte
REU_REU_LO      = $DF04 ; REU base address  - low  byte
REU_REU_HI      = $DF05 ; REU base address  - high byte
REU_REU_BANK    = $DF06 ; REU bank number   (0-7 for 512KB)
REU_LEN_LO      = $DF07 ; Transfer length   - low  byte
REU_LEN_HI      = $DF08 ; Transfer length   - high byte
REU_INT_MASK    = $DF09 ; Interrupt mask    register
REU_ADDR_CTRL   = $DF0A ; Address control   register


; ============================================================
; REU Command Register Bit Layout
; ============================================================
; Bit 7   : Execute bit  - Set to 1 to trigger the transfer
; Bit 6   : Reserved
; Bit 5   : No Autoload  - 1 = base registers NOT reloaded after transfer
;                        - 0 = base registers reload (useful for streaming)
; Bit 4   : FF00 mode    - Usually 0 for normal operation
; Bit 3   : Reserved
; Bit 2   : Reserved
; Bits 1-0: Transfer type
;            00 ($00) = C64 -> REU  (store to REU)
;            01 ($01) = REU -> C64  (load from REU)
;            10 ($02) = SWAP        (exchange both)
;            11 ($03) = Verify      (compare)
;
; Most common commands (Execute=1, NoAutoload=1):
; ============================================================
REU_CMD_C64_TO_REU  = $90   ; 1001 0000 - Store C64 data into REU
REU_CMD_REU_TO_C64  = $91   ; 1001 0001 - Load REU data into C64
REU_CMD_SWAP        = $92   ; 1001 0010 - Swap C64 <-> REU simultaneously
REU_CMD_VERIFY      = $93   ; 1001 0011 - Verify/compare both regions

; ============================================================
; REU Address Space
; ============================================================
; The REU address is 24-bit: [BANK][HIGH][LOW]
;   - REU_REU_BANK holds bits 16-18 (bank 0-7 for 512KB)
;   - REU_REU_HI   holds bits  8-15
;   - REU_REU_LO   holds bits  0-7
;
; You can pass a 24-bit address to our macros like this:
;
;   REU_ADDR_0  = $000000   ; Start of bank 0
;   REU_ADDR_1  = $010000   ; Start of bank 1 (64KB in)
;   REU_ADDR_2  = $020000   ; Start of bank 2 (128KB in)
;
; 64tass lets us extract bytes cleanly:
;   lda #<(addr)           ; low  byte  (bits 0-7)
;   lda #>(addr)           ; high byte  (bits 8-15)
;   lda #`(addr)           ; bank byte  (bits 16-23) <-- 64tass specific!
;
;  BANK $00 : $0000 - $FFFF  =  1st 64KB  (bytes        0 -  65,535)
;  BANK $01 : $0000 - $FFFF  =  2nd 64KB  (bytes   65,536 - 131,071)
;  BANK $02 : $0000 - $FFFF  =  3rd 64KB  (bytes  131,072 - 196,607)
;  ...
;  BANK $FF : $0000 - $FFFF  = 256th 64KB (bytes 16,711,680 - 16,777,215)
;
;  Total theoretical space = 256 banks x 64KB = 16MB ($FF:FFFF + 1)
;
; Real REU Hardware Limits
; The BANK register is 8-bit wide, but physical chips only
; decode the lower bits depending on the model:
;
;  Model  |  RAM   |  Banks Used  |  Bank Bits  |  Max Address
; --------|--------|--------------|-------------|-------------
;  1700   |  128KB |   0 - 1      |  bit 0 only |  $01:FFFF
;  1764   |  256KB |   0 - 3      |  bits 0-1   |  $03:FFFF
;  1750   |  512KB |   0 - 7      |  bits 0-2   |  $07:FFFF
;
;  Writing a bank value beyond the chip's range will simply
;  WRAP or MIRROR back to a lower bank on real hardware.
;
;  VICE emulator however supports up to 16MB (bank $00-$FF)
;  which is useful for testing expanded REU scenarios.
; ============================================================

; ============================================================
; Adjust this constant to match your target hardware
; ============================================================
REU_MAX_BANK = $07 ; 1750 REU  (512KB - most common)
;REU_MAX_BANK = $03 ; 1764 REU  (256KB)
;REU_MAX_BANK = $01 ; 1700 REU  (128KB)
;REU_MAX_BANK = $FF ; VICE max  (16MB - emulator only)
; ============================================================

; ============================================================
; REU Status Register $DF00 - Corrected Full Definition
; ============================================================
;
;  Bit 7 : INTERRUPT PENDING  - 1 = interrupt has occurred
;  Bit 6 : END OF BLOCK       - 1 = transfer completed
;  Bit 5 : FAULT              - 1 = verify mismatch
;  Bit 4 : SIZE               - 0 = 128KB, 1 = 256KB+
;  Bits 3-0 : VERSION         - chip revision number
;
;  So your reading of %00010000 ($10) breaks down as:
;
;  Bit 4    = 1  (256KB+ REU present)
;  Bits 3-0 = 0  (version 0 - as reported by VICE emulation)
;
; ============================================================
REU_STATUS_INT     = %10000000  ; Bit 7
REU_STATUS_EOB     = %01000000  ; Bit 6
REU_STATUS_FAULT   = %00100000  ; Bit 5
REU_STATUS_SIZE    = %00010000  ; Bit 4
REU_STATUS_VERSION = %00001111  ; Bits 3-0 mask

; ============================================================
; Quick Reference
; ============================================================
;
;  After a TRANSFER ($90/$91/$92):
;    Bit 6 (EOB) = 1  means SUCCESS
;    Bits 5,7    = normally 0
;
;  After a VERIFY ($93):
;    Bit 6 (EOB) = 1  means verify RAN to completion
;    Bit 5 (FLT) = 0  means data MATCHED  (all good)
;    Bit 5 (FLT) = 1  means data MISMATCH (error!)
;
;  Bit 7 (INT) only relevant if you have enabled REU
;  interrupts via REU_INT_MASK ($DF09) - advanced usage
; ============================================================
