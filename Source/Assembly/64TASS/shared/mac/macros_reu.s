.comment
; ============================================================
; FILE    : macros_reu.s
; PROJECT : Commodore 64 REU Macro Library
; AUTHOR  : Peter
; TARGET  : Commodore 64 / 6510 CPU
; TOOLS   : 64TASS assembler, VICE emulator, physical C64U
; ============================================================
; PURPOSE
; -------
; Provides a complete set of macros and procedures for
; interfacing with the Commodore 1700/1764/1750 RAM Expansion
; Unit (REU) and compatible expansions up to 16MB (VICE).
;
; The REU performs transparent DMA transfers between C64 RAM
; and expansion RAM. "Transparent" means the CPU is halted
; during the transfer but resumes as if no time passed —
; making DMA appear atomic from the program's perspective.
;
; DEPENDENCIES
; ------------
; Requires labels_reu.s to be included BEFORE this file.
; That file defines all REU hardware register addresses:
;   REU_COMMAND   = $DF01   REU_C64_LO  = $DF02
;   REU_C64_HI    = $DF03   REU_REU_LO  = $DF04
;   REU_REU_HI    = $DF05   REU_REU_BANK= $DF06
;   REU_LEN_LO    = $DF07   REU_LEN_HI  = $DF08
;   REU_STATUS    = $DF00   REU_STATUS_EOB = %01000000
;
; REGISTER MAP SUMMARY (REU I/O page $DF00-$DF0F)
; ------------------------------------------------
;   $DF00  REU_STATUS    - status register (read, self-clearing)
;   $DF01  REU_COMMAND   - command register (write to trigger DMA)
;   $DF02  REU_C64_LO    - C64 base address low  byte
;   $DF03  REU_C64_HI    - C64 base address high byte
;   $DF04  REU_REU_LO    - REU address low  byte (offset bits 0-7)
;   $DF05  REU_REU_HI    - REU address mid  byte (offset bits 8-15)
;   $DF06  REU_REU_BANK  - REU address high byte (bank bits 16-23)
;   $DF07  REU_LEN_LO    - transfer length low  byte
;   $DF08  REU_LEN_HI    - transfer length high byte
;
; COMMAND BYTE REFERENCE ($DF01)
; --------------------------------
;   bit 7   : execute  - must be 1 to trigger DMA
;   bit 6   : unused   - write 0
;   bit 5   : fix REU addr - 1 = do not increment REU address
;   bit 4   : fix C64 addr - 1 = do not increment C64 address
;   bits 3-2: unused   - write 0
;   bits 1-0: transfer type:
;             %00 = $90 : C64 → REU
;             %01 = $91 : REU → C64
;             %10 = $92 : SWAP (C64 ↔ REU simultaneously)
;             %11 = $93 : COMPARE (C64 vs REU)
;
; 24-BIT REU ADDRESS FORMAT
; --------------------------
; The REU uses a flat 24-bit address space split across three
; 8-bit registers:
;
;   bits 23-16 : bank number  → REU_REU_BANK ($DF06)
;   bits 15-8  : page offset  → REU_REU_HI   ($DF05)
;   bits  7-0  : byte offset  → REU_REU_LO   ($DF04)
;
; Example: $0A1234  → bank $0A, page $12, byte $34
;
; In 64TASS, the backtick operator extracts byte 2 (the bank):
;   lda #`\rAddress     ; extracts bits 16-23
;
; MACRO INVENTORY
; ---------------
; Detection:
;   REU_QUICK_DETECT         - fast presence check via bank register
;
; Absolute Address Transfers (24-bit REU address):
;   REU_FROM_C64             - C64 RAM → REU RAM
;   REU_TO_C64               - REU RAM → C64 RAM
;   REU_SWAP                 - atomic bidirectional swap
;
; Bank-Based Transfers (register holds bank number):
;   REU_FROM_C64_B           - C64 RAM → REU RAM, register-selected bank
;   REU_TO_C64_B             - REU RAM → C64 RAM, register-selected bank
;
; Synchronisation:
;   REU_WAIT_EOB_MACRO       - inline busy-wait for transfer completion
;   REU_WAIT_EOB_PROC        - subroutine version (JSR, saves code size)
;
; Utility:
;   REU_SET_LENGTH_MACRO     - set transfer length registers only
;   REU_SET_C64_ADDRESS_MACRO - set C64 address registers only
;   REU_SET_REU_ADDRESS_MACRO - set REU address registers only (24-bit)
;
; USAGE PATTERN
; -------------
; Most transfers follow this sequence:
;
;   1. Invoke a transfer macro (e.g. REU_FROM_C64, REU_TO_C64)
;      → the macro programs the REU registers and fires DMA
;
;   2. Wait for completion (if issuing sequential transfers):
;      jsr REU_WAIT_EOB_PROC    ; or use #REU_WAIT_EOB_MACRO
;
;   3. Proceed with next operation.
;
; For a single fire-and-forget transfer, waiting is optional
; as the CPU is halted during transparent DMA anyway.
;
; ZERO PAGE USAGE
; ---------------
; REU_ALIASING_DETECT uses zero page locations $FB, $FC, $FD
; as temporary byte staging areas during aliasing tests.
; Ensure these are free when calling that macro.
;
; NOTES ON VICE EMULATION
; ------------------------
; VICE emulator has a known bug in its 256KB (1764) emulation:
; the aliasing boundary is incorrectly placed, causing
; REU_ALIASING_DETECT to misreport 256KB as 512KB. Real
; hardware (C64U) detects all sizes correctly. See the
; VICE_256KB_BUG.md companion document for full details.
;
; ASSEMBLER: 64TASS (tested against v1.60)
; ============================================================

; ============================================================
; MACRO: REU_QUICK_DETECT
; Purpose : Detect presence of a RAM Expansion Unit (REU)
;           by probing the REU bank register ($DF06).
;           Branches to the given label if no REU is found.
; Params  : label  - branch target if REU is not detected
; Returns : A register contains REU size value if present:
;             $01=128KB, $03=256KB, $07=512KB, $0F=1MB
;             $00=no REU detected
; Destroys: Accumulator (A register)
; Algorithm: 1. Clear REU address registers to known state
;            2. Read back bank register
;            3. If zero, no REU present - branch to label
;            4. If non-zero, REU present - A contains size
; Notes   : On systems without REU, $DF06 reads as $00
;           or sometimes $FF depending on bus floating state.
;           Real hardware returns power-of-2 minus 1 values.
; Cycles  : ~30 cycles (branch not taken / REU present)
; ============================================================
.endcomment
REU_QUICK_DETECT .macro label
    ; ensure registers are in known state first
    ; this prevents false positives from previous operations
    lda #$00
    sta REU_REU_LO      ; clear reu address low
    sta REU_REU_HI      ; clear reu address mid
    sta REU_REU_BANK    ; clear reu address high
    
    ; read back the bank register
    ; if REU is present, this will return a non-zero value
    ; encoding the installed RAM size
    lda REU_REU_BANK
    
    ; check if zero (no REU)
    ; on systems without REU, this address reads as $00
    ; or sometimes $ff depending on bus state
    beq \label      ; branch if zero (no REU detected)
    
    ; if we reach here, REU is present
    ; A register contains the REU size value
.endmacro

; ============================================================
; MACRO: REU_FROM_C64
; Purpose : Copy data FROM C64 RAM -> TO REU RAM using 24-bit
;           absolute REU addressing. This is the simplest form
;           for transfers when you know the complete address.
; Params  : rAddress - 24-bit REU destination address
;                      example: $0A1234 = bank $0A, offset $1234
;           cAddress - 16-bit C64 source address ($0000-$FFFF)
;           tLength  - 16-bit transfer length (1-65536 bytes)
;                      note: 0 is interpreted as 65536
;           tCommand - (OPTIONAL) command byte, defaults to $90
;                      $90 = C64→REU (default)
;                      $91 = REU→C64
;                      $92 = SWAP C64↔REU
;                      $93 = COMPARE C64 vs REU
; Returns : None (transfer executes immediately)
; Destroys: Accumulator (A register)
; Algorithm: 1. Load C64 source address into REU_C64_LO/HI
;            2. Split 24-bit REU address into low/high/bank
;            3. Load transfer length into REU_LEN_LO/HI
;            4. Write command to REU_COMMAND (triggers DMA)
;            5. CPU halts until transfer completes (transparent)
; Notes   : Uses 64TASS ` operator to extract bank byte.
;           Formula: bank = (rAddress >> 16) & $FF
;                    offset = rAddress & $FFFF
;           The transfer is transparent DMA - CPU is halted
;           but the transfer appears atomic to the program.
; Cycles  : ~20 CPU cycles + DMA time (~2 cycles per byte)
; Example : #REU_FROM_C64 $0A1234, $C000, 1000
;           → copies 1000 bytes from $C000 to bank $0A, offset $1234
;           #REU_FROM_C64 $0A1234, $C000, 1000, $91
;           → uses $91 command instead of default $90
; ============================================================
REU_FROM_C64 .macro rAddress, cAddress, tLength, tCommand=$90
    ; --- step 1: set the c64 source address ---
    #REU_SET_C64_ADDRESS_MACRO \cAddress

    ; --- step 2: set the reu destination address (24-bit) ---
    #REU_SET_REU_ADDRESS_MACRO \rAddress

    ; --- step 3: set transfer length ---
    #REU_SET_LENGTH_MACRO \tLength

    ; --- step 4: execute! writing the command register starts the DMA ---
    ; the CPU is halted by the REU during the transfer (transparent DMA)
    ; the transfer happens at approximately 2 cycles per byte
    lda #\tCommand         ; command byte (or default $90)
    sta REU_COMMAND        ; $DF01 - go! cpu stalls until done
.endmacro

; ============================================================
; MACRO: REU_TO_C64
; Purpose : Copy data FROM REU RAM -> TO C64 RAM using 24-bit
;           absolute REU addressing.
; Params  : rAddress - 24-bit REU source address
;           cAddress - 16-bit C64 destination address
;           tLength  - 16-bit transfer length (1-65536 bytes)
;           tCommand - (OPTIONAL) command byte, defaults to $91
;                      $90 = C64→REU
;                      $91 = REU→C64 (default)
;                      $92 = SWAP C64↔REU
;                      $93 = COMPARE C64 vs REU
; Returns : None (transfer executes immediately)
; Destroys: Accumulator (A register)
; Algorithm: 1. Load C64 destination address into REU_C64_LO/HI
;            2. Split 24-bit REU address into low/high/bank
;            3. Load transfer length into REU_LEN_LO/HI
;            4. Write command to REU_COMMAND (triggers DMA)
;            5. CPU halts until transfer completes (transparent)
; Notes   : Uses 64TASS ` operator for bank byte extraction.
;           Default command is $91 (REU→C64) for this macro.
; Cycles  : ~20 CPU cycles + DMA time (~2 cycles per byte)
; Example : #REU_TO_C64 $050000, $C000, 1000
;           → copies 1000 bytes from bank $05 to $C000
;           #REU_TO_C64 $050000, $C000, 1000, $92
;           → uses $92 (swap) instead of default $91
; ============================================================
REU_TO_C64 .macro rAddress, cAddress, tLength, tCommand=$91
    ; --- step 1: set the c64 destination address ---
    #REU_SET_C64_ADDRESS_MACRO \cAddress

    ; --- step 2: set the reu source address (24-bit) ---
    #REU_SET_REU_ADDRESS_MACRO \rAddress

    ; --- step 3: set transfer length ---
    #REU_SET_LENGTH_MACRO \tLength

    ; --- step 4: execute! ---
    lda #\tCommand         ; command byte (default $91 for reu→c64)
    sta REU_COMMAND        ; $DF01 - go! cpu stalls until done
.endmacro

; ============================================================
; MACRO: REU_SWAP
; Purpose : SIMULTANEOUSLY swap memory blocks between C64 and
;           REU. This is the REU's killer feature - true atomic
;           swap with no temporary buffer needed!
; Params  : rAddress - 24-bit REU address
;           cAddress - 16-bit C64 address
;           tLength  - 16-bit number of bytes to swap
;           tCommand - (OPTIONAL) command byte, defaults to $92
;                      $90 = C64→REU
;                      $91 = REU→C64
;                      $92 = SWAP C64↔REU (default)
;                      $93 = COMPARE C64 vs REU
; Returns : None (swap executes immediately)
; Destroys: Accumulator (A register)
; Algorithm: 1. Load C64 address (source AND destination)
;            2. Load REU address (source AND destination)
;            3. Load transfer length
;            4. Write $92 command (triggers simultaneous swap)
;            5. CPU halts until swap completes
; Notes   : After swap, C64 memory has REU data and vice versa.
;           Neither buffer needs a temporary holding area.
;           This is unique to the REU - no other C64 expansion
;           can perform atomic bidirectional transfers.
;           The swap happens during DMA, appearing atomic.
; Cycles  : ~20 CPU cycles + DMA time (~2 cycles per byte)
; Example : #REU_SWAP $010000, $C000, 1000
;           → swaps 1000 bytes between $C000 and bank $01
;           Before: C64[$C000]=A, REU[$010000]=B
;           After:  C64[$C000]=B, REU[$010000]=A
; ============================================================
REU_SWAP .macro rAddress, cAddress, tLength, tCommand=$92
    ; --- step 1: set the c64 address (source AND destination) ---
    #REU_SET_C64_ADDRESS_MACRO \cAddress

    ; --- step 2: set the reu address (source AND destination) ---
    #REU_SET_REU_ADDRESS_MACRO \rAddress

    ; --- step 3: set transfer length ---
    #REU_SET_LENGTH_MACRO \tLength

    ; --- step 4: execute! ---
    lda #\tCommand         ; command byte (default $92 for swap)
    sta REU_COMMAND        ; $DF01 - go! both regions exchanged simultaneously
.endmacro

; ============================================================
; MACRO: REU_FROM_C64_B
; Purpose : Copy data FROM C64 RAM -> TO REU RAM using bank-
;           based addressing. Allows the bank number to be in
;           any register (X, A, or Y) without requiring an
;           intermediate load into the accumulator.
; Params  : rBank    - store instruction selecting which register
;                      holds the bank value:
;                      stx → X register holds bank number
;                      sta → A register holds bank number
;                      sty → Y register holds bank number
;           rOffset  - 16-bit offset within the bank ($0000-$FFFF)
;           cAddress - 16-bit C64 source address ($0000-$FFFF)
;           tLength  - number of bytes to transfer (1-65536)
;           tCommand - (OPTIONAL) command byte, defaults to $90
;                      $90 = C64→REU (default)
;                      $91 = REU→C64
;                      $92 = SWAP C64↔REU
;                      $93 = COMPARE C64 vs REU
; Returns : None (transfer executes immediately)
; Destroys: Accumulator (A register)
; Algorithm: 1. Load C64 source address into REU_C64_LO/HI
;            2. Load REU offset within bank into REU_REU_LO/HI
;            3. Store bank number using caller's register choice
;            4. Load transfer length into REU_LEN_LO/HI
;            5. Write command to REU_COMMAND (triggers DMA)
; Notes   : The bank parameter accepts the store opcode itself,
;           which is then substituted to generate the appropriate
;           store instruction. This eliminates the need for:
;             txa / sta REU_REU_BANK  (if bank is in X)
;           Instead, just pass stx as the rBank parameter.
;           
;           If sta is passed as rBank, A is consumed by the
;           bank write. Using stx or sty preserves A for the
;           subsequent lda instructions in the macro.
;           
;           REU Address Calculation:
;           24-bit address = (bank << 16) | offset
;           Example: bank=$05, offset=$1234 → $051234
; Cycles  : ~20 CPU cycles + DMA time (~2 cycles per byte)
; Example : ldx #$04                       ; bank 4 in X
;           #REU_FROM_C64_B stx, $0000, $c000, 1
;           → copies 1 byte from $C000 to bank $04, offset $0000
;           
;           lda #$08                        ; bank 8 in A
;           #REU_FROM_C64_B sta, $1000, $d000, 256, $91
;           → uses $91 command, bank in A, offset $1000
; ============================================================
REU_FROM_C64_B .macro rBank, rOffset, cAddress, tLength, tCommand=$90

    ; --- step 1: set c64 source address ---
    ; load the 16-bit c64 memory address where data will be read
    #REU_SET_C64_ADDRESS_MACRO \cAddress

    ; --- step 2: set reu offset within bank ---
    ; this is the 16-bit offset WITHIN the selected 64KB bank
    ; each bank is 64KB (65536 bytes), addressed $0000-$FFFF
    lda #<\rOffset              ; low  byte of offset within bank
    sta REU_REU_LO              ; $DF04 / 57092
    lda #>\rOffset              ; high byte of offset within bank
    sta REU_REU_HI              ; $DF05 / 57093

    ; --- step 3: set bank using caller-nominated register ---
    ; this is the innovative part! the caller passes the actual
    ; store instruction (stx/sta/sty) as a macro parameter.
    ;
    ; the macro substitutes \rBank with the instruction:
    ;   if caller passed stx → generates: stx REU_REU_BANK
    ;   if caller passed sta → generates: sta REU_REU_BANK
    ;   if caller passed sty → generates: sty REU_REU_BANK
    ;
    ; this means the bank number can already be in X, A, or Y
    ; without requiring an intermediate transfer to A first.
    ; this saves 2 cycles (txa) and makes code more flexible.
    \rBank REU_REU_BANK         ; $DF06 / 57094

    ; --- step 4: set transfer length ---
    ; 16-bit value specifying number of bytes to transfer
    ; valid range: 1-65536 (0 is interpreted as 65536)
    #REU_SET_LENGTH_MACRO \tLength

    ; --- step 5: execute transfer with command ---
    ; writing to REU_COMMAND triggers the DMA operation
    ; the CPU is halted (transparent DMA) until transfer completes
    ;
    ; command byte format (8 bits):
    ;   bit 7: execute (1 = start transfer immediately)
    ;   bit 6: unused (should be 0)
    ;   bit 5: fix REU address (1 = don't increment)
    ;   bit 4: fix C64 address (1 = don't increment)
    ;   bit 3-2: unused (should be 0)
    ;   bit 1-0: transfer type
    ;            00 = C64 → REU ($90 / 144)
    ;            01 = REU → C64 ($91 / 145)
    ;            10 = swap      ($92 / 146)
    ;            11 = compare   ($93 / 147)
    lda #\tCommand              ; command byte (or default $90)
    sta REU_COMMAND             ; $DF01 / 57089 - fires DMA immediately!
.endmacro


; ============================================================
; MACRO: REU_TO_C64_B
; Purpose : Copy data FROM REU RAM -> TO C64 RAM using bank-
;           based addressing. Allows the bank number to be in
;           any register (X, A, or Y).
; Params  : rBank    - store instruction for register holding bank:
;                      stx / sta / sty
;           rOffset  - 16-bit offset within the bank ($0000-$FFFF)
;           cAddress - 16-bit C64 destination address
;           tLength  - number of bytes to transfer (1-65536)
;           tCommand - (OPTIONAL) command byte, defaults to $91
;                      $90 = C64→REU
;                      $91 = REU→C64 (default)
;                      $92 = SWAP C64↔REU
;                      $93 = COMPARE C64 vs REU
; Returns : None (transfer executes immediately)
; Destroys: Accumulator (A register)
; Algorithm: 1. Load C64 destination address into REU_C64_LO/HI
;            2. Load REU offset within bank into REU_REU_LO/HI
;            3. Store bank number using caller's register choice
;            4. Load transfer length into REU_LEN_LO/HI
;            5. Write command to REU_COMMAND (triggers DMA)
; Notes   : Similar to REU_FROM_C64_B but defaults to $91 (REU→C64).
;           The rBank parameter accepts store opcodes directly.
; Cycles  : ~20 CPU cycles + DMA time (~2 cycles per byte)
; Example : ldx #$04                       ; bank 4 in X
;           #REU_TO_C64_B stx, $0000, $c000, 1
;           → copies 1 byte from bank $04 to $C000
;
;           ldy zp_bank                     ; bank from zero page
;           #REU_TO_C64_B sty, $0000, $c000, 1
;           → Y holds bank, uses default $91 command
; ============================================================
REU_TO_C64_B .macro rBank, rOffset, cAddress, tLength, tCommand=$91

    ; --- step 1: set c64 destination address ---
    #REU_SET_C64_ADDRESS_MACRO \cAddress

    ; --- step 2: set reu offset within bank ---
    lda #<\rOffset              ; low  byte of offset within bank
    sta REU_REU_LO              ; $DF04 / 57092
    lda #>\rOffset              ; high byte of offset within bank
    sta REU_REU_HI              ; $DF05 / 57093

    ; --- step 3: set bank using caller-nominated register ---
    \rBank REU_REU_BANK         ; $DF06 / 57094 - stx / sta / sty

    ; --- step 4: set transfer length ---
    #REU_SET_LENGTH_MACRO \tLength

    ; --- step 5: execute ---
    lda #\tCommand              ; command byte (default $91 for reu→c64)
    sta REU_COMMAND             ; $DF01 / 57089 - fires DMA immediately!
.endmacro

; ============================================================
; MACRO: REU_WAIT_EOB_MACRO
; Purpose : Busy-wait (poll) until the current REU transfer
;           completes. Essential for ensuring sequential DMA
;           operations don't overlap or corrupt data.
; Params  : None
; Returns : None (A register contains final status byte)
; Destroys: Accumulator (A register)
; Algorithm: 1. Read REU_STATUS register ($DF00)
;            2. Test bit 6 (End-Of-Block flag)
;            3. If clear, loop back to step 1
;            4. If set, transfer complete - exit
; Notes   : CRITICAL: Reading REU_STATUS clears the register!
;           This means you cannot check multiple status bits
;           across separate reads. Save the status byte if you
;           need to check multiple flags.
;           
;           This is a blocking/busy-wait loop - the CPU does
;           nothing but poll the status register. For time-
;           critical code, consider an interrupt-driven approach
;           using the EOB interrupt (bit 7 of REU_CONTROL).
;           
;           Status Register ($DF00) format:
;           bit 7: interrupt pending (1 = EOB interrupt occurred)
;           bit 6: end of block (1 = transfer complete)
;           bit 5: fault (1 = verify error in compare operation)
;           bit 4: size (REU RAM size - implementation specific)
;           bit 3-0: version number (implementation specific)
; Cycles  : Variable - depends on transfer size
;           Approximately 6 cycles per iteration + DMA time
; Example : #REU_FROM_C64 $000000, $C000, 1000
;           #REU_WAIT_EOB_MACRO
;           ; now safe to start next transfer
; ============================================================
REU_WAIT_EOB_MACRO .macro
reu_wait_loop\@
    lda REU_STATUS      ; read status register (clears on read!)
    and #REU_STATUS_EOB ; test bit 6 (end of block)
    beq reu_wait_loop\@ ; loop until end of block flag is set
    ; when we exit: transfer is complete and safe to proceed
.endmacro

; ============================================================
; MACRO: REU_SET_LENGTH_MACRO
; Purpose : Helper macro to set the transfer length registers.
;           Useful when setting up multiple transfers with the
;           same length, or when length is calculated at runtime.
; Params  : tLength - 16-bit transfer length (1-65536 bytes)
;                     0 is interpreted as 65536
; Returns : None
; Destroys: Accumulator (A register)
; Algorithm: 1. Load low byte of length into A
;            2. Store to REU_LEN_LO ($DF07)
;            3. Load high byte of length into A
;            4. Store to REU_LEN_HI ($DF08)
; Notes   : This does NOT start a transfer - it only sets the
;           length registers. You must still write to REU_COMMAND
;           to initiate DMA.
;           
;           Useful patterns:
;           - Set length once, perform multiple transfers
;           - Build custom transfer sequences
;           - Dynamic length calculations
; Cycles  : ~12 cycles
; Example : #REU_SET_LENGTH_MACRO 1000
;           ; now length registers are set to 1000 bytes
;           ; ... set up addresses ...
;           lda #$90
;           sta REU_COMMAND    ; starts the transfer
; ============================================================
REU_SET_LENGTH_MACRO .macro tLength
    ; --- Set transfer length ---
    ; 16-bit value specifies number of bytes to transfer
    ; valid range: 1-65536 (0 is interpreted as 65536)
    lda #<\tLength      ; load low  byte of transfer length
    sta REU_LEN_LO      ; $DF07 / 57095 - transfer length low
    lda #>\tLength      ; load high byte of transfer length
    sta REU_LEN_HI      ; $DF08 / 57096 - transfer length high
.endmacro

; ============================================================
; MACRO: REU_SET_C64_ADDRESS_MACRO
; Purpose : Helper macro to set the C64 base address registers
;           only, without programming any other REU registers
;           or triggering a transfer. Useful when building a
;           custom transfer sequence register-by-register.
; Params  : cAddress - 16-bit C64 address ($0000-$FFFF)
; Returns : None
; Destroys: Accumulator (A register)
; Algorithm: 1. Load low  byte of cAddress into A
;            2. Store to REU_C64_LO ($DF02)
;            3. Load high byte of cAddress into A
;            4. Store to REU_C64_HI ($DF03)
; Notes   : Does NOT trigger a transfer. You must still write
;           to REU_COMMAND ($DF01) to initiate DMA.
;
;           Intended for use alongside:
;             REU_SET_REU_ADDRESS_MACRO  - to set the REU side
;             REU_SET_LENGTH_MACRO       - to set the length
;           Then write the command byte manually to fire the DMA.
;
;           For most use cases, prefer the all-in-one macros
;           (REU_FROM_C64, REU_TO_C64, etc.) which program all
;           registers in a single macro call.
; Cycles  : ~8 cycles
; Example : #REU_SET_C64_ADDRESS_MACRO $C000
;           #REU_SET_REU_ADDRESS_MACRO  $050000
;           #REU_SET_LENGTH_MACRO       256
;           lda #$90
;           sta REU_COMMAND             ; fire DMA: C64→REU
; ============================================================
REU_SET_C64_ADDRESS_MACRO .macro cAddress
    ; Set the 16-bit c64 memory address where data will be read
    lda #<\cAddress        ; low  byte of C64 address
    sta REU_C64_LO         ; $DF02 - c64 base address low
    lda #>\cAddress        ; high byte of C64 address
    sta REU_C64_HI         ; $DF03 - c64 base address high
.endmacro

; ============================================================
; MACRO: REU_SET_REU_ADDRESS_MACRO
; Purpose : Helper macro to set the REU expansion address
;           registers only (24-bit), without programming any
;           other REU registers or triggering a transfer.
;           Companion to REU_SET_C64_ADDRESS_MACRO.
; Params  : rAddress - 24-bit REU address
;                      bits 23-16 = bank number
;                      bits 15-8  = page offset (high byte)
;                      bits  7-0  = byte offset (low  byte)
;                      example: $0A1234 = bank $0A, offset $1234
; Returns : None
; Destroys: Accumulator (A register)
; Algorithm: 1. Extract low  byte of rAddress (bits  7-0)  → REU_REU_LO
;            2. Extract high byte of rAddress (bits 15-8)  → REU_REU_HI
;            3. Extract bank byte of rAddress (bits 23-16) → REU_REU_BANK
;               (64TASS backtick ` operator extracts byte 2)
; Notes   : Does NOT trigger a transfer. You must still write
;           to REU_COMMAND ($DF01) to initiate DMA.
;
;           Uses the 64TASS ` operator to extract the bank byte:
;             lda #`\rAddress   ; equivalent to (rAddress >> 16) & $FF
;
;           Intended for use alongside:
;             REU_SET_C64_ADDRESS_MACRO  - to set the C64 side
;             REU_SET_LENGTH_MACRO       - to set the length
;           Then write the command byte manually to fire the DMA.
; Cycles  : ~12 cycles
; Example : #REU_SET_C64_ADDRESS_MACRO  $C000
;           #REU_SET_REU_ADDRESS_MACRO  $050000
;           #REU_SET_LENGTH_MACRO       256
;           lda #$91
;           sta REU_COMMAND             ; fire DMA: REU→C64
; ============================================================
REU_SET_REU_ADDRESS_MACRO .macro rAddress
    ; --- Set the reu destination address (24-bit) ---
    ; the 24-bit address is split into three 8-bit components:
    ; - low byte (bits 0-7)    - offset within page
    ; - high byte (bits 8-15)  - page within bank
    ; - bank byte (bits 16-23) - 64KB bank number
    lda #<\rAddress        ; low  byte of reu address
    sta REU_REU_LO         ; $DF04 - reu expansion address low
    lda #>\rAddress        ; high byte of reu address
    sta REU_REU_HI         ; $DF05 - reu expansion address high
    lda #`\rAddress        ; bank byte of reu address
    sta REU_REU_BANK       ; $DF06 - reu expansion bank
    ; note: use ` operator in 64tass for byte 2 of 24-bit value
.endmacro
