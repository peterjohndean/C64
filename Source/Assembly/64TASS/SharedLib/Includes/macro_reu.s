; ============================================================
; MACRO: REU_DETECT
; Purpose : Detect presence of a RAM Expansion Unit (REU)
;           by probing the REU bank register ($DF06).
;           Branches to the given label if no REU is found.
; Params  : label  - branch target if REU is not detected
; Destroys: Accumulator (A register)
; Notes   : REU_REU_BANK returns $00 when no REU is present.
;           A non-zero result also encodes installed RAM size:
;           $01=128KB, $03=256KB, $07=512KB, $0F=1MB, etc.
; Cycles  : ~30 cycles (branch not taken / REU present)
; ============================================================
REU_DETECT   .macro label
    ; ensure registers are in known state first
    lda #$00
    sta REU_REU_LO      ; clear reu address low
    sta REU_REU_HI      ; clear reu address mid
    sta REU_REU_BANK    ; clear reu address high
    
    ; If no REU present, typically returns $00
    lda REU_REU_BANK
    
    ; Check if zero (no REU)
    ; On systems without REU, this address reads as $00
    ; or sometimes $ff depending on bus state
    beq \label      ; branch if zero (no REU detected)
    
    ; If we reach here, REU is present
    ; A register contains the REU size value
.endmacro

; ============================================================
; MACRO: STROUT
; Purpose : Output a null-terminated string via BASIC_STROUT
;           by loading the string address into A (lo) / Y (hi)
; Params  : msg    - label of a null-terminated string to print
; Destroys: Accumulator (A), Y register
; Notes   : The string must be terminated with a null byte ($00).
;           Typically defined as:  txt .null "your string"
; Cycles  : ~12 cycles + BASIC_STROUT call time
; ============================================================
STROUT  .macro msg
    lda #<\msg          ; lsb
    ldy #>\msg          ; msb
    jsr BASIC_STROUT
.endmacro

; ============================================================
; MACRO: REU_FROM_C64
; Purpose : Copy data FROM C64 RAM -> TO REU RAM
; Params  : rAddress - 24-bit REU  destination address
;           cAddress - 16-bit C64  source address
;           tLength  - 16-bit number of bytes to transfer (1-65536)
; Destroys: Accumulator (A register)
; Cycles  : ~20 cycles + REU DMA time
; ============================================================
REU_FROM_C64 .macro rAddress, cAddress, tLength
    ; --- Step 1: Set the C64 SOURCE address ---
    lda #<\cAddress        ; Low  byte of C64 address
    sta REU_C64_LO
    lda #>\cAddress        ; High byte of C64 address
    sta REU_C64_HI

    ; --- Step 2: Set the REU DESTINATION address (24-bit) ---
    lda #<\rAddress        ; Low  byte of REU address (bits  0-7)
    sta REU_REU_LO
    lda #>\rAddress        ; High byte of REU address (bits  8-15)
    sta REU_REU_HI
    lda #`\rAddress        ; Bank byte of REU address (bits 16-23)
    sta REU_REU_BANK        ; Use ` operator in 64tass for byte 2

    ; --- Step 3: Set transfer LENGTH ---
    lda #<\tLength         ; Low  byte of length
    sta REU_LEN_LO
    lda #>\tLength         ; High byte of length (0 for <256 bytes)
    sta REU_LEN_HI

    ; --- Step 4: Execute! Writing the command register starts the DMA ---
    ; The CPU is halted by the REU during the transfer (transparent DMA)
    lda #REU_CMD_C64_TO_REU ; $90 - Execute + C64->REU
    sta REU_COMMAND         ; GO! CPU stalls until done
.endmacro

; ============================================================
; MACRO: REU_TO_C64
; Purpose : Copy data FROM REU RAM -> TO C64 RAM
; Params  : rAddress - 24-bit REU  source address
;           cAddress - 16-bit C64  destination address
;           tLength  - 16-bit number of bytes to transfer
; Destroys: Accumulator (A register)
; ============================================================
REU_TO_C64 .macro rAddress, cAddress, tLength
    ; --- Step 1: Set the C64 DESTINATION address ---
    lda #<\cAddress
    sta REU_C64_LO
    lda #>\cAddress
    sta REU_C64_HI

    ; --- Step 2: Set the REU SOURCE address (24-bit) ---
    lda #<\rAddress
    sta REU_REU_LO
    lda #>\rAddress
    sta REU_REU_HI
    lda #`\rAddress        ; Bank byte using 64tass ` operator
    sta REU_REU_BANK

    ; --- Step 3: Set transfer LENGTH ---
    lda #<\tLength
    sta REU_LEN_LO
    lda #>\tLength
    sta REU_LEN_HI

    ; --- Step 4: Execute! ---
    lda #REU_CMD_REU_TO_C64 ; $91 - Execute + REU->C64
    sta REU_COMMAND         ; GO! CPU stalls until done
.endmacro

; ============================================================
; MACRO: REU_SWAP
; Purpose : SIMULTANEOUSLY swap blocks between C64 and REU
;           This is the REU's killer feature - true atomic swap!
;           Neither buffer needs a temporary area.
; Params  : rAddress - 24-bit REU  address
;           cAddress - 16-bit C64  address
;           tLength  - 16-bit number of bytes to swap
; Destroys: Accumulator (A register)
; Note    : After swap, C64 has REU data, REU has C64 data
; ============================================================
REU_SWAP .macro rAddress, cAddress, tLength
    ; --- Step 1: Set the C64 address (source AND destination) ---
    lda #<\cAddress
    sta REU_C64_LO
    lda #>\cAddress
    sta REU_C64_HI

    ; --- Step 2: Set the REU address (source AND destination) ---
    lda #<\rAddress
    sta REU_REU_LO
    lda #>\rAddress
    sta REU_REU_HI
    lda #`\rAddress
    sta REU_REU_BANK

    ; --- Step 3: Set transfer LENGTH ---
    lda #<\tLength
    sta REU_LEN_LO
    lda #>\tLength
    sta REU_LEN_HI

    ; --- Step 4: Execute! ---
    lda #REU_CMD_SWAP       ; $92 - Execute + Swap
    sta REU_COMMAND         ; GO! Both regions exchanged simultaneously
.endmacro

; ============================================================
; MACRO: REU_WAIT_EOB
; Purpose : Busy-wait (poll) until transfer completes
; Use     : Call immediately after triggering a transfer
; Caution : This is a blocking loop - consider interrupt
;           driven approach for time critical code
; ============================================================
REU_WAIT_EOB .macro
wait
    lda REU_STATUS      ; Read status (clears on read!)
    and #REU_STATUS_EOB ; Test bit 6
    beq wait            ; Loop until End of Block set
.endmacro
